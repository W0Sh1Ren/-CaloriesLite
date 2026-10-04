/**
 * 应用级共享状态。
 *
 * 页面之间跳转时不通过路由传参（路由参数是无类型的 Object，容易在 ArkTS 里踩坑），
 * 而是把「待确认的识别结果」这类跨页数据放在这里，跳转后由目标页读取。
 *
 * 另外这里存一份窗口安全区尺寸：EntryAbility 把窗口设为全屏布局后，
 * 状态栏和底部手势区会盖在内容上，各页面需要据此自行避让。
 */
import { FoodDraft, MealType } from '../model/Types';

/** 拍照识别页 → 首页 的待确认结果 */
export class PendingResult {
  /** 原图 uri，用于结果页展示缩略图 */
  imageUri: string = '';
  /** 识别出的食物草稿 */
  drafts: FoodDraft[] = [];
  /** 整图说明 */
  overallNote: string = '';
  /** 使用的模型 */
  model: string = '';

  constructor(imageUri: string, drafts: FoodDraft[], overallNote: string, model: string) {
    this.imageUri = imageUri;
    this.drafts = drafts;
    this.overallNote = overallNote;
    this.model = model;
  }
}

export class AppState {
  /** 拍照识别完成后暂存的结果，供结果确认页读取 */
  static pending: PendingResult | null = null;

  /** 历史页是否需要刷新（从相机页回来时置位） */
  static needRefreshHome: boolean = false;

  /** 识别页选中的餐次，跳转前设置 */
  static targetMeal: MealType = MealType.LUNCH;

  /**
   * 顶部安全区高度（vp）。
   *
   * 窗口设为全屏布局后，状态栏会盖在内容上，页面顶部需要留出这个高度。
   */
  static topInset: number = 0;

  /**
   * 底部安全区高度（vp）。
   *
   * 底部手势条区域会拦截点击，悬浮导航栏必须整体抬到这个高度之上，
   * 否则按钮按不动——这一条是实测踩出来的。
   */
  static bottomInset: number = 0;

  static clearPending(): void {
    AppState.pending = null;
  }
}
