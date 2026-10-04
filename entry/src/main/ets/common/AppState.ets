/**
 * 应用级共享状态。
 *
 * 页面之间跳转时不通过路由传参（路由参数是无类型的 Object，容易在 ArkTS 里踩坑），
 * 而是把「待确认的识别结果」这类跨页数据放在这里，跳转后由目标页读取。
 *
 * 另外这里存一份窗口安全区尺寸：EntryAbility 把窗口设为全屏布局后，
 * 状态栏和底部手势区会盖在内容上，各页面需要据此自行避让。
 */
import { DailySummary, FoodDraft, MealType } from '../model/Types';

/** 拍照识别页 → 首页 的待确认结果 */
export class PendingResult {
  /**
   * 送出识别的图片 uri 列表（可能多张），结果页用它们展示缩略图。
   * 记录只存第一张，避免每条记录都挂一串图。
   */
  imageUris: string[] = [];
  /** 识别出的食物草稿 */
  drafts: FoodDraft[] = [];
  /** 整图说明 */
  overallNote: string = '';
  /** 使用的模型 */
  model: string = '';
  /** 用户手写的补充说明，已随请求发给模型 */
  userNotes: string = '';

  constructor(imageUris: string[], drafts: FoodDraft[], overallNote: string, model: string,
    userNotes: string) {
    this.imageUris = imageUris;
    this.drafts = drafts;
    this.overallNote = overallNote;
    this.model = model;
    this.userNotes = userNotes;
  }

  /** 首图，用于记录里的缩略图 */
  firstImage(): string {
    return this.imageUris.length > 0 ? this.imageUris[0] : '';
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
   * 把当日数据镜像到 AppStorage，供各页面响应式读取。
   *
   * 为什么不只靠 @Watch(refreshTick) / onPageShow：
   * 那些回调的触发时机依赖页面栈实现，实测出现过「识别完回到首页，
   * 热量和营养素还是旧值，退出重进才更新」。AppStorage 是全局的，
   * 写入方一 set，所有 @StorageLink 绑定的界面当帧就会重算，
   * 不依赖任何页面生命周期。
   *
   * 这里只镜像「汇总数字」，记录明细仍由各页自己查存储——
   * 把整个列表塞进全局状态会带来不必要的耦合。
   */
  static mirrorToday(summary: DailySummary): void {
    AppStorage.setOrCreate('todayIntake', summary.intake);
    AppStorage.setOrCreate('todayProtein', summary.protein);
    AppStorage.setOrCreate('todayFat', summary.fat);
    AppStorage.setOrCreate('todayCarb', summary.carb);
    AppStorage.setOrCreate('todayBudget', summary.budget);
    AppStorage.setOrCreate('todayDeficit', summary.deficit);
  }

  /** 写入方在数据变动后调用，强制所有绑定界面重算 */
  static notifyDataChanged(): void {
    const stamp: number = Date.now();
    AppStorage.setOrCreate('dataStamp', stamp);
  }

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

  /**
   * 个人档案是否被改过。
   *
   * 「我的」页改完年龄/性别/活动量后，首页的热量预算要跟着变。
   * 页面之间没有直接引用关系，用这个标记让首页在下次显示时重算。
   */
  static profileDirty: boolean = false;

  static clearPending(): void {
    AppState.pending = null;
  }
}
