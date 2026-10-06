/**
 * 悬浮液态玻璃导航栏。
 *
 * 玻璃完全由**外层属性**表达：
 *   backgroundColor + backdropBlur + 0.5vp 描边 + 深色投影 + 白光晕
 * 内部只放「跟手光效」画布与三个入口。
 *
 * 交互：
 *   - 按住任意位置：以手指为圆心浮起柔光，手指移到哪光就跟到哪
 *   - 手指抬起：选中抬起位置对应的项，光效就地淡出
 *
 * 注意：底部安全区（手势条）会吃掉点击，整条栏必须由父组件抬到 bottomInset 之上。
 */
import {
  COLOR_GLASS_BORDER, COLOR_NAV_ACTIVE, COLOR_NAV_IDLE,
  DUR_FAST, GLASS_GLOW, GLASS_HAIRLINE, GLASS_INNER_GRADIENT, GLASS_LIFT_SHADOW,
  NAV_HEIGHT, NAV_RADIUS
} from '../common/Theme';

/**
 * 跟手光效的颜色与半径。
 *
 * 用极淡的绿而不是纯白：白色在浅色内容上几乎看不见，
 * 而品牌绿既能被识别为「这是可交互的」又不会盖住图标。
 */
const GLOW_RGBA: string = 'rgba(34, 197, 94, 0.75)';
/** 光斑半径（vp）。略大于一个格子的半宽，扫过一格时光感是连续的 */
const GLOW_RADIUS: number = 120;

/**
 * 玻璃边缘的对比度描边。
 *
 * 底色只有 22% 白，用纯白细边与它形成明显的明度台阶，
 * 整条栏的轮廓就从页面里「立」出来了 —— 这是提升边缘对比度最直接的做法。
 * 宽度比 GLASS_HAIRLINE 略粗（0.75），因为太细的高光在浅底上会被糊掉。
 */
const GLASS_EDGE_WIDTH: number = 0.75;
const COLOR_GLASS_EDGE: string = 'rgba(220, 240, 224, 0.95)';

/** 一个导航项 */
export class NavItem {
  label: string;
  /** 用字符做图标，避免依赖系统符号资源 */
  glyph: string;

  constructor(label: string, glyph: string) {
    this.label = label;
    this.glyph = glyph;
  }
}

@Component
export struct FloatingNav {
  @Prop items: NavItem[] = [];
  /** 当前选中项（已提交的） */
  @Prop activeIndex: number = 0;
  /** 导航栏总宽度（vp），由父组件用 onAreaChange 传入 */
  @Prop barWidth: number = 0;
  onSelect: (index: number) => void = () => {
  };

  /** 是否正被按住 */
  @State pressing: boolean = false;
  /** 手指按下时相对导航栏左边的 x 坐标，用于换算下标 */
  @State pressX: number = 0;
  /** 手指当前落在第几项；-1 表示没按 */
  @State hoverIndex: number = -1;
  /**
   * 跟手光效的位置，**按整条栏宽归一化**（0~1）。
   *
   * 用比例而不是像素：栏宽会变（92% 屏宽、旋转、折叠态），
   * 存像素的话布局一变光斑就偏了；比例天然跟着布局走。
   */
  @State glowFrac: number = 0.5;
  /** 光效强度 0~1：按下淡入、抬起淡出 */
  @State glowOn: number = 0;

  private glowSettings: RenderingContextSettings = new RenderingContextSettings(true);
  private glowCtx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.glowSettings);
  private glowTimer: number = -1;

  /**
   * 调试开关：把光斑钉在中间并常亮。
   *
   * 跟手光效依赖触摸，抬起即淡出，没法用截图验证（截图时手指已经松开了）。
   * 临时改成 true → 构建安装 → 截图确认光效真的画出来了 → 改回 false。
   * 生产代码里必须是 false。
   */
  private static readonly DEBUG_PIN_GLOW: boolean = false;
  /**
   * 实测宽度（vp），由 onAreaChange 更新。
   *
   * 只用于把触摸 x 换算成项下标，**不参与布局**：
   * 布局一律用 layoutWeight 等分，这样即使测量值缺失或延迟，
   * 图标也是均匀对称的。之前命中判定用父组件传进来的 barWidth，
   * 那个值在导航栏改成 92% 宽后不可靠，点到别的格子就会「选错项」。
   */
  @State measuredWidth: number = 0;

  private cellWidth(): number {
    const n: number = this.items.length > 0 ? this.items.length : 1;
    return this.measuredWidth > 0 ? this.measuredWidth / n : 0;
  }

  /**
   * 一项的颜色：选中是明亮的绿，未选中是中性灰。
   *
   * 图标与文字共用同一个颜色，所以选中态完全由颜色表达，
   * 不需要任何背景块。
   */
  private itemColor(index: number): string {
    return index === this.activeIndex ? COLOR_NAV_ACTIVE : COLOR_NAV_IDLE;
  }

  /**
   * 把 x 坐标换算成项下标。
   *
   * 取不到实测宽度时按「等分整条栏」估算：既然布局是等分的，
   * 命中判定按同一规则均分就不会错位。
   */
  private indexAt(x: number): number {
    const n: number = this.items.length;
    if (n <= 0) {
      return -1;
    }
    const w: number = this.cellWidth();
    if (w > 0) {
      return Math.max(0, Math.min(n - 1, Math.floor(x / w)));
    }
    return -1;
  }

  // ================================================================ 跟手光效

  /**
   * 把手指的 x 换算成归一化位置（0~1）。
   *
   * 拿不到实测宽度就退回 0.5：宁可光斑停在中间，
   * 也不要因为除以 0 得到 NaN 把整块画布搞黑。
   */
  private pressFrac(x: number): number {
    if (this.measuredWidth <= 0) {
      return 0.5;
    }
    const f: number = x / this.measuredWidth;
    return Math.max(0, Math.min(1, f));
  }

  /**
   * 画跟手光斑。
   *
   * Canvas 内容不是声明式的，每次位置/强度变化都要显式重画。
   * 渐变用 createRadialGradient：中心亮、向外淡出，
   * 比纯色圆更像「光」而不是「贴纸」。
   */
  private drawGlow(): void {
    const ctx = this.glowCtx;
    const w: number = ctx.width;
    const h: number = ctx.height;
    ctx.clearRect(0, 0, w, h);

    // 调试：钉住光斑，方便截图确认光效确实画出来了
    const frac: number = FloatingNav.DEBUG_PIN_GLOW ? 0.5 : this.glowFrac;
    const alpha: number = FloatingNav.DEBUG_PIN_GLOW ? 1 : this.glowOn;
    if (w <= 0 || h <= 0 || alpha <= 0.01) {
      // 强度归零就什么都不画，避免残留一个极淡的圆
      return;
    }

    const cx: number = frac * w;
    const cy: number = h / 2;
    const r: number = GLOW_RADIUS;
    const grad: CanvasGradient = ctx.createRadialGradient(cx, cy, 0, cx, cy, r);
    grad.addColorStop(0, GLOW_RGBA);
    // 中段再补一档，让衰减更接近真实的光晕（单段线性会显得生硬）
    grad.addColorStop(0.55, 'rgba(34, 197, 94, 0.10)');
    grad.addColorStop(1, 'rgba(34, 197, 94, 0)');

    ctx.globalAlpha = alpha;
    ctx.beginPath();
    ctx.fillStyle = grad;
    ctx.arc(cx, cy, r, 0, Math.PI * 2);
    ctx.fill();
    ctx.globalAlpha = 1;
  }

  /**
   * 把光效强度平滑推向目标值。
   *
   * 不用 animateTo：它插值的是**属性**，而这里要逐帧重绘 Canvas，
   * 必须自己按帧推进（与热量环动画同一套路）。
   */
  private animateGlow(to: number): void {
    if (this.glowTimer !== -1) {
      clearInterval(this.glowTimer);
      this.glowTimer = -1;
    }
    this.glowTimer = setInterval(() => {
      const diff: number = to - this.glowOn;
      if (Math.abs(diff) <= 0.02) {
        this.glowOn = to;
        this.drawGlow();
        clearInterval(this.glowTimer);
        this.glowTimer = -1;
        return;
      }
      this.glowOn = this.glowOn + diff * 0.28;
      this.drawGlow();
    }, 16);
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      /*
       * ── 这里曾经有一个 glassBackdrop() 层，已删除 ──
       *
       * 原先 build() 的第一层是一个自绘的 backdrop builder，
       * 用 backgroundBlurStyle(BACKGROUND_ULTRA_THICK) + 10% 白。
       * 它一直叠在外层样式**上面**，是导航栏「发灰像塑料板」的直接原因：
       * backgroundBlurStyle 会按档位一并调整亮度/饱和度，在浅色页面上
       * 把整条压暗一档。外层的 backdropBlur 被它盖住，改了也看不出效果。
       *
       * 现在玻璃完全由外层属性表达（backgroundColor + backdropBlur +
       * 描边 + 双投影），这里只叠「跟手光效」，层次才干净。
       */
      Canvas(this.glowCtx)
        .width('100%')
        .height('100%')
        .onReady(() => {
          // onReady 时才能拿到真实绘制尺寸
          this.drawGlow();
        })
        // 光效只是装饰：绝不能吃掉触摸，否则整条栏点不动
        .hitTestBehavior(HitTestMode.None)

      /*
       * 玻璃内层的纵向高光。
       *
       * 单纯一个半透明底看起来像「半透明色板」；加上这层渐变后，
       * 上缘比下缘亮一点 —— 眼睛立刻把它读成「一块有厚度的玻璃」。
       * 这是模拟折射最省事也最有效的一层。
       */
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({ angle: 90, colors: GLASS_INNER_GRADIENT })
        .hitTestBehavior(HitTestMode.None)

      /*
       * 三个入口均匀排布，没有任何选中背景块。
       *
       * 选中态完全靠颜色表达（图标与文字一起变绿）。
       * 按下时的反馈很轻：整格轻微缩放 + 跟手光斑（见 drawGlow），
       * 不画任何固定的背景块——固定块会被看成「一个按钮被按住了」，
       * 而不是「当前在这一页」。
       */
      Row() {
        ForEach(this.items, (item: NavItem, index: number) => {
          Column({ space: 4 }) {
            // 图标固定行高，避免不同字符的行高差异把这一格顶得不居中
            Text(item.glyph)
              .fontSize(21)
              .lineHeight(25)
              .textAlign(TextAlign.Center)
              .fontColor(this.itemColor(index))

            Text(item.label)
              .fontSize(11)
              .lineHeight(14)
              .textAlign(TextAlign.Center)
              .fontWeight(index === this.activeIndex ? FontWeight.Medium : FontWeight.Normal)
              .fontColor(this.itemColor(index))
          }
          // 等宽格子：三项严格均分整条栏，视觉上必然对称。
          // 若改成自然宽度 + SpaceEvenly，格子宽度会随文字长短变化，
          // 看起来就是「歪的」（实测反馈过）。
          .layoutWeight(1)
          .height(NAV_HEIGHT)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          // 按下时只有当前指到的那一格轻微回弹，其余保持不动
          .scale({
            x: this.pressing && this.hoverIndex === index ? 0.92 : 1,
            y: this.pressing && this.hoverIndex === index ? 0.92 : 1
          })
          .animation({ duration: DUR_FAST, curve: Curve.EaseOut })
        }, (item: NavItem, index: number) => `${index}-${item.label}`)
      }
      .width('100%')
      .height(NAV_HEIGHT)
      // 三项用 layoutWeight 等分，不需要 SpaceEvenly 再分间隙
      .justifyContent(FlexAlign.Start)
      // 实测整条栏宽度，供把触摸坐标换算成项下标
      .onAreaChange((oldValue: Area, newValue: Area) => {
        const w: number = Number.parseFloat(`${newValue.width}`);
        if (!Number.isNaN(w) && w > 0) {
          this.measuredWidth = w;
        }
      })
    }
    .width('100%')
    .height(NAV_HEIGHT)
    .clip(true)
    // 大圆角：正好是高度的一半，形成完整胶囊
    .borderRadius(NAV_RADIUS)
    /*
     * 液态玻璃（折射感加强版）。
     *
     * 用 backdropBlur 而不是 backgroundBlurStyle：后者会按 BlurStyle 档位
     * 一并施加亮度/饱和度调整，在浅色页面上会把整条压成灰板
     *（实测顶栏和底部导航都因此发灰）。backdropBlur 只做背景模糊，
     * 亮度完全由底色决定。
     *
     * 底色 35% → 22%：用户反馈 1.2 的 20% 太透、1.3 的 35% 太实，
     * 取中间偏透。折射那三层（亮描边 / 内部渐变 / 顶部高光）保留，
     * 所以即便底色很淡，仍然读得出「玻璃」而不是「一层膜」。
     *
     * 模糊 44：这个值不能用「透明度」去反推，要单独看。
     * 实测 36 时正文笔画会透上来（导航栏顶边与按钮之间那条缝里
     * 能看到「加餐」的字），观感是**脏**而不是透。
     * 真正的「浮起来」靠的是投影与描边，不是靠透出后面的文字，
     * 所以模糊要足够重到把内容化成色块。
     */
    .backgroundColor('#4DB2DFDB')
    .backdropBlur(8)
    /*
     * 玻璃的「折射四件套」：
     *   1. 0.5vp 亮白描边   —— 玻璃厚度；边缘的折射最直观
     *   2. 内部纵向渐变     —— 上缘亮、下缘暗，光线斜射进玻璃的衰减
     *   3. 顶部方向性内光   —— offsetY 为负的白光晕，顶部弧形高光
     *   4. 深色大半径投影   —— 与下方内容拉开层次（浮起来）
     * 缺 2 / 3 会像一块半透明色板而不是玻璃；缺 4 会贴在内容上没有高度。
     */
    /*
     * 玻璃边缘的**对比度描边**。
     *
     * 一个节点只能有一个 border，所以做不到「白高光 + 深色轮廓」两圈叠：
     * 提升对比度的办法是让这一圈更亮、更利落 —— 纯白 + 0.75vp。
     * 底色只有 22% 白，纯白边与它形成明显的明度台阶，
     * 整条栏的轮廓就从页面里「立」出来了，同时还保留折射感。
     *
     * 与 GLASS_LIFT_SHADOW 分工：投影负责向外柔和分离，
     * 这圈边负责贴着边缘的硬轮廓，两者不重复。
     */
    .border({ width: GLASS_EDGE_WIDTH, color: COLOR_GLASS_EDGE })
    .shadow(GLASS_LIFT_SHADOW)
    .shadow(GLASS_GLOW)
    // 整条栏统一接管手势：按下即反馈，移动即跟随，抬起即选中。
    // 用整栏一个手势而不是每项各一个，手指在项之间滑动才不会被切断。
    .onTouch((event: TouchEvent) => {
      const touches: TouchObject[] = event.touches;
      if (touches.length === 0) {
        return;
      }
      const x: number = touches[0].x;
      if (event.type === TouchType.Down) {
        this.pressing = true;
        this.pressX = x;
        this.hoverIndex = this.indexAt(x);
        // 光斑先落到按下的位置再淡入，避免从上一处「飞」过来
        this.glowFrac = this.pressFrac(x);
        this.animateGlow(1);
      } else if (event.type === TouchType.Move) {
        this.pressX = x;
        this.hoverIndex = this.indexAt(x);
        // 位置直接跟手（不加缓动，否则会有拖拽的黏滞感）
        this.glowFrac = this.pressFrac(x);
        // 移动时立即重绘：改 @State 会触发重建，但 Canvas 需要显式重画
        this.drawGlow();
      } else if (event.type === TouchType.Up) {
        const target: number = this.indexAt(x);
        this.pressing = false;
        this.hoverIndex = -1;
        // 抬起后光效就地淡出，不移动位置——移开反而像「光跑了」
        this.animateGlow(0);
        if (target >= 0 && target !== this.activeIndex) {
          this.onSelect(target);
        }
      } else if (event.type === TouchType.Cancel) {
        this.pressing = false;
        this.hoverIndex = -1;
        this.animateGlow(0);
      }
    })
  }

  aboutToDisappear(): void {
    // 定时器必须在销毁时停掉，否则回调会打到已销毁的实例上
    if (this.glowTimer !== -1) {
      clearInterval(this.glowTimer);
      this.glowTimer = -1;
    }
  }
}
