/**
 * 轻卡记 —— 主页面。
 *
 * 结构：Stack 分三层，从下往上依次是
 *   1. 顶部柔光层（沉浸光感的来源，颜色随时段变化）
 *   2. 内容层（三个视图按选中项切换，带淡入位移动画）
 *   3. 悬浮导航栏（毛玻璃胶囊，浮在内容之上）
 *
 * 没有用 Tabs 组件：Tabs 的 tabBar 贴底且做不出毛玻璃悬浮效果，
 * 自己搭反而更好控制动画与层次。
 */
import { router, curves } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
// uiMaterial：系统材质（沉浸光感）。底部页签的悬浮样式靠它开材质。
import { uiMaterial } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { MealType, FoodRecord, ExerciseRecord } from '../model/Types';
import { MEAL_ORDER, mealTypeLabel, macroTargetFor, guessMealType } from '../model/Enums';
import { friendlyDate, todayKey, shiftDay, hourOf } from '../common/DateUtil';
import { DailyService, HomeData } from '../service/DailyService';
import { FoodRepo } from '../service/FoodRepo';
import { ImageService } from '../service/ImageService';
import { AppState } from '../common/AppState';
import {
  COLOR_BG, COLOR_CARD, COLOR_DIVIDER, COLOR_PRIMARY, COLOR_PRIMARY_SOFT, COLOR_TEXT, COLOR_TEXT_SUB, COLOR_WARN,
  CARD_SHADOW, CURVE_BOUNCE, DUR_MEAL_EXPAND, DUR_NORMAL, DUR_SLOW, DUR_VIEW_SWITCH, GAP, GlowPalette, NAV_HEIGHT, NAV_MARGIN,
  NAV_RESERVE, PAGE_PAD, RADIUS, VIEW_INACTIVE_SCALE, VIEW_SLIDE_X, glowForHour
} from '../common/Theme';
import { CalorieRing } from '../components/CalorieRing';
import { MacroBar } from '../components/MacroBar';
import { RollingNumber } from '../components/RollingNumber';
import { GlassTopBar, topReserve } from '../components/GlassTopBar';
import { RecordRow } from '../components/RecordRow';
import { MealFold } from '../components/MealFold';
import { FloatingNav, NavItem } from '../components/FloatingNav';
import { HistoryTab } from './HistoryTab';
import { ProfileTab } from './ProfileTab';

const DOMAIN = 0x0000;

/*
 * 这里原本有个 MEAL_BODY_PLACEHOLDER_H = 400，是「展开动画 1.0/2.0初期」
 * 用来让收起态内层能被布局的占位高度。已删除，原因：
 *   1. 占位值与真实高度不同 → 展开瞬间按占位值渲染，看起来是跳一下；
 *   2. 测量发生在「高度 = 占位值」的裁切容器里，内容超过 400 时
 *      量到的值被截断，写回去长度永远不够（超过 5 道菜只显示 5 道）。
 * 现在改成：收起态高度 0 但**不裁切**，内层按自然尺寸布局，
 * onAreaChange 直接量到真实高度，不需要占位值。
 */

/**
 * 首页悬浮「拍照识别」按钮的高度。
 *
 * 提成常量是因为滚动区的底部留白与按钮自身高度都要用它：
 * 分散写死会出现「按钮长高了但留白没跟着变」，
 * 最后一节内容被压住点不到。
 */
const CAMERA_BAR_HEIGHT: number = 50;

/** 判定为「翻日期滑动」的最小水平位移（vp）。理由同 CalendarHeatmap 里的同名常量 */
const DATE_SWIPE_MIN_VP: number = 40;

/**
 * 悬浮按钮底边距屏幕底的高度。
 *
 * 组成：底部安全区 + 导航栏外边距(30) + 导航栏高度 + 两条之间的呼吸(NAV_MARGIN)。
 * 这样按钮正好落在导航栏**正上方**，两者不重叠、也不贴在一起。
 */
function cameraFloatBottom(bottomInset: number): number {
  return bottomInset + 30 + NAV_HEIGHT + NAV_MARGIN;
}

/** 三个导航项 */
const NAV_ITEMS: NavItem[] = [
  new NavItem('首页', '◉'),
  new NavItem('记录', '▤'),
  new NavItem('我的', '☰')
];

@Entry
@Component
struct Index {
  @State dayKey: string = todayKey();
  @State data: HomeData = new HomeData();
  /** 当前视图下标。名字不能叫 tabIndex：ArkUI 的 CustomComponent 已有同名属性 */
  @State activeTab: number = 0;
  /** 每次从子页面返回自增，驱动子视图重新读数据 */
  /**
   * 数据刷新计数器。
   *
   * 加 @Watch 是有意为之：increment 时直接把数据重读一遍。
   * 只靠 onPageShow 不够稳——从相机/结果页 router.back() 回来时，
   * 生命周期回调的触发时机取决于页面栈实现，实测出现过
   * 「识别完回到首页，热量和营养素还是旧值，退出重进才更新」。
   * 走 @Watch 就是把「刷新」和「生命周期」解耦，只要计数器变了就一定重读。
   */
  /**
   * 子组件刷新信号：+1 只用于驱动 ProfileTab / HistoryTab 重新读取配置。
   *
   * 幂等，绝对不能在 reload() 内部自增！
   * reload() 一旦写这个变量就会触发 @Watch('onRefreshTick')
   * → reload() → 再写 → 无限递归，实测 60 多层后 RangeError: Stack overflow。
   * 它的唯一合法写入点是 onPageShow() 与 switchTo()（用户主动触发的路径）。
   */
  @State @Watch('onRefreshTick') refreshTick: number = 0;
  /** 重入守卫：兜住任何意外的自我触发，避免再次爆栈 */
  private isReloading: boolean = false;
  /** 顶部柔光配色，按当前时段取 */
  @State glow: GlowPalette = glowForHour(hourOf(Date.now()));
  /** 悬浮导航栏实测宽度，用于算高亮胶囊位置 */
  @State navWidth: number = 0;
  /** 顶部安全区（状态栏）高度，全屏布局后需要自行避让 */
  @State topInset: number = 0;
  /** 底部安全区（手势条）高度，导航栏必须抬到它之上才能点到 */
  @State bottomInset: number = 0;
  /** 已展开明细的餐次。默认为空即全部收起 */
  @State expandedMeals: MealType[] = [];
  /**
   * 悬浮拍照按钮是否处于「展开」状态。
   *
   * 它是 `dayKey === todayKey()` 的**动画化替身**：两者语义相同，
   * 但这个可以被 animateTo 平滑推到 0/1，而布尔条件渲染没有中间帧
   *（`if` 只会让节点整体出现或消失，观感是硬切）。
   *
   * 单独用一个 state 而不是每次现算 `this.dayKey === todayKey()`：
   * 现算的话，动画与数据更新会在同一帧里竞争，收缩到一半就被新值打断。
   * 这里由各处**显式**同步，更新时间点可控。
   */
  @State cameraBarOn: boolean = true;
  /**
   * 页面切换用的曲线。
   *
   * Swiper 的 .curve() 接受 ICurve。选 springMotion(0.86, 1.0)：
   * 阻尼比接近临界（1.0）→ 不回弹。跨多页平移时如果曲线欠阻尼，
   * 会冲过头把邻页边缘拖进视口再弹回，观感像「没对齐」。
   * 要的是「走完全程、稳稳停住」。
   */
  /**
   * Swiper 控制器：切换必须走 changeIndex() 才有动画。
   *
   * 关键区别（查 swiper.d.ts 确认）：
   *   .index(value)                     → 等同 changeIndex(value, false)，**瞬切无动画**
   *   .changeIndex(index, useAnimation) → 该方法本身支持动画
   * 之前只用 .index(activeTab)，所以点导航是硬切、看不到任何过渡。
   * 另外 .index() 与 changeIndex() 同时存在会打架（前者瞬切顶掉后者），
   * 所以 Swiper 上刻意不写 .index()。
   */
  private swiperController: SwiperController = new SwiperController();
  /**
   * 模态面板是否正打开。
   *
   * 必须是 @State：.visibility() 的参数要能在 build 里读到，
   * 而 AppState 的静态字段变化不会触发重建。
   */
  @State modalOpen: boolean = false;

  /**
   * 各餐次的展开透明度（展开动画 3.0）。
   *
   * 明细**高度**不再需要状态：由条数按固定单条高度算出来
   *（见 components/MealFold.ets 的 mealDetailHeight），
   * 所以不存在「量不到高度」的问题，记录增删也会自动跟着变。
   *
   * 透明度留在这里，是因为它要在 toggleMeal 的 animateTo 里和展开状态
   * 同一帧改变，动效才同步。
   *
   * 改动时换一个新 Map 才触发重建（ArkTS 只比较引用）。
   */
  @State mealAlphaMap: Map<MealType, number> = new Map<MealType, number>();

  /**
   * 数据版本号：每次重读当日数据就自增，传给环等自绘组件做强制重绘。
   *
   * 为什么不只依赖子组件的 onDidUpdate / @Watch：
   * 自绘（Canvas）组件在「父组件只换了数据对象」时收不到重绘通知，
   * 会出现数字变了、弧线还是旧比例。显式版本号是最确定的信号。
   */
  @State dataVersion: number = 0;

  aboutToAppear(): void {
    this.syncInsets();
    // 注册为「当日数据变更」的接收方：别的页面写入记录后会直接回调这里，
    // 不需要等页面生命周期，这正是「必须退出重进才更新」的解法。
    //
    // 这个回调同时也是「模态面板开关」的同步点：ProfileTab 打开底部面板时
    // 会置 AppState.modalOpen 再调 notifyDataChanged()，
    // 这里必须把它同步到本地 @State，导航栏才会隐藏。
    // （onRefreshTick 走的是 refreshTick 那条线，通知不到这里。）
    AppState.setDataListener(() => {
      this.modalOpen = AppState.modalOpen;
      this.setDayKey(todayKey());
      this.reload();
      this.consumeCardRoute();
    });
    this.modalOpen = AppState.modalOpen;
    this.reload();
  }

  aboutToDisappear(): void {
    AppState.clearDataListener();
  }

  /** 从子页面返回或回到前台时刷新。
   *
   * refreshTick 必须自增：ProfileTab / HistoryTab 靠它触发 onDidUpdate 重新读配置，
   * 否则从 AI 配置页保存后返回，「我的」页仍会显示未配置。 */
  onPageShow(): void {
    this.glow = glowForHour(hourOf(Date.now()));
    // 安全区是窗口异步量出来的，首次渲染时可能还是 0，回到前台再取一次
    this.syncInsets();
    if (AppState.needRefreshHome) {
      AppState.needRefreshHome = false;
      /*
       * 切到「本次记录的目标日期」而不是今天。
       *
       * 从记录页给某一天补记时，AppState.targetDay 已被设成那一天；
       * 平时它是空串，等价于今天。
       * 原来这里写死 todayKey()，于是补记完回来看到的是今天，
       * 用户会以为记错了地方（实际数据是记对了的）。
       */
      this.setDayKey(AppState.effectiveTargetDay());
      this.switchTo(0);
    }
    // 这里只自增信号、不直接调 reload()：onRefreshTick 会重读数据。
    // 两条路都写会重读两遍，而且容易忘了 reload 里不能再动 refreshTick。
    this.refreshTick++;

    /*
     * 回到首页时让拍照按钮重新展开。
     *
     * 点按钮跳去拍照页时把它设成了 false（收缩），回来必须还原，
     * 否则按钮会一直停在被压扁的状态。
     *
     * ⚠️ 这里用 setTimeout 延后一帧多，不是在跟动画抢时间，而是为了
     *    让「展开」从页面可见之后才开始：onPageShow 是在返回转场**期间**
     *    触发的，若同一帧就展开，撑开的过程会被转场画面盖掉一多半。
     *    等 260ms（约 DUR_NORMAL）让转场收尾，展开才看得完整。
     *
     * 只在「今天」展开：从历史日期回来时按钮本来就该是收起的。
     */
    setTimeout(() => {
      this.cameraBarOn = this.dayKey === todayKey();
    }, 260);
  }
  // 注意：这里不要改用 @StorageLink('dataStamp')。
  // 该装饰器在绑定那一刻就要求 AppStorage 里已存在同名键，
  // 而键只在首次写入时创建，冷启动会直接崩（实测进程启动即退出）。
  // 刷新走 AppState.setDataListener 注册的静态回调，见 aboutToAppear。

  /**
   * refreshTick 变化时重读当日数据。
   *
   * 这条链路本身是安全的：reload() 不再回写 refreshTick，
   * 环被打断了。isReloading 只是额外兜一层，
   * 万一以后有人在 reload() 里又写了 refreshTick，也只会被挡掉而不会爆栈。
   */
  onRefreshTick(): void {
    // 顺带同步模态面板状态，用于隐藏导航栏
    this.modalOpen = AppState.modalOpen;
    this.reload();
  }

  /** 把 EntryAbility 量好的安全区尺寸取到本地状态，驱动布局重算 */
  private syncInsets(): void {
    this.topInset = AppState.topInset;
    this.bottomInset = AppState.bottomInset;
  }

  /**
   * ⚠️ 已废弃，不再被调用。
   *
   * 原来这里是「Swiper 三页并排 + 平移切换」。换成 Tabs 之后，
   * 三个视图直接作为 TabContent 的子节点（见 build()），
   * Tabs 内置的分页几何与滑动替代了这段 Swiper 逻辑。
   *
   * 保留在文件里是因为它记录了一个踩过的坑（百分比宽度按父容器解析、
   * 手写平移会对不上），删掉就丢了这段教训。确认新方案稳定后可以整段删除
   *（连同 swiperController 与顶部那几行注释）。
   */
  @Builder
  contentView() {
    Stack({ alignContent: Alignment.Top }) {
      /*
       * 视口容器：只负责裁切。
       *
       * 内部那条 Row 有 3 屏宽，必须裁掉溢出部分，
       * 否则整条 Row 会溢出屏幕、把页面顶歪。
       */
      Column() {
        /*
         * 用 Swiper 而不是「Row + translate」。
         *
         * 之前手写平移踩了一整类坑：Row 宽 3 屏时子页的百分比宽度会被
         * 放大（ArkUI 的百分比按父容器解析），于是子页间距与位移量对不上，
         * 表现就是「点首页显示记录、点记录显示我的、点我的空白」。
         * 试过像素宽度、实测视口宽度，都没能同时对上宽度与间距。
         *
         * Swiper 内置处理分页几何，平移也是它的本意语义：
         * 从第 0 页切到第 2 页会**连续经过**第 1 页，正是要的观感。
         * 关掉手动滑动（disableSwipe）——切换只由底部导航驱动。
         */
        Swiper(this.swiperController) {
          Column() {
            this.todayView()
          }
          .width('100%')
          .height('100%')

          Column() {
            HistoryTab({ dayKey: this.dayKey, refreshTick: this.refreshTick })
          }
          .width('100%')
          .height('100%')

          Column() {
            ProfileTab({ refreshTick: this.refreshTick })
          }
          .width('100%')
          .height('100%')
        }
        .loop(false)
        /*
         * 刻意**不写 .index(this.activeTab)**。
         *
         * .index() 是声明式绑定，值一变就瞬切（等同 changeIndex(v, false)），
         * 会把 changeIndex(index, true) 的动画顶掉 —— 两者同时存在就是打架，
         * 结果还是硬切。所以页码只由控制器的 changeIndex 驱动，
         * activeTab 只用于顶栏标题与导航高亮。
         */
        .disableSwipe(true)
        .indicator(false)
        /*
         * 420ms：跨两页平移是一段不短的距离，340ms 收得太快、
         * 看不出「经过中间页」。420ms 既能看清连续扫过，又不拖沓
         *（对齐 iOS 整屏翻页的节奏）。
         */
        .duration(420)
        /*
         * 用时长型曲线，**不要用 springMotion**。
         *
         * 踩过的坑：springMotion 自带时间常数，会忽略 .duration()，
         * 于是动画在极短时间内走完，观感就是「完全没有动画」
         *（实测：duration 设 1500ms 仍然瞬切）。
         * FastOutSlowIn 按 duration 走的「快出慢入」，
         * 跨多页平移时既有速度感又能稳稳收尾。
         */
        .curve(Curve.FastOutSlowIn)
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('100%')
      .clip(true)

      // 顶层：毛玻璃顶栏。zIndex(1) 保证盖在内容之上。
      // 首页的右上角放一对步进按钮用于切换日期——之前把内嵌日期栏删掉时
      // 忘了把入口搬过来，导致首页没法切日期了。
      GlassTopBar({
        title: this.topTitle(),
        subtitle: this.topSubtitle(),
        leadingGlyph: '',
        trailingGlyphs: this.activeTab === 0 ? ['‹', '›'] : [],
        // 「今天」时不能再往后翻，把右箭头置灰
        trailingEnabled: [true, this.dayKey !== todayKey()],
        onTrailing: (index: number) => {
          this.shiftDate(index === 0 ? -1 : 1);
        }
      })
        .zIndex(1)
        .hitTestBehavior(HitTestMode.Transparent)
    }
    .width('100%')
    .height('100%')
  }

  /** 顶栏主标题 */
  private topTitle(): string {
    if (this.activeTab === 1) {
      return '记录';
    }
    if (this.activeTab === 2) {
      return '我的';
    }
    return this.dayKey === todayKey() ? '今天' : friendlyDate(this.dayKey);
  }

  /** 顶栏副标题 */
  /** 顶栏副标题 */
  private topSubtitle(): string {
    if (this.activeTab === 1) {
      return '查看历史与体重趋势';
    }
    if (this.activeTab === 2) {
      return '个人情况与 AI 配置';
    }
    return this.dayKey === todayKey() ? friendlyDate(this.dayKey) : '查看历史';
  }

  /**
   * 把记录里的图片从缓存转存到持久目录。
   *
   * 相机与相册给的 uri 都在临时目录，缓存也可能被系统回收，
   * 直接落库的话过几天图片就丢了。这里在读取记录时顺手转存一份，
   * 并把记录里的 uri 换成持久路径。
   *
   * 注意必须用 update 而不是 addMany：addMany 是纯追加、不按 id 去重，
   * 用它会把当天每条记录都复制一遍。
   */
  /**
   * 图片转存与去重（每次加载只跑一次）。
   *
   * 相机与相册给的 uri 都在临时目录，缓存也可能被系统回收，
   * 直接落库的话过几天图片就丢了，所以要转存到 filesDir。
   *
   * 两个关键点：
   *   1. 整批共用一个 memo（persistAll）。同一餐的多道菜共享同一组照片，
   *      逐条转存会把一张图复制 N 份——实测 2 张照片被复制成 20 个文件，
   *      详情页里图片就会一直重复滚动。
   *   2. 落盘必须用 update 而不是 addMany：后者纯追加、不按 id 去重，
   *      会把当天记录整体复制一遍。
   */
  private persistImages(): void {
    // 先做一次全量收敛：合并内容相同的重复文件并删掉孤立的
    // 只跑一次：dedupeImages 要读每张照片的全部字节做两两比对，
    // 而 persistImages 会随 reload 反复触发（三页常驻后更频繁），
    // 每次都全量重跑会明显拖慢翻日期/切页。
    if (!this.imagesPersisted) {
      this.imagesPersisted = true;
      ImageService.dedupeImages(this.data.records, this.uiContext(), (r: FoodRecord) => {
        FoodRepo.update(r);
      });
    }

    for (const r of this.data.records) {
      const list: string[] = r.gallery();
      if (list.length === 0) {
        continue;
      }
      let needs: boolean = false;
      for (const u of list) {
        if (!u.includes('/food_images/')) {
          needs = true;
          break;
        }
      }
      if (!needs) {
        continue;
      }
      const saved: string[] = ImageService.persistAll(list, this.uiContext());
      r.imageUris = saved;
      r.imageUri = saved[0];
      FoodRepo.update(r);
      hilog.info(DOMAIN, 'CalorieLite', 'persisted %{public}d image(s) for %{public}s',
        saved.length, r.id);
    }
  }

  private uiContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  /** 图片维护是否已跑过，避免重复转存 */
  private imageTaskDone: boolean = false;
  /**
   * 图片去重是否已跑过。
   *
   * 与 imageTaskDone 分开：那个管的是「要不要安排这次维护」，
   * 这个管的是「去重这个重活有没有跑过」。dedupeImages 要读全部字节
   * 做两两比对，重复跑代价很高，而 persistImages 会随 reload 反复进入。
   */
  private imagesPersisted: boolean = false;

  /**
   * 重读当日数据。
   *
   * 两个硬性约束，改这个函数前务必先看懂：
   *   1. 绝对不要在这里写 this.refreshTick！它是 @Watch('onRefreshTick')
   *      的触发源，而 onRefreshTick 又会调回本函数，
   *      于是 reload → tick++ → watch → reload → … 无限递归，
   *      60 多层后直接 RangeError: Stack overflow（已实测）。
   *      子组件的刷新信号只在 onPageShow / switchTo 里 +1。
   *   2. 不要在这里同步调用需要 UIContext 的操作（如取沙箱路径），
   *      aboutToAppear 阶段组件尚未挂载，getUIContext 会失败。
   *      图片相关的维护交给 scheduleImageMaintenance 延后执行。
   */
  private reload(): void {
    // 重入守卫：任何意外触发的嵌套调用直接返回，避免栈被撑爆
    if (this.isReloading) {
      return;
    }
    this.isReloading = true;
    try {
      /*
       * 换日期后明细高度不需要在这里清理：
       * 各餐次的明细高度由 MealFold 自己持有，而它的 content 会随
       * 当日记录重建，onAreaChange 会重新报一次真实高度。
       * （早期版本把高度缓存在页面里，换天必须手动清，否则沿用旧长度。）
       */
      this.data = DailyService.homeData(this.dayKey);
      AppState.mirrorToday(this.data.summary);
      // 自增版本号，驱动环等自绘组件重绘
      this.dataVersion++;
      this.scheduleImageMaintenance();
      /*
       * 顺手刷新桌面卡片。
       *
       * 放在 reload 里而不是每个「保存成功」的分支里：reload 是当日数据
       * 变更的唯一汇聚点（别的页面写入后都会回调到 dataListener → reload），
       * 写一处就覆盖全部入口 —— 拍照确认、补记、删除、运动、体重。
       * reload 有重入守卫，卡片刷新也不会反向触发这里，不会形成回路。
       */
      AppState.refreshCard();
    } catch (err) {
      const e: Error = err as Error;
      hilog.error(DOMAIN, 'CalorieLite', 'reload failed: %{public}s', e.message);
    } finally {
      this.isReloading = false;
    }
  }

  /** 布局完成后再做图片转存/去重，避免在构建期取 UIContext */
  private scheduleImageMaintenance(): void {
    if (this.imageTaskDone) {
      return;
    }
    setTimeout(() => {
      if (this.imageTaskDone) {
        return;
      }
      this.imageTaskDone = true;
      this.persistImages();
    }, 300);
  }

  /**
   * 设置当前查看的日期，并同步拍照按钮的显隐。
   *
   * 为什么要有这个函数：`dayKey` 和 `cameraBarOn` 必须**永远一致**
   *（一个是数据，一个是它的动画化表现），但 `dayKey` 有三四个写入点。
   * 之前每处各写一行 `this.dayKey = ...`，加 `cameraBarOn` 时就要改好几处，
   * 漏一个就会出现「历史日期上还浮着拍照按钮」。
   * 现在所有写入点都走这里，只改一个地方。
   */
  private setDayKey(day: string): void {
    this.dayKey = day;
    // 箭头函数体里不能有语句，所以这里写成普通判断
    if (day === todayKey()) {
      this.cameraBarOn = true;
    } else {
      this.cameraBarOn = false;
    }
  }

  /**
   * 点顶部页签时的切换请求。
   *
   * 只改 `activeTab`，**不在这里刷新数据** —— Tabs 的 `index` 参数是双向的，
   * 改了这个 state 之后 Tabs 会切页并回调 `onChange`，
   * 而 `onTabIndexChanged` 才是「切换后刷新」的唯一入口。
   *
   * 两处都写刷新会重读两遍数据（本项目在 refreshTick 上踩过同类坑）。
   */
  private switchTo(index: number): void {
    if (index === this.activeTab) {
      // 已经在这一页：仍然刷新一次，避免「点了没反应但数据其实变了」的情况
      if (index === 0) {
        this.setDayKey(this.homeDayForReturn());
        this.refreshTick++;
      }
      return;
    }
    if (AppState.profileDirty) {
      AppState.profileDirty = false;
    }
    // 只提交下标：Tabs 会据此切页（带它自己的平移动画），并回调 onChange
    this.activeTab = index;
  }

  /**
   * 页签下标变化的**唯一处理入口**（Tabs 的 onChange）。
   *
   * 为什么必须走这里而不是只在 switchTo 里刷新：
   * 官方 Tabs 自带左右滑动切页，用户可以**直接滑**而不点页签 ——
   * 那条路径不经过 switchTo。把刷新挂在 onChange 上，
   * 点页签与滑页签才会走同一套逻辑。
   */
  private onTabIndexChanged(index: number): void {
    this.activeTab = index;
    // 回到首页时重读，保证刚记录的餐次立刻出现
    if (index === 0) {
      this.setDayKey(this.homeDayForReturn());
      this.refreshTick++;
    }
  }

  /**
   * 回到首页时该显示哪一天。
   *
   * 用 AppState 记下的「本次记录的目标日期」：
   *   · 从记录页给某一天补记 → 停在补记的那一天（用户要求）；
   *   · 平时没有目标日期 → 就是今天。
   *
   * 注意读完后**不清空** targetDay：onPageShow 与 switchTo 可能先后触发，
   * 先清掉的话第二次就会退回今天。真正清空在用户离开这条流程时
   *（见 Index.shiftDate 与 Camera 的说明）。
   */
  private homeDayForReturn(): string {
    return AppState.effectiveTargetDay();
  }

  private mealKcal(records: FoodRecord[]): number {
    let sum: number = 0;
    for (const r of records) {
      sum += r.kcal;
    }
    return Math.round(sum);
  }

  /** 删除一条记录，删前确认 */
  private async confirmDelete(record: FoodRecord): Promise<void> {
    try {
      const result = await promptAction.showDialog({
        title: '删除记录',
        message: `确定删除「${record.name}」吗？`,
        buttons: [
          { text: '取消', color: COLOR_TEXT_SUB },
          { text: '删除', color: '#E5533D' }
        ]
      });
      if (result.index === 1) {
        FoodRepo.remove(record.dayKey, record.id);
        this.reload();
        this.refreshTick++;
      }
    } catch (err) {
      hilog.error(DOMAIN, 'CalorieLite', 'delete dialog failed: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 左右滑切换日期。
   *
   * 与顶栏的步进按钮走同一条 shiftDate 链路（含未来日期拦截）。
   * 阈值 40vp：不设阈值的话，点餐次折叠、点记录行时的轻微横向抖动
   * 都会被判成翻日期——这些是首页最常用的操作，误触代价很高。
   */
  private onDateSwipe(dx: number): void {
    if (Math.abs(dx) < DATE_SWIPE_MIN_VP) {
      return;
    }
    // 手指向左滑（dx < 0）→ 看后一天
    this.shiftDate(dx < 0 ? 1 : -1);
  }

  private shiftDate(delta: number): void {
    const next: string = shiftDay(this.dayKey, delta);
    if (next > todayKey()) {
      // 已经是最新一天：给个反馈，否则滑动像「没反应」
      if (delta > 0) {
        promptAction.showToast({ message: '已经是最新一天了' });
      }
      return;
    }
    this.setDayKey(next);
    this.reload();
  }

  build() {
    /*
     * 用 Alignment.Top（水平居中）而不是 TopStart（左对齐）。
     *
     * 底部导航栏是 92% 宽的胶囊，父层若左对齐它就会贴在屏幕左边
     * ——实测 left=0 / right=1178 / 屏宽 1280，整体左偏 51px，
     * 看起来就是「导航栏歪了」。改成水平居中后左右留白相等。
     */
    Stack({ alignContent: Alignment.Top }) {
      // ---------------------------------------------------- 1. 柔光背景
      // 铺满整屏（含状态栏区域），这才是「沉浸」的前提
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [[this.glow.from, 0.0], [this.glow.to, 0.42], [COLOR_BG, 1.0]]
        })

      // ---------------------------------------------------- 2. 内容层 + 底部页签
      /*
       * ══════════════ 用 Tabs 替换原来的 Swiper + 自绘 FloatingNav ══════════════
       *
       * 为什么换：**官方沉浸光感（系统材质）只在这两个位置生效** ——
       * Navigation/NavDestination 标题栏，或「横向 Tabs 中 barPosition 为
       * BarPosition.End 的底部 TabBar」。自绘的 Row 容器设 systemMaterial()
       * **完全不生效**（官方原文，且把「在标题栏生效范围外为整页背景设置材质」
       * 列为反例）。
       *
       * 换了之后拿到的东西：
       *   · 真实系统材质（THIN 档），随设备算力与用户「沉浸光感强弱」设置自适应
       *   · interactive: true  → 交互形变（按压时的弹性形变）
       *   · lightEffect        → 点光源/流光交互反馈
       *   · adaptToHandedness  → 按左右手习惯适配
       * 代价：丢掉自绘的 Canvas 跟手光斑（FloatingNav 不再使用）
       *
       * ⚠️ 悬浮样式生效的三个条件（官方明确要求**同时满足**）：
       *      barOverlap(true) + vertical 为 false（默认即是）+
       *      barPosition 为 BarPosition.End
       *   缺一个 systemMaterial 就不生效。
       *
       * ⚠️ 设了悬浮材质后**不能再设** barBackgroundColor / barBackgroundBlurStyle，
       *    否则会遮挡材质。所以这里一个都不设。
       */
      Tabs({ barPosition: BarPosition.End, index: this.activeTab }) {
        TabContent() {
          Column() {
            this.todayView()
          }
          .width('100%')
          .height('100%')
        }
        .tabBar('首页')

        TabContent() {
          Column() {
            HistoryTab({ dayKey: this.dayKey, refreshTick: this.refreshTick })
          }
          .width('100%')
          .height('100%')
        }
        .tabBar('记录')

        TabContent() {
          Column() {
            ProfileTab({ refreshTick: this.refreshTick })
          }
          .width('100%')
          .height('100%')
        }
        .tabBar('我的')
      }
      /*
       * 页签栏本身的高度。
       *
       * 不设的话系统给的是默认高度（偏高的标准 TabBar），
       * 与我们原来那条 70vp 的胶囊对不上。这里按原来的视觉高度收紧。
       */
      .barHeight(56)
      /*
       * 悬浮页签栏 —— 沉浸光感的入口。
       *
       * 🌟 systemMaterial 必须显式写在这里。官方说明：
       *    「应用级 ENABLE 模式下底部页签**不会**默认开启沉浸光感；
       *      设置 barFloatingStyle 并生效悬浮样式时，底部页签默认开启」
       *    但实测把材质对象显式传进去最稳（也才能自定义 interactive /
       *    lightEffect 这两项）。
       */
      .barFloatingStyle({
        // 左右留白：与内容区的 PAGE_PAD 对齐，不然页签栏比卡片宽一圈
        barSideMargin: PAGE_PAD,
        // 抬离屏幕底部，让出手势条 + 留一点视觉呼吸
        barBottomMargin: this.bottomInset + 30,
        adaptToHandedness: true,
        systemMaterial: new uiMaterial.ImmersiveMaterial({
          // THIN：胶囊背景要透出内容才像玻璃；ULTRA_THIN 在浅色页面上几乎看不见
          style: uiMaterial.ImmersiveStyle.THIN,
          applyShadow: true,
          // 交互形变：按压时的弹性形变（就是别家导航栏那种「果冻」感）
          interactive: true,
          // 点光源/流光：手指触摸时的光感反馈
          lightEffect: { color: Color.White }
        })
      })
      /*
       * ⚠️ 这三个是悬浮样式的**前置条件**，不是可选修饰。
       */
      .barOverlap(true)
      .vertical(false)
      /*
       * 底部页签自带的滑动切换：原来靠 Swiper 做「连续经过中间页」的平移，
       * Tabs 内置的分页几何等价，而且与页签栏是同一套动效语言，不用自己接。
       */
      .animationDuration(420)
      /*
       * 页签切换的唯一入口。
       *
       * 官方 Tabs 自带左右滑动，用户可能直接滑而不是点页签，
       * 所以「切换后要刷新数据」不能只挂在自己的 switchTo 上 ——
       * 必须让 onChange 成为唯一入口，否则滑动切页不会重读数据。
       */
      .onChange((index: number) => {
        this.onTabIndexChanged(index);
      })
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    // 让背景铺到状态栏和手势区下面。不加这句，根节点会被安全区限制在
    // [0,137] 起，顶部柔光就永远铺不到屏幕顶端（实测确认过）。
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .backgroundColor(COLOR_BG)
  }

  // ================================================== 首页
  @Builder
  todayView() {
    /*
     * 用 Stack 而不是 Column：拍照按钮要**悬浮**在内容之上，
     * 而不是作为固定底栏把内容挤上去、自己占掉一条横带。
     *
     * 悬浮 vs 固定底栏的差别不只是位置：
     *   固定底栏会形成一条「分界线」，内容到此为止
     *   悬浮时内容从按钮下面穿过去，按钮像一颗浮起来的气泡
     * 与底部导航栏是同一套语言。
     */
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        Scroll() {
          // 顶部留出毛玻璃顶栏的高度，否则第一张卡片会被顶栏压住
          Column({ space: GAP }) {
            CalorieRing({
              intake: this.data.summary.intake,
              budget: this.data.summary.budget,
              exerciseKcal: this.data.summary.exerciseKcal,
              deficit: this.data.summary.deficit,
              // 计划缺口（TDEE − 每日目标）：环用它把缺口分三档（达标/未达标/超出）
              deficitPlanned: this.data.summary.plannedDeficit,
              refreshKey: this.dataVersion
            })

            // 结算评语
            Row() {
              Text(DailyService.verdict(this.data.summary))
                .fontSize(13)
                .fontColor(COLOR_TEXT_SUB)
                .layoutWeight(1)
            }
            .width('100%')
            .padding({ left: 4, right: 4 })

            /*
             * 目标被 BMR 地板顶掉时的提示。
             *
             * 触发条件：用户选的「目标调整」会把每日目标压到 BMR 以下，
             * calcDailyBudget 便把它抬回 BMR —— **用户选的目标没生效**。
             *
             * 为什么必须显式提示：不提示的话，用户以为自己在按 −500 减脂，
             * 实际每日目标比预期高，「缺口」也会比预期小，
             * 而界面上一切正常，用户只会觉得「怎么减得这么慢」。
             */
            if (this.data.floorApplied) {
              Row({ space: 6 }) {
                Text('⚠️')
                  .fontSize(12)
                Text(`所选目标会使每日目标低于基础代谢（${this.data.bmr} 千卡），已按基础代谢计。`
                    + `原本 ${this.data.requestedBudget} → 现为 ${this.data.summary.budget} 千卡`)
                  .fontSize(12)
                  .fontColor(COLOR_WARN)
                  .layoutWeight(1)
              }
              .width('100%')
              .padding({ left: 12, right: 12, top: 8, bottom: 8 })
              .backgroundColor('#1AE5533D')
              .borderRadius(10)
              .margin({ left: 4, right: 4 })
            }

            Row({ space: 14 }) {
              if (this.data.streak > 0) {
                this.chip('连续达标', () => this.data.streak, '天')
              }
              if (this.data.summary.exerciseKcal > 0) {
                this.chip('运动 +', () => this.data.summary.exerciseKcal, '')
              }
            }
            .width('100%')
            .padding({ left: 4, right: 4 })

            // 营养素卡片常显：没有记录时也要能看到推荐量，
            // 否则用户不知道今天该吃多少
            MacroBar({
              protein: this.data.summary.protein,
              fat: this.data.summary.fat,
              carb: this.data.summary.carb,
              // 推荐克数按当日实际预算推算，不写死数字：
              // 写死会在换人/换目标后与顶部预算自相矛盾
              carbTarget: macroTargetFor(this.data.summary.budget).carb,
              proteinTarget: macroTargetFor(this.data.summary.budget).protein,
              fatTarget: macroTargetFor(this.data.summary.budget).fat
            })

            ForEach(MEAL_ORDER, (meal: MealType) => {
              this.mealSection(meal)
            }, (meal: MealType) => `${meal}-${this.data.summary.recordCount}`)

            this.exerciseSection()

            /*
             * 底部留白 = 悬浮按钮 + 悬浮导航栏两层占位 + 一段净空。
             *
             * 顺序（从屏幕底往上）：导航栏 → 呼吸 → 按钮 → 净空。
             *
             * 净空不能省：导航栏只有 92% 宽，两侧各留 8% 的缝，
             * 那条缝里透出的内容**不在模糊范围内**，会原样显示出来，
             * 看上去像导航栏破了个洞。留够净空，滚动到底时那一带也是空的。
             */
            Row().height(cameraFloatBottom(this.bottomInset) + CAMERA_BAR_HEIGHT + 120)
          }
          .width('100%')
          .padding({ left: PAGE_PAD, right: PAGE_PAD, top: topReserve() + 4 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        /*
         * 滑到顶/底后继续滑会拉出空白并回弹 —— 用系统内置的弹簧效果。
         *
         * 曾经自己实现过一版（用 onScrollFrameBegin 拦下增量、按阻尼公式平移
         * 内容、松手再动画收回），目标是做「超出越多越拉不动」的非线性阻尼。
         * **失败了**，两个问题：
         *   1. 把 onScrollFrameBegin 的返回值设成 0 会把正常滚动一起吃掉 ——
         *      页面直接滑不动（实测）
         *   2. 回弹时机对不上：onScrollStop 在内层 fling 结束才触发，
         *      表现是「拉出去了，但不弹回来」
         * 内置 Spring 虽然没有可自定义的阻尼曲线，但它可靠、手感也够用。
         * 结论：跟滚动物理耦合的东西，优先交给系统。
         */
        .edgeEffect(EdgeEffect.Spring)
      }
      .width('100%')
      .height('100%')

      /*
       * 悬浮主操作：拍照识别。
       *
       * **只在「今天」显示**（用户要求）：
       * 翻到历史某天时，这个按钮的语义是「现在拍一张」——那必然记到今天，
       * 与当前正在看的日期不一致，容易误操作。
       * 历史日期要补记，走「记录」页的补记入口（那里会把日期带上）。
       *
       * ⚠️ 这里**常挂载**，用 scaleX 收缩来「消失」，不用 `if` 条件渲染：
       *    `if` 只让节点整体出现/消失，没有任何中间帧，观感是硬切。
       *    改成缩放后，收起时从两端向中间压扁、展开时反向撑开，才有动作。
       */
      this.cameraBar()
    }
    .width('100%')
    .height('100%')
    /*
     * 左右滑切换日期，与顶栏的步进按钮同一条链路。
     *
     * 只认水平方向，纵向留给内容滚动（两者不冲突）。
     * 阈值在 onDateSwipe 里判：不设阈值的话，点餐次折叠、点记录行时的
     * 轻微横向抖动都会被判成翻日期。
     */
    .gesture(
      PanGesture({ direction: PanDirection.Horizontal })
        .onActionEnd((event: GestureEvent) => {
          this.onDateSwipe(event.offsetX);
        })
    )
  }

  /** 日期切换条 */
  @Builder
  dateBar() {
    Row() {
      Button({ type: ButtonType.Circle }) {
        Text('‹').fontSize(20).fontColor(COLOR_TEXT)
      }
      .width(36)
      .height(36)
      .backgroundColor(COLOR_CARD)
      .shadow(CARD_SHADOW)
      .onClick(() => {
        this.shiftDate(-1);
      })

      Column({ space: 2 }) {
        Text(this.dayKey === todayKey() ? '今天' : friendlyDate(this.dayKey))
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_TEXT)
        // 副标题只在「今天」时补一个日期；看历史日期时标题本身就是日期，
        // 再重复一次没有信息量
        Text(this.dayKey === todayKey() ? friendlyDate(this.dayKey) : '查看历史')
          .fontSize(12)
          .fontColor(COLOR_TEXT_SUB)
      }
      .layoutWeight(1)

      Button({ type: ButtonType.Circle }) {
        Text('›')
          .fontSize(20)
          .fontColor(this.dayKey === todayKey() ? COLOR_DIVIDER : COLOR_TEXT)
      }
      .width(36)
      .height(36)
      .backgroundColor(COLOR_CARD)
      .shadow(CARD_SHADOW)
      .enabled(this.dayKey !== todayKey())
      .opacity(this.dayKey === todayKey() ? 0.5 : 1)
      .onClick(() => {
        this.shiftDate(1);
      })
    }
    .width('100%')
    .padding({ left: PAGE_PAD, right: PAGE_PAD, top: 10, bottom: 10 })
  }

  /**
   * 一个小标签：前缀文字 + 会滚动的数字 + 单位。
   *
   * 数字必须走 RollingNumber 且由这里内联渲染：
   * 之前整个标签是 this.chip(`连续达标 ${n} 天}`) 这样传字符串，
   * @Builder 的参数只求值一次，数字变了标签也不会更新；
   * 而且纯 Text 是瞬间跳变，没有滚动感。
   */
  @Builder
  chip(label: string, value: () => number, unit: string) {
    Row({ space: 2 }) {
      Text(label)
        .fontSize(12)
        .fontColor(COLOR_PRIMARY)
      RollingNumber({
        value: value(),
        fontSize: 12,
        fontWeight: FontWeight.Medium,
        textColor: COLOR_PRIMARY,
        duration: DUR_SLOW
      })
      Text(unit)
        .fontSize(12)
        .fontColor(COLOR_PRIMARY)
    }
    .alignItems(VerticalAlign.Center)
    .padding({ left: 10, right: 10, top: 5, bottom: 5 })
    .backgroundColor(COLOR_PRIMARY_SOFT)
    .borderRadius(12)
  }

  /**
   * 展开/收起某一餐。
   *
   * 套用「展开动画 2.0」（docs/展开动画2.0.md）：
   * 高度即时变化 + 透明度用 animateTo 插值，动效来自透明度。
   *
   * 明细的**高度**由 MealFold 组件各自持有 —— 早期版本把高度存在本组件里
   * 用 Map<meal, number> 共用，结果是 onAreaChange 的归属不可靠，
   * 出现「箭头显示展开、内容却是空的」。这里只维护「展开状态 + 透明度」。
   */
  private toggleMeal(meal: MealType): void {
    const next: MealType[] = [];
    let removed: boolean = false;
    for (const m of this.expandedMeals) {
      if (m === meal) {
        removed = true;
      } else {
        next.push(m);
      }
    }
    /*
     * 展开与收起都不需要重置高度：高度在 MealFold 内部，
     * 收起期间它已经量成真实值，展开时直接用它，起点就是对的。
     * （早期版本在展开前把高度重置成占位值 400，
     * 那个值与真实高度不同，于是展开瞬间会按 400 渲染一下 —— 看起来是跳一下。）
     */
    if (!removed) {
      next.push(meal);
      this.getUIContext().animateTo({ duration: DUR_MEAL_EXPAND, curve: Curve.EaseInOut }, () => {
        this.expandedMeals = next;
        this.setMealAlpha(meal, 1);
      });
      return;
    }
    this.getUIContext().animateTo({ duration: DUR_MEAL_EXPAND, curve: Curve.EaseInOut }, () => {
      this.expandedMeals = next;
      this.setMealAlpha(meal, 0);
    });
  }

  /** 取某餐的展开透明度 */
  private mealAlphaOf(meal: MealType): number {
    const v: number | undefined = this.mealAlphaMap.get(meal);
    return v === undefined ? 0 : v;
  }

  /** 写某餐的展开透明度 */
  private setMealAlpha(meal: MealType, a: number): void {
    const next: Map<MealType, number> = new Map<MealType, number>();
    this.mealAlphaMap.forEach((v: number, k: MealType) => {
      next.set(k, v);
    });
    next.set(meal, a);
    this.mealAlphaMap = next;
  }

  /**
   * 处理桌面卡片带来的跳转意图。
   *
   * 卡片的「拍照记录」按钮带 cardRoute='camera' 拉起应用，
   * EntryAbility 写进 AppState，这里读走并跳到拍照页，读完清空
   *（否则每次刷新都会重新跳一次）。
   * 卡片左侧的环不带参数，落到首页即可，无需处理。
   */
  private consumeCardRoute(): void {
    const route: string = AppState.cardRoute;
    if (route.length === 0) {
      return;
    }
    AppState.cardRoute = '';
    if (route === 'camera') {
      /*
       * 点卡片按钮记的是**今天**，所以这里必须显式把目标日期设成今天。
       *
       * 不设的话会沿用 AppState.targetDay 里残留的值：用户可能刚在
       * 记录页翻到 10 月 3 日补记过（那个日期会留在 targetDay 里），
       * 之后从桌面卡片点「拍照记录」，记录会落到 10 月 3 日而不是今天。
       */
      AppState.targetDay = todayKey();
      // 餐次按当前时间猜，用户也可以在结果页改
      AppState.targetMeal = guessMealType(hourOf(Date.now()));
      // 卡片是「回首页看看」的入口，先把视图切回今天那一页
      this.switchTo(0);
      // 与首页那个悬浮按钮一致：跳走前先收起（回来时由 onPageShow 展开）
      this.cameraBarOn = false;
      try {
        router.pushUrl({ url: 'pages/Camera' });
      } catch (err) {
        const e: BusinessError = err as BusinessError;
        hilog.error(DOMAIN, 'CalorieLite', 'card route to camera failed: %{public}s', e.message);
      }
    }
  }

  private isExpanded(meal: MealType): boolean {
    return this.expandedMeals.includes(meal);
  }

  /**
   * 一餐的分组。
   *
   * 默认收起，只显示餐次名与合计热量；点标题才展开逐条明细。
   * 刚记完一餐时列表会一下子变很长，收起是更好的默认状态。
   *
   * 层级（原来每餐是一段裸列表，四个餐次糊成一片分不清边界）：
   *   每餐一张白色卡片（圆角 + 阴影）→ 卡片内标题行
   *   → 展开时用一条分隔线把标题与明细切开，明细区自身是浅底块。
   * 这样「早餐 / 午餐 / 晚餐 / 加餐」各自成形，滚动时边界一眼可辨。
   */
  @Builder
  mealSection(meal: MealType) {
    Column({ space: 0 }) {
      // 标题行：整行可点，右侧箭头随展开状态旋转
      Row({ space: 6 }) {
        Text(mealTypeLabel(meal))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_TEXT)

        Blank()

        Text(this.mealKcal(DailyService.recordsOf(this.data.records, meal)) > 0
          ? `${this.mealKcal(DailyService.recordsOf(this.data.records, meal))} 千卡`
          : '')
          .fontSize(13)
          .fontColor(COLOR_TEXT_SUB)

        Text('⌄')
          .fontSize(14)
          .fontColor(COLOR_TEXT_SUB)
          .rotate({ angle: this.isExpanded(meal) ? 180 : 0 })
          // 与明细区同时长，箭头与容器动作才是一体的
          .animation({ duration: DUR_MEAL_EXPAND, curve: Curve.EaseInOut })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 12, bottom: 12 })
      .onClick(() => {
        this.toggleMeal(meal);
      })

      /*
       * 展开时先来一条分隔线：把「标题」与「明细」在视觉上切开，
       * 这是层级感最关键的一笔 —— 没有它，展开后标题会和第一条记录粘在一起。
       */
      if (this.isExpanded(meal)) {
        Divider().color(COLOR_DIVIDER)
      }

      /*
       * 明细区：高度由**条数算出来**（展开动画 3.0），不做测量。
       *
       * count 传这一餐的记录条数，MealFold 直接用
       * 「内边距 + 条数×单条高度 + 间距」算出高度，
       * 所以第一次展开就是正确长度，不会先占位再撑开地闪一下。
       * 记录增删后 count 变化，高度自动跟着变 —— 不需要额外维护。
       */
      MealFold({
        expanded: this.isExpanded(meal),
        alpha: this.mealAlphaOf(meal),
        count: DailyService.recordsOf(this.data.records, meal).length,
        content: () => {
          this.mealDetail(meal);
        }
      })

      /*
       * 收起态摘要：有记录时列菜名，没记录时也要说话。
       *
       * 原来只在「有记录」时显示，于是没记录的餐次折叠后一片空白
       * —— 用户反馈「折叠的时候没有概括也没有多少千卡」。
       */
      if (!this.isExpanded(meal)) {
        Row() {
          Text(this.mealSummary(meal))
            .fontSize(12)
            .fontColor(COLOR_TEXT_SUB)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Text(this.mealKcalText(meal))
            .fontSize(12)
            .fontColor(COLOR_TEXT_SUB)
            .margin({ left: 8 })
        }
        .width('100%')
        .padding({ left: 14, right: 14, bottom: 12 })
      }
    }
    .width('100%')
    // 每餐一张卡片，四个餐次之间才有明确的边界
    .backgroundColor(COLOR_CARD)
    .borderRadius(RADIUS)
    .shadow(CARD_SHADOW)
    .clip(true)
  }

  /**
   * 一餐的明细内容（MealFold 的 @BuilderParam）。
   *
   * 在这里而不是内联进 MealFold：明细要渲染 RecordRow 并接删除回调，
   * 那些都依赖本组件的状态与方法；MealFold 只负责「按高度收放 + 淡入淡出」。
   */
  @Builder
  mealDetail(meal: MealType) {
    Column({ space: 8 }) {
      if (DailyService.recordsOf(this.data.records, meal).length === 0) {
        Row() {
          Text('还没有记录')
            .fontSize(13)
            .fontColor(COLOR_TEXT_SUB)
        }
        .width('100%')
        .padding(14)
      } else {
        ForEach(DailyService.recordsOf(this.data.records, meal), (record: FoodRecord) => {
          RecordRow({
            record: record,
            onDelete: (id: string) => {
              const target: FoodRecord | undefined =
                this.data.records.find((r: FoodRecord) => r.id === id);
              if (target !== undefined) {
                this.confirmDelete(target);
              }
            }
          })
        }, (record: FoodRecord) => record.id)
      }
    }
    .width('100%')
    // 浅底块：与白色卡片形成第二层，明细区一眼是「卡片里的内容」
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor(COLOR_BG)
    /*
     * 底部圆角跟着卡片：卡片圆角 18、外层 padding 0，
     * 明细块在最底下，不补圆角就会溢出卡片边角。
     */
    .borderRadius({ bottomLeft: RADIUS, bottomRight: RADIUS })
  }

  /**
   * 收起态的一行摘要，例如「白米饭、番茄炒蛋」。
   *
   * 没有记录时返回「还没有记录」而**不是空串**：
   * 空串会让整行只剩右侧的「0 千卡」，看起来像数据缺失。
   */
  private mealSummary(meal: MealType): string {
    const list: FoodRecord[] = DailyService.recordsOf(this.data.records, meal);
    if (list.length === 0) {
      return '还没有记录';
    }
    const names: string[] = [];
    for (const r of list) {
      names.push(r.name);
      if (names.length >= 4) {
        break;
      }
    }
    return names.length < list.length ? `${names.join('、')} 等 ${list.length} 项` : names.join('、');
  }

  /**
   * 收起态右侧的热量文案。
   *
   * 没有记录时显式写「0 千卡」，不要留空 ——
   * 用户明确反馈过折叠后「没有概括也没有显示多少千卡」。
   */
  private mealKcalText(meal: MealType): string {
    return `${this.mealKcal(DailyService.recordsOf(this.data.records, meal))} 千卡`;
  }

  @Builder
  exerciseSection() {
    Column({ space: 8 }) {
      Row() {
        Text('运动消耗')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_TEXT)
        Blank()
        if (this.data.summary.exerciseKcal > 0) {
          Text(`${this.data.summary.exerciseKcal} 千卡`)
            .fontSize(13)
            .fontColor(COLOR_TEXT_SUB)
        }
      }
      .width('100%')
      .padding({ left: 4, right: 4 })

      if (this.data.exercises.length === 0) {
        Row() {
          Text('没有运动记录')
            .fontSize(13)
            .fontColor(COLOR_TEXT_SUB)
        }
        .width('100%')
        .padding(14)
        .backgroundColor(COLOR_CARD)
        .borderRadius(RADIUS)
        .shadow(CARD_SHADOW)
      } else {
        ForEach(this.data.exercises, (item: ExerciseRecord) => {
          Row({ space: 10 }) {
            Column({ space: 3 }) {
              Text(item.name)
                .fontSize(15)
                .fontColor(COLOR_TEXT)
              Text(item.minutes > 0 ? `${item.minutes} 分钟` : '未记录时长')
                .fontSize(12)
                .fontColor(COLOR_TEXT_SUB)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Text(`${item.kcal} 千卡`)
              .fontSize(15)
              .fontColor(COLOR_TEXT)
          }
          .width('100%')
          .padding(14)
          .backgroundColor(COLOR_CARD)
          .borderRadius(RADIUS)
          .shadow(CARD_SHADOW)
        }, (item: ExerciseRecord) => item.id)
      }
    }
    .width('100%')
  }

  /** 悬浮主操作：拍照识别。浮在底部导航栏正上方 */
  @Builder
  cameraBar() {
    Row() {
      Button({ type: ButtonType.Capsule }) {
        Text('拍照识别热量')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
      }
      .width('100%')
      .height(CAMERA_BAR_HEIGHT)
      .backgroundColor(COLOR_PRIMARY)
      // 与导航栏同一套「浮起」语言：深色投影拉开层次
      .shadow({ radius: 20, color: 'rgba(16, 24, 36, 0.18)', offsetX: 0, offsetY: 8 })
      .onClick(() => {
        /*
         * 先收起、再跳转：让「收缩」这一拍在页面切走之前就开始，
         * 用户看到的是「按下去 → 按钮收起来 → 进拍照页」。
         * 反过来（先跳转）的话，收缩动画会被页面转场盖掉，等于没有。
         *
         * 回来时由 onPageShow 设回 true 重新展开，见那边说明。
         */
        this.cameraBarOn = false;
        try {
          router.pushUrl({ url: 'pages/Camera' });
        } catch (err) {
          const e: BusinessError = err as BusinessError;
          hilog.error(DOMAIN, 'CalorieLite', 'goCamera failed: %{public}s', e.message);
        }
      })
    }
    .width('100%')
    /*
     * 定位：底边刚好落在悬浮导航栏之上。
     *
     * 导航栏的占位 = bottomInset + 30(外边距) + NAV_HEIGHT，
     * 再留 NAV_MARGIN 作为两条之间的呼吸。
     * 这样按钮不压导航栏、导航栏也不压按钮，两者像一叠气泡。
     */
    .padding({ left: PAGE_PAD, right: PAGE_PAD, bottom: cameraFloatBottom(this.bottomInset) })
    /*
     * ══════════ 收起 / 展开动画 ══════════
     *
     * ── 为什么用 scaleX 而不是宽度
     * 改 `.width()` 会**重新排版**整棵子树（按钮内部文字要重新居中、
     * 底下的滚动内容要重算高度），每帧一次，廉价设备上会掉帧。
     * `.scale()` 不参与布局，只在合成阶段把已画好的图形横向压扁，
     * 代价几乎为零，而且效果正是「从两端向中间收缩」。
     *
     * ── 为什么不用 `.clip(true)` 包一层来切断
     * 收缩到接近 0 时图形本身已经细成一条线，视觉上等同于消失，
     * 不需要额外裁切；而多一层容器会多一次合成。
     *
     * ── 曲线的选择（Q 弹的来源）
     * 用 cubicBezier 的**回弹曲线** (0.34, 1.56, 0.64, 1)：
     * 第二控制点的 y = 1.56 > 1，也就是它会**冲过目标值再回落**。
     * 展开时冲到略大于 1（按钮「弹」一下），收起时冲到略小于 0
     *（压过头再回一点点），这就是 Q 弹的来源。
     * 时长的 380ms 比应用的通用时长(DUR_NORMAL=260)长一些 ——
     * 回弹需要时间让人看清「冲过头」和「弹回来」两拍，
     * 太快会退化成普通缓动、弹感消失。
     *
     * ⚠️ 回弹曲线会让 scaleX 短暂变成负值。负值在渲染上等同于
     *    镜像到 0，配合 scaleY=0 不会出现残影，但**别去掉 scaleY**：
     *    只缩 X 不缩 Y，按钮会变成一根竖线。
     */
    .scale({ x: this.cameraBarOn ? 1 : 0, y: this.cameraBarOn ? 1 : 0 })
    .opacity(this.cameraBarOn ? 1 : 0)
    .animation({ duration: 600, curve: curves.cubicBezierCurve(0.34, 1.56, 0.64, 1) })
    /*
     * 收起后必须彻底让出点击：scaleX=0 时它仍占着那条横带，
     * 不处理的话历史日期上会出现「点空白处却跳去拍照」。
     */
    .enabled(this.cameraBarOn)
    .hitTestBehavior(this.cameraBarOn ? HitTestMode.Default : HitTestMode.None)
  }
}
