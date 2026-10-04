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

  private cellWidth(): number {
    const n: number = this.items.length > 0 ? this.items.length : 1;
    return this.barWidth > 0 ? this.barWidth / n : 0;
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

  /** 把 x 坐标换算成项下标 */
  private indexAt(x: number): number {
    const w: number = this.cellWidth();
    if (w <= 0) {
      return -1;
    }
    const i: number = Math.floor(x / w);
    return Math.max(0, Math.min(this.items.length - 1, i));
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
      // 三个入口等距分布，不依赖任何格子宽度计算
      .justifyContent(FlexAlign.SpaceEvenly)
    }
    .width('100%')
    .height(NAV_HEIGHT)
    .clip(true)
    // 大圆角：正好是高度的一半，形成完整胶囊
    .borderRadius(NAV_RADIUS)
    // 底色要非常通透，观感主要靠下面的模糊和描边撑起来。
    // 25% 白：再高就变成一块灰色实心板，液态玻璃的通透感全无。
    .backgroundColor('#40FFFFFF')
    // 最厚一档背景模糊，把透上来的内容磨成砂面。
    // 注意：backgroundBlurStyle 没有 blurRadius 参数
    //（那是前景 blur() 的入参），模糊强度只能选 BlurStyle 档位。
    .backgroundBlurStyle(BlurStyle.BACKGROUND_ULTRA_THICK, {
      colorMode: ThemeColorMode.LIGHT,
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: 1.0
    })
    // 玻璃高光边缘：这圈白边是「玻璃感」的灵魂，比底色更重要
    .border({ width: 1.5, color: '#CCFFFFFF' })
    // 内部白色光晕：让边缘有一层柔和的内发光，模拟光线在玻璃里的折射
    .shadow({ radius: 4, color: 'rgba(255,255,255,0.5)', offsetX: 0, offsetY: 0 })
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
