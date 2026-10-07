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
import { todayKey } from './DateUtil';
import { TOP_BAR_RESERVE } from './Theme';
import { common } from '@kit.AbilityKit';
import { formProvider } from '@kit.FormKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

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
   * 系统深浅色变化时，EntryAbility 调用它通知界面。
   *
   * 为什么需要单独一条通道：
   *   Theme 里的颜色是资源引用（$r），系统切主题时**属性值自动变**，
   *   所以大部分界面什么都不用做。
   *   但 **Canvas 不在这条通道里** —— 它的颜色是画上去的字符串，
   *   主题变了必须**重画**。首页的热量环就属于这种。
   *
   * 机制：把这个计数加一，页面用 @StorageLink 观察它，
   * 变化时触发一次重建 → 画布重绘（见 Index 的 themeTick）。
   */
  static notifyThemeChanged(): void {
    const cur: number = AppStorage.get<number>('themeTick') ?? 0;
    AppStorage.setOrCreate<number>('themeTick', cur + 1);
  }

  /**
   * 顶部安全区高度（vp）。
   *
   * 窗口设为全屏布局后，状态栏会盖在内容上，页面顶部需要留出这个高度。
   */
  static topInset: number = 0;

  /**
   * 页面内容顶部要为**官方标题栏**让出的总高度（状态栏 + 标题栏本体）。
   *
   * ══════════════════════════════════════════════════════════════
   * 这是全应用**唯一**的「内容从哪开始」的口径。
   * ══════════════════════════════════════════════════════════════
   * 首页与 5 个二级页面的顶栏现在都是同一套官方组件
   *（HdsNavigation 的 titleBar），高度一致，所以口径也应该只有一个 ——
   * 以后调间距只改这里，或者只改 TOP_BAR_RESERVE 那一个数。
   *
   * 用法：
   *     .padding({ top: AppState.contentTopOffset() })
   *
   * ⚠️ 为什么用 getter 而不是 static 字段：
   *    topInset 是 EntryAbility 启动后用 window.getAvoidArea **异步**量出来的
   *    （模块加载时还是 0）。若写成 static contentTopOffset: number = ...，
   *    它会在模块加载那一刻固化成 0 + 56 = 56，之后再也不会更新，
   *    页面顶部就会少让出整个状态栏的高度。
   *    getter 每次读取都重新算，永远拿到最新的 topInset。
   */
  static get contentTopOffset(): number {
    return AppState.topInset + TOP_BAR_RESERVE;
  }

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

  /**
   * 这次拍照识别要记到哪一天（YYYY-MM-DD）。
   *
   * 空串表示「今天」。从记录页给某一天补记时，先把日期写进这里，
   * 拍照页与确认页都读它 —— 确认保存时按它落库，并按它把首页切到那一天。
   *
   * 为什么必须显式传：确认页原来写死 `todayKey()`，
   * 于是不管从哪天进去补记，都会记到当天（用户反馈的 bug）。
   */
  static targetDay: string = '';

  /** 取本次要记录的目标日期；未设置时就是今天 */
  static effectiveTargetDay(): string {
    return AppState.targetDay.length > 0 ? AppState.targetDay : todayKey();
  }

  /** 清掉目标日期（保存完成或用户放弃时调用，避免影响下一次） */
  static clearTargetDay(): void {
    AppState.targetDay = '';
  }

  /**
   * 桌面卡片带来的目标页。
   *
   * 卡片的「拍照记录」区带 wantParams.cardRoute='camera' 拉起应用，
   * EntryAbility 把它写进这里，首页在刷新时读走并跳转，读完清空。
   * 用共享状态而不是路由参数：路由参数是无类型 Object，
   * 而且应用未启动时还没建立路由栈，只能等首页加载完再跳。
   */
  static cardRoute: string = '';

  /**
   * UIAbility 的上下文，供刷新桌面卡片用（EntryAbility 在 onCreate 时存入）。
   *
   * formProvider.reloadAllForms 只能在 UIAbility 里调用，且需要它的 context；
   * 记录保存发生在页面里，所以在这里存一份。
   */
  private static abilityContext: common.UIAbilityContext | null = null;

  /** EntryAbility 启动时调用 */
  static setAbilityContext(ctx: common.UIAbilityContext): void {
    AppState.abilityContext = ctx;
  }

  /**
   * 通知系统刷新桌面卡片。
   *
   * 用 reloadAllForms 而不是 updateForm：后者需要 formId，而 formId 只在
   * FormExtensionAbility.onAddForm 时拿得到，主应用进程与之不共享内存
   *（要跨进程共享得把 formId 落盘，见卡片实战文档第 9 节）。
   * reloadAllForms 由系统广播给卡片服务，卡片服务再走 onUpdateForm 重算，
   * 不需要主应用知道 formId。
   *
   * 失败只记日志：「记完一笔卡片立刻变」是体验优化，
   * 失败还有 30 分钟的定时刷新兜底，不该影响记录本身。
   */
  static refreshCard(): void {
    const ctx: common.UIAbilityContext | null = AppState.abilityContext;
    if (ctx === null) {
      return;
    }
    try {
      formProvider.reloadAllForms(ctx)
        .then((n: number) => {
          hilog.info(0x0000, 'CalorieLite', 'reloadAllForms -> %{public}d', n);
        })
        .catch((e: BusinessError) => {
          hilog.warn(0x0000, 'CalorieLite', 'reloadAllForms failed: %{public}s', e.message);
        });
    } catch (err) {
      hilog.warn(0x0000, 'CalorieLite', 'reloadAllForms unavailable');
    }
  }

  static clearPending(): void {
    AppState.pending = null;
  }
}
