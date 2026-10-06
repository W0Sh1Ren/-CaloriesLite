/**
 * 桌面卡片（2x2）的数据接口。
 *
 * 卡片进程与主应用进程相互独立，不能指望内存里的 @State 或 AppStorage，
 * 所以这里从偏好存储重新读一遍档案与当日记录，算出汇总再交给卡片页面。
 *
 * 必须在 onCreate 里调 Store.init(this.context)：不初始化的话
 * Store 的读取全部返回默认值，卡片会一直显示 0（而不是报错），很难排查。
 *
 * **所有派生计算都在 CardData 里做完**，这里只负责「读数据 → 转 payload → 推送」。
 * 卡片 UI 不做任何运算（原因见 CardData.ets 顶部说明）。
 */
import { formBindingData, FormExtensionAbility, formInfo, formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { Store } from '../common/Store';
import { todayKey } from '../common/DateUtil';
import { DailyService, HomeData } from '../service/DailyService';
import { macroTargetFor, MacroTarget } from '../model/Enums';
import { CardData } from '../widget/CardData';

const DOMAIN = 0x0000;

/** 卡片「刷新」按钮发来的业务动作名，与 CalorieCard.ets 里保持一致 */
const ACTION_REFRESH: string = 'refresh';

export default class CalorieCardAbility extends FormExtensionAbility {

  /**
   * 已算好的数据缓存，键是 dayKey。
   *
   * onAddForm 与 onUpdateForm 会先后触发，如果每次都重算并推送，
   * 卡片就会被连续改写两次 —— 这是「闪一下」的一个来源。
   * 同一天只算一次，两次回调推的是同一份内容，界面就不会二次跳动。
   * 换天（dayKey 变化）时自动重算。
   */
  private static cachedDay: string = '';
  private static cachedData: Record<string, Object> | null = null;

  /** 取当日数据（带缓存），保证同一份内容不会被反复推送 */
  private static dataForToday(): Record<string, Object> {
    const day: string = todayKey();
    if (CalorieCardAbility.cachedData !== null && CalorieCardAbility.cachedDay === day) {
      return CalorieCardAbility.cachedData;
    }
    const d: Record<string, Object> = CalorieCardAbility.buildData();
    CalorieCardAbility.cachedDay = day;
    CalorieCardAbility.cachedData = d;
    return d;
  }

  /**
   * 数据变化后作废缓存。
   *
   * 应用侧记完一笔后调 formProvider.reloadAllForms()，系统会回调
   * onUpdateForm；不清缓存的话那次回调拿到的还是旧数据，卡片不会变。
   */
  static invalidateCache(): void {
    CalorieCardAbility.cachedData = null;
    CalorieCardAbility.cachedDay = '';
  }

  /**
   * 把当日汇总整理成卡片能用的扁平数据。
   *
   * 读存储失败时返回 CardData.fallback()，保证卡片永远有内容可渲染
   *（而不是整块空白）。
   */
  private static buildData(): Record<string, Object> {
    try {
      const home: HomeData = DailyService.homeData(todayKey());
      const target: MacroTarget = macroTargetFor(home.summary.budget);
      const data: CardData = CardData.from(home.summary, target);
      /*
       * 诊断日志：把「读到了什么」和「要推什么」都打出来。
       * 点刷新没反应时，靠这两行区分是【读到的数据就是旧的】
       * 还是【推出去了但卡片没重绘】。
       *
       * 后面四项是缺口分档的输入与结果：卡片的环色/档位文案完全由它们决定，
       * 而卡片 UI 跑在系统进程里看不到节点 —— 排查「卡片没变红」时
       * 只能靠这几行确认是算错了还是没渲染出来。
       */
      hilog.info(DOMAIN, 'CalorieLite',
        'card build: storeReady=%{public}s records=%{public}d intake=%{public}d -> push intake=%{public}d',
        `${Store.isReady()}`, home.records.length, Math.round(home.summary.intake), data.intake);
      hilog.info(DOMAIN, 'CalorieLite',
        'card deficit: actual=%{public}d planned=%{public}d -> %{public}s ringColor=%{public}s',
        data.deficit, data.plannedDeficit, data.deficitLabel, data.ringColor);
      return data.toPayload();
    } catch (err) {
      hilog.error(DOMAIN, 'CalorieLite', 'card data build failed: %{public}s', JSON.stringify(err));
      return CardData.fallback().toPayload();
    }
  }

  /** 添加卡片：给出初始数据 */
  onAddForm(want: Want): formBindingData.FormBindingData {
    Store.init(this.context);
    // 用带缓存的入口：紧接着的 onUpdateForm 会拿到同一份内容，
    // 卡片不会被连续改写两次（那是「闪一下」的一个来源）
    return formBindingData.createFormBindingData(CalorieCardAbility.dataForToday());
  }

  /**
   * 刷新卡片：系统定时刷新（updateDuration=1，即 30 分钟）触发，
   * 以及主应用调 reloadAllForms() 后由系统回调。
   *
   * 每次都重算 —— 这正是「记完一笔，卡片跟着变」生效的地方，
   * 所以这里**不能**走带缓存的 dataForToday()（那会一直推旧值）。
   */
  onUpdateForm(formId: string): void {
    /*
     * 用 reload 而不是 init：卡片进程是长驻的，而 preferences 实例在进程内
     * 有缓存，主应用写入的新数据它看不到（详见 Store.reload 的说明）。
     * 这里必须主动丢掉旧快照，否则「刷新」推的还是旧值。
     */
    Store.reload(this.context);
    try {
      const fresh: Record<string, Object> = CalorieCardAbility.buildData();
      // 顺手刷新缓存，避免下一次 onAddForm 推到旧内容
      CalorieCardAbility.cachedDay = todayKey();
      CalorieCardAbility.cachedData = fresh;
      const binding: formBindingData.FormBindingData =
        formBindingData.createFormBindingData(fresh);
      // 用 formProvider 而不是 this.context.updateForm：
      // FormExtensionContext 上没有 updateForm 方法（实测编译报
      // 「Property 'updateForm' does not exist on type 'FormExtensionContext'」）。
      formProvider.updateForm(formId, binding)
        .catch((e: Error) => {
          hilog.error(DOMAIN, 'CalorieLite', 'updateForm failed: %{public}s', e.message);
        });
    } catch (err) {
      hilog.error(DOMAIN, 'CalorieLite', 'card onUpdateForm failed: %{public}s', JSON.stringify(err));
    }
  }

  onCastToNormalForm(formId: string): void {
    // 本卡片不支持临时转常驻
  }

  /**
   * 卡片上的「刷新」按钮走这里。
   *
   * 卡片 UI 通过 postCardAction({action:'message', params:{action:'refresh'}})
   * 把事件发过来，这里重算并推送。用 message 而不是 router：
   * 刷新只是换数据，不该把用户拉到应用里去。
   *
   * message 的 JSON 结构在不同资料里表述不一（可能是完整对象、也可能只有
   * params 内容），所以按文档建议做**防御式解析**，两种都认。
   */
  onFormEvent(formId: string, message: string): void {
    hilog.info(DOMAIN, 'CalorieLite', 'onFormEvent: %{public}s', message);
    let action: string = CalorieCardAbility.parseAction(message);
    if (action !== ACTION_REFRESH) {
      return;
    }
    // 同 onUpdateForm：卡片进程必须重开偏好存储，否则读到的还是旧值
    Store.reload(this.context);
    try {
      // 与 onUpdateForm 一致：重算而不是读缓存，否则「刷新」刷不出新数据
      const fresh: Record<string, Object> = CalorieCardAbility.buildData();
      CalorieCardAbility.cachedDay = todayKey();
      CalorieCardAbility.cachedData = fresh;
      formProvider.updateForm(formId, formBindingData.createFormBindingData(fresh))
        .then(() => {
          hilog.info(DOMAIN, 'CalorieLite', 'refresh pushed to %{public}s', formId);
        })
        .catch((e: Error) => {
          hilog.error(DOMAIN, 'CalorieLite', 'refresh updateForm failed: %{public}s', e.message);
        });
    } catch (err) {
      hilog.error(DOMAIN, 'CalorieLite', 'onFormEvent failed: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 从 message 里取出业务动作名。
   *
   * 兼容三种可能形态（文档实测过的三种）：
   *   '{"action":"message","params":{"action":"refresh"}}' → params.action
   *   '{"action":"refresh"}'                              → 顶层 action
   *   'refresh'（纯字符串，不是合法 JSON）                  → 原文
   * 兜底取顶层 action 时要排除 'message' 本身 —— 那是事件类型，不是业务动作。
   */
  private static parseAction(message: string): string {
    if (message === null || message === undefined || message.length === 0) {
      return '';
    }
    try {
      const obj: Record<string, Object> = JSON.parse(message) as Record<string, Object>;
      const paramsObj: Object | undefined = obj['params'];
      if (paramsObj !== null && paramsObj !== undefined) {
        const inner: Record<string, Object> = paramsObj as Record<string, Object>;
        const innerAction: Object | undefined = inner['action'];
        if (typeof innerAction === 'string' && innerAction.length > 0) {
          return innerAction as string;
        }
      }
      const topAction: Object | undefined = obj['action'];
      if (typeof topAction === 'string' && (topAction as string) !== 'message'
        && (topAction as string).length > 0) {
        return topAction as string;
      }
      return '';
    } catch (e) {
      // 不是合法 JSON，可能就是纯动作字符串
      return message;
    }
  }

  onRemoveForm(formId: string): void {
    hilog.info(DOMAIN, 'CalorieLite', 'card removed: %{public}s', formId);
  }

  onConfigurationUpdate(): void {
    // 深浅色由卡片页面按 colorMode:auto 自行处理。
    // 不接 Configuration 参数：common 命名空间下没有导出该类型，
    // 卡片也不需要响应配置变化。
  }

  onAcquireFormState(want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }
}
