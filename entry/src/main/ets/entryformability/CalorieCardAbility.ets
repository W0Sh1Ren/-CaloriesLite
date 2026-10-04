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

export default class CalorieCardAbility extends FormExtensionAbility {

  /**
   * 把当日汇总整理成卡片能用的扁平数据。
   *
   * 卡片页面只做展示，不在里面读存储 —— 卡片 UI 里写业务逻辑
   * 会在每次刷新时重复执行，而且读不到就整块空白，不如在这里兜住。
   *
   * 所有字段都保证是**有意义的非零默认值**：
   * 卡片那边 @LocalStorageProp 的默认值是 0，绑定数据到位前会先渲染一帧，
   * 若这里也给 0，用户看到的就是「先闪一下 0 / 0 再变成真实数字」。
   * 给默认预算后，那一帧显示的是 0 / 2000，观感是正常的「今天还没吃」。
   */
  private static buildData(): Record<string, Object> {
    const data: Record<string, Object> = {};
    data['intake'] = 0;
    data['budget'] = DEFAULT_BUDGET;
    data['protein'] = 0;
    data['fat'] = 0;
    data['carb'] = 0;
    const dt: MacroTarget = macroTargetFor(DEFAULT_BUDGET);
    data['proteinTarget'] = dt.protein;
    data['fatTarget'] = dt.fat;
    data['carbTarget'] = dt.carb;
    try {
      const home: HomeData = DailyService.homeData(todayKey());
      const budget: number = Math.round(home.summary.budget);
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
