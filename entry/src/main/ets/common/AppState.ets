/**
 * 应用级共享状态。
 *
 * 页面之间跳转时不通过路由传参（路由参数是无类型的 Object，容易在 ArkTS 里踩坑），
 * 而是把「待确认的识别结果」这类跨页数据放在这里，跳转后由目标页读取。
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

  static clearPending(): void {
    AppState.pending = null;
  }
}
