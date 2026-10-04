/**
 * 悬浮液态玻璃导航栏。
 *
 * 玻璃质感由三层叠出来（见 glassBackdrop）：
 *   极低透明度白底 + 拉满的背景模糊 + 细白色高光边框
 * 文字与图标自带一层淡阴影，保证在浅色/深色内容上都读得清。
 *
 * 交互（对齐参考图的观感）：
 *   - 按住任意位置：以手指为圆心浮起柔光，手指移到哪光就跟到哪
 *   - 选中气泡实时跟到手指所在的项（弹簧曲线，不是硬切）
 *   - 手指抬起：选中抬起位置对应的项，并触发页面切换
 *
 * 注意：底部安全区（手势条）会吃掉点击，整条栏必须由父组件抬到 bottomInset 之上。
 */
import {
  COLOR_NAV_ACTIVE, COLOR_NAV_IDLE, DUR_FAST, NAV_HEIGHT, NAV_RADIUS
} from '../common/Theme';

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

  /**
   * 玻璃底色。
   *
   * 三层叠出「液态玻璃」：
   *   1. 极低透明度的白底（10%）——让底层内容透上来
   *   2. 拉满的背景模糊——把透上来的内容磨成砂面
   *   3. 细白色高光边框——玻璃边缘的折射感
   *
   * 关于模糊强度：backgroundBlurStyle 只能选 BlurStyle 档位，
   * 没有 blurRadius 参数（那是前景 blur() 的入参，见 BackgroundBlurStyleOptions
   * 的字段只有 colorMode / adaptiveColor / scale / blurOptions）。
   * 「拉满」对应的档位是 BACKGROUND_ULTRA_THICK
   * （枚举里没有 ULTRA_THICK，写它会编译不过）。
   */
  @Builder
  glassBackdrop() {
    Column()
      .width('100%')
      .height('100%')
      .backgroundBlurStyle(BlurStyle.BACKGROUND_ULTRA_THICK, {
        colorMode: ThemeColorMode.LIGHT,
        adaptiveColor: AdaptiveColor.DEFAULT,
        scale: 1.0
      })
      // 10% 白：再高就会在浅色背景上糊成一块实心白，玻璃感全无
      .backgroundColor('#1AFFFFFF')
      .hitTestBehavior(HitTestMode.None)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 玻璃底色：10% 白 + 拉满模糊
      this.glassBackdrop()

      /*
       * 三个入口均匀排布，没有任何选中背景块。
       *
       * 选中态完全靠颜色表达（图标与文字一起变绿），
       * 不再画那个大圆角胶囊——它会占掉大半个格子，
       * 视觉上像是「一个按钮被按住了」，而不是「当前在这一页」。
       *
       * 按下时的反馈也刻意做得很轻（整格轻微缩放 + 压暗），
       * 不再用跟随手指的径向柔光：那同样会被看成一块背景。
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
     * 液态玻璃。
     *
     * 用 backdropBlur 而不是 backgroundBlurStyle：后者会按档位一并调整
     * 亮度与饱和度，在浅色页面上把整条压成一块灰板（实测就是「灰色实心
     * 塑料板」的来源）。backdropBlur 只做模糊，亮度交给底色，
     * 这样 25% 白就是通透的玻璃，而不是发灰的塑料。
     */
    .backgroundColor('#40FFFFFF')
    .backdropBlur(40)
    // 玻璃高光边缘：这圈白边是「玻璃感」的灵魂，比底色更重要
    .border({ width: 1.5, color: '#E6FFFFFF' })
    // 内部白色光晕：让边缘有一层柔和的内发光，模拟光线在玻璃里的折射
    .shadow({ radius: 6, color: 'rgba(255,255,255,0.65)', offsetX: 0, offsetY: 0 })
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
      } else if (event.type === TouchType.Move) {
        this.pressX = x;
        this.hoverIndex = this.indexAt(x);
      } else if (event.type === TouchType.Up) {
        const target: number = this.indexAt(x);
        this.pressing = false;
        this.hoverIndex = -1;
        if (target >= 0 && target !== this.activeIndex) {
          this.onSelect(target);
        }
      } else if (event.type === TouchType.Cancel) {
        this.pressing = false;
        this.hoverIndex = -1;
      }
    })
  }
}
