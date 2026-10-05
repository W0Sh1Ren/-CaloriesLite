/**
 * 桌面卡片（2x2）的数据接口。
 *
 * 卡片进程与主应用进程相互独立，不能指望内存里的 @State 或 AppStorage，
 * 所以这里从偏好存储重新读一遍档案与当日记录，算出汇总再交给卡片页面。
 *
 * 必须在 onCreate 里调 Store.init(this.context)：不初始化的话
 * Store 的读取全部返回默认值，卡片会一直显示 0（而不是报错），很难排查。
 */
import { formBindingData, FormExtensionAbility, formInfo, formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { Store } from '../common/Store';
import { todayKey } from '../common/DateUtil';
import { DailyService, HomeData } from '../service/DailyService';
import { macroTargetFor, MacroTarget } from '../model/Enums';

const DOMAIN = 0x0000;

/**
 * 兜底默认预算（千卡）。
 *
 * 只在读不到档案时使用（例如首次安装、还没走设置向导）。
 * 不能给 0：卡片会先渲染一帧「0 / 0」再跳到真实值，用户看到的是闪一下。
 * 取 2000 接近普通成年人的维持热量，即使兜底也不会显示得离谱。
 */
const DEFAULT_BUDGET: number = 2000;

/*
 * 其余兜底值。
 *
 * 摄入与已吃克数保持一致：都是 0（今天还没记录），这是**真实**的展示值，
 * 不要为了「看起来有内容」编数字 —— 那会让用户以为已经记过了。
 * 有内容的部分（预算与营养素目标）已经给足，环与三条进度条都有刻度，
 * 整张卡片不会显得像没加载出来。
 *
 * 这几个值必须与 CalorieCard.ets 里 @LocalStorageProp 的声明初值一致。
 */
const DEFAULT_INTAKE: number = 0;
const DEFAULT_PROTEIN: number = 0;
const DEFAULT_FAT: number = 0;
const DEFAULT_CARB: number = 0;

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

  /** 数据变化后作废缓存（应用侧改完记录可以让卡片下次刷新拿到新值） */
  private static invalidateCache(): void {
    CalorieCardAbility.cachedData = null;
    CalorieCardAbility.cachedDay = '';
  }

  /**
   * 把当日汇总整理成卡片能用的扁平数据。
   *
   * 卡片页面只做展示，不在里面读存储 —— 卡片 UI 里写业务逻辑
   * 会在每次刷新时重复执行，而且读不到就整块空白，不如在这里兜住。
   *
   * 兜底值必须与 CalorieCard.ets 里 @LocalStorageProp 的声明初值
   * **逐一对齐**：卡片在绑定数据到位前会先按声明初值渲染一帧，
   * 两边不一致时那一帧的数字和最终值不同，看起来就是「闪一下」。
   */
  private static buildData(): Record<string, Object> {
    const data: Record<string, Object> = CalorieCardAbility.fallbackData();
    try {
      const home: HomeData = DailyService.homeData(todayKey());
      const budget: number = Math.round(home.summary.budget);
      hilog.info(DOMAIN, 'CalorieLite',
        'card data: storeReady=%{public}s budget=%{public}d intake=%{public}d',
        `${Store.isReady()}`, budget, Math.round(home.summary.intake));

      if (budget > 0) {
        // 推荐克数按当日预算推算，与首页同源，避免两处数字互相矛盾
        const t: MacroTarget = macroTargetFor(budget);
        data['budget'] = budget;
        data['proteinTarget'] = t.protein;
        data['fatTarget'] = t.fat;
        data['carbTarget'] = t.carb;
      }
      // 摄入与已吃克数可以真是 0（今天还没记录），照实写
      data['intake'] = Math.round(home.summary.intake);
      data['protein'] = Math.round(home.summary.protein);
      data['fat'] = Math.round(home.summary.fat);
      data['carb'] = Math.round(home.summary.carb);
    } catch (err) {
      hilog.error(DOMAIN, 'CalorieLite', 'card data build failed: %{public}s', JSON.stringify(err));
    }
    return data;
  }

  /**
   * 兜底数据。
   *
   * 与 CalorieCard.ets 的 @LocalStorageProp 初值保持一致，
   * 这样「绑定数据还没到」那一帧与真实数据帧长得一样，不会闪。
   *
   * 刻意**不填全 0**：全 0 时环形是空的、三条营养素条也是空的，
   * 整张卡片看着像没加载出来；给一组正常值后，
   * 「还没记录」在观感上就是「今天刚开始」，而不是「卡片坏了」。
   */
  private static fallbackData(): Record<string, Object> {
    const data: Record<string, Object> = {};
    const t: MacroTarget = macroTargetFor(DEFAULT_BUDGET);
    data['intake'] = DEFAULT_INTAKE;
    data['budget'] = DEFAULT_BUDGET;
    data['protein'] = DEFAULT_PROTEIN;
    data['fat'] = DEFAULT_FAT;
    data['carb'] = DEFAULT_CARB;
    data['proteinTarget'] = t.protein;
    data['fatTarget'] = t.fat;
    data['carbTarget'] = t.carb;
    return data;
  }

  /** 添加卡片：给出初始数据 */
  onAddForm(want: Want): formBindingData.FormBindingData {
    Store.init(this.context);
    // 用带缓存的入口：紧接着的 onUpdateForm 会拿到同一份内容，
    // 卡片不会被连续改写两次（那是「闪一下」的一个来源）
    return formBindingData.createFormBindingData(CalorieCardAbility.dataForToday());
  }

  /**
   * 定时刷新（updateDuration=1，即每 30 分钟一次）。
   *
   * 只负责把最新数据推给卡片；卡片页面收到后自行重绘。
   * 数据走 dataForToday() 的缓存，同一天不会因为
   * onAddForm / onUpdateForm 先后触发而推两份不同的内容。
   */
  onUpdateForm(formId: string): void {
    Store.init(this.context);
    try {
      const binding: formBindingData.FormBindingData =
        formBindingData.createFormBindingData(CalorieCardAbility.dataForToday());
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
