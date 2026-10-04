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

export default class CalorieCardAbility extends FormExtensionAbility {

  /**
   * 把当日汇总整理成卡片能用的扁平数据。
   *
   * 卡片页面只做展示，不在里面读存储 —— 卡片 UI 里写业务逻辑
   * 会在每次刷新时重复执行，而且读不到就整块空白，不如在这里兜住。
   */
  private static buildData(): Record<string, Object> {
    const data: Record<string, Object> = {};
    // 先给全 0，保证任何一步失败时卡片仍能正常渲染出结构
    data['intake'] = 0;
    data['budget'] = 0;
    data['protein'] = 0;
    data['fat'] = 0;
    data['carb'] = 0;
    data['proteinTarget'] = 0;
    data['fatTarget'] = 0;
    data['carbTarget'] = 0;
    try {
      const home: HomeData = DailyService.homeData(todayKey());
      // 推荐克数按当日预算推算，与首页同源，避免两处数字互相矛盾
      const t: MacroTarget = macroTargetFor(home.summary.budget);
      data['intake'] = Math.round(home.summary.intake);
      data['budget'] = Math.round(home.summary.budget);
      data['protein'] = Math.round(home.summary.protein);
      data['fat'] = Math.round(home.summary.fat);
      data['carb'] = Math.round(home.summary.carb);
      data['proteinTarget'] = t.protein;
      data['fatTarget'] = t.fat;
      data['carbTarget'] = t.carb;
    } catch (err) {
      hilog.error(DOMAIN, 'CalorieLite', 'card data build failed: %{public}s', JSON.stringify(err));
    }
    return data;
  }

  /** 添加卡片：给出初始数据 */
  onAddForm(want: Want): formBindingData.FormBindingData {
    Store.init(this.context);
    return formBindingData.createFormBindingData(CalorieCardAbility.buildData());
  }

  /**
   * 定时刷新（updateDuration=1，即每 30 分钟一次）。
   *
   * 只负责把最新数据推给卡片；卡片页面收到后自行重绘。
   * 另外卡片页面自己也挂了 1 分钟的定时器，那是为了在应用正在使用时
   * 更快看到变化 —— 系统级的 updateForm 最快也是 30 分钟。
   */
  onUpdateForm(formId: string): void {
    Store.init(this.context);
    try {
      const binding: formBindingData.FormBindingData =
        formBindingData.createFormBindingData(CalorieCardAbility.buildData());
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
