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
   * 当日数据变更的订阅回调。
   *
   * 为什么不用 AppStorage + @StorageLink：
   * @StorageLink 在装饰器绑定那一刻就要求 AppStorage 里存在同名键，
   * 而键是首次写入时才创建的，于是冷启动时绑定失败、整个应用起不来
   * （实测：加上 @StorageLink('dataStamp') 后进程启动即退出）。
   * 而且同一变量只能挂一个状态装饰器，没法用 @Watch 兜。
   *
   * 改用静态回调：谁持有数据谁把自己注册进来，写入方调
   * notifyDataChanged()，当前显示的页面立刻重读。
   * 无时序陷阱，也不依赖页面栈何时回调生命周期。
   */
  private static dataListener: (() => void) | null = null;

  /** 页面注册自己的刷新方法（在 aboutToAppear 里调用） */
  static setDataListener(fn: () => void): void {
    AppState.dataListener = fn;
  }

  /** 页面销毁时注销，避免回调指向已销毁的组件 */
  static clearDataListener(): void {
    AppState.dataListener = null;
  }

  /**
   * 把当日汇总镜像到 AppStorage，供将来需要跨页只读订阅的场景使用。
   *
   * 这里只是「写」：setOrCreate 会在键不存在时创建，
   * 不会触发上面那种绑定期异常。
   */
  static mirrorToday(summary: DailySummary): void {
    AppStorage.setOrCreate('todayIntake', summary.intake);
    AppStorage.setOrCreate('todayProtein', summary.protein);
    AppStorage.setOrCreate('todayFat', summary.fat);
    AppStorage.setOrCreate('todayCarb', summary.carb);
    AppStorage.setOrCreate('todayBudget', summary.budget);
    AppStorage.setOrCreate('todayDeficit', summary.deficit);
  }

  /**
   * 是否正有模态面板（底部弹层）打开。
   *
   * 打开时首页会把悬浮导航栏隐藏：面板是模态的，
   * 遮罩下不该还能点导航；而且导航栏在最上层，
   * 会把面板下半部分（体重输入框）压住。
   */
  static modalOpen: boolean = false;

  /** 写入方在数据变动后调用，通知当前页面立即重读 */
  static notifyDataChanged(): void {
    const fn: (() => void) | null = AppState.dataListener;
    if (fn !== null) {
      fn();
    }
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
