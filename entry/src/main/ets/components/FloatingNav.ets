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
  COLOR_PRESS_GLOW, COLOR_PRIMARY, COLOR_PRIMARY_GLASS, COLOR_TEXT_SUB,
  CURVE_SPRING, DUR_FAST, DUR_NORMAL, NAV_HEIGHT, NAV_RADIUS, PRESS_SCALE
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
  /** 手指按下时相对导航栏左边的 x 坐标 */
  @State pressX: number = 0;
  /** 手指当前落在第几项；-1 表示没按 */
  @State hoverIndex: number = -1;

  private cellWidth(): number {
    const n: number = this.items.length > 0 ? this.items.length : 1;
    return this.barWidth > 0 ? this.barWidth / n : 0;
  }

  /** 高亮胶囊显示在哪一项：按住时跟着手指，否则跟着已选中项 */
  private pillIndex(): number {
    return this.pressing && this.hoverIndex >= 0 ? this.hoverIndex : this.activeIndex;
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
   * 三层要求叠在一起才是「液态玻璃」：
   *   1. 极低透明度的白底（15%）——让底层内容透上来
   *   2. 拉满的背景模糊——把透上来的内容磨成砂面
   *   3. 细白色高光边框——玻璃边缘的反光
   *
   * 关于模糊档位：BlurStyle 枚举里没有 ULTRA_THICK，
   * 「最厚一档」是 BACKGROUND_ULTRA_THICK（写 ULTRA_THICK 会编译不过）。
   *
   * 另外不用背景材质（systemMaterial）而用这里的模糊，是因为
   * 本机 uiMaterial.getMaterialInfo().state 恒为 0（应用级开关未生效），
   * 系统材质不渲染；backgroundBlurStyle 则一直可用。
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
      // 15% 白：再高就会在浅色背景上糊成一块实心白，玻璃感全无
      .backgroundColor('#26FFFFFF')
      .hitTestBehavior(HitTestMode.None)
  }

  /** 手指按压处的柔光 */
  @Builder
  pressGlow() {
    Column()
      .width(NAV_HEIGHT * 2.2)
      .height(NAV_HEIGHT * 2.2)
      .radialGradient({
        center: ['50%', '50%'],
        radius: NAV_HEIGHT * 1.1,
        colors: [[COLOR_PRESS_GLOW, 0.0], ['#0022C55E', 1.0]]
      })
      .position({ x: this.pressX - NAV_HEIGHT * 1.1, y: -(NAV_HEIGHT * 1.1 - NAV_HEIGHT / 2) })
      .hitTestBehavior(HitTestMode.None)
      .visibility(this.pressing ? Visibility.Visible : Visibility.Hidden)
      .opacity(this.pressing ? 1 : 0)
      .animation({ duration: DUR_FAST, curve: Curve.EaseOut })
  }

  build() {
    Stack({ alignContent: Alignment.Start }) {
      // 玻璃底色：15% 白 + 拉满模糊
      this.glassBackdrop()

      Stack({ alignContent: Alignment.Start }) {
        /*
         * 选中态小气泡。
         *
         * 本身也是毛玻璃：40% 白 + THIN 模糊 + 1.5px 白色高光边框。
         * 用「占满整宽的容器 + 等宽格子」定位，而不是「固定宽度 + 手算左偏移」，
         * 后者浮点取整会带来偏心；这里与文字共用同一套等分布局，几何上必然对齐。
         */
        Row() {
          ForEach(this.items, (item: NavItem, index: number) => {
            Column() {
              Row()
                .width('100%')
                .height(NAV_HEIGHT - 18)
                .backgroundBlurStyle(BlurStyle.Thin, {
                  colorMode: ThemeColorMode.LIGHT,
                  adaptiveColor: AdaptiveColor.DEFAULT,
                  scale: 1.0
                })
                /*
                 * 绿色胶囊，但保持玻璃质感：用半透明的品牌绿做着色层，
                 * 底下叠一层 40% 的白当柔光，两层一起压过 Thin 模糊。
                 * 直接写不透明绿会丢掉玻璃的通透感，写纯白又看不出是选中态。
                 */
                .backgroundColor(COLOR_PRIMARY_GLASS)
                .borderRadius((NAV_HEIGHT - 18) / 2)
                .border({ width: 1.5, color: '#CCFFFFFF' })
                .padding({ left: 6, right: 6 })
            }
            .layoutWeight(1)
            .height(NAV_HEIGHT)
            .justifyContent(FlexAlign.Center)
            .opacity(this.pillIndex() === index ? 1 : 0)
            .animation({ curve: CURVE_SPRING, duration: DUR_NORMAL })
          }, (item: NavItem, index: number) => `pill-${index}`)
        }
        .width('100%')
        .height(NAV_HEIGHT)
        .hitTestBehavior(HitTestMode.None)

        // 按压柔光垫在胶囊与文字之间
        this.pressGlow()

        Row() {
          ForEach(this.items, (item: NavItem, index: number) => {
            Column({ space: 3 }) {
              // 图标固定行高，避免不同字符的行高差异把这一格顶得不居中
              Text(item.glyph)
                .fontSize(20)
                .lineHeight(24)
                .textAlign(TextAlign.Center)
                .fontColor(this.pillIndex() === index ? COLOR_PRIMARY : COLOR_TEXT_SUB)
                .scale({
                  x: this.pillIndex() === index ? 1.12 : 1,
                  y: this.pillIndex() === index ? 1.12 : 1
                })
                .animation({ duration: DUR_FAST, curve: Curve.EaseOut })

              Text(item.label)
                .fontSize(11)
                .lineHeight(14)
                .textAlign(TextAlign.Center)
                .fontWeight(this.pillIndex() === index ? FontWeight.Medium : FontWeight.Normal)
                .fontColor(this.pillIndex() === index ? COLOR_PRIMARY : COLOR_TEXT_SUB)
                .animation({ duration: DUR_FAST })
            }
            .width(this.cellWidth())
            .height(NAV_HEIGHT)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            // 按住时未选中的项轻微压暗，突出当前指向的那一项
            .opacity(this.pressing && this.pillIndex() !== index ? 0.72 : 1)
            .animation({ duration: DUR_FAST })
          }, (item: NavItem, index: number) => `${index}-${item.label}`)
        }
        .width('100%')
        .height(NAV_HEIGHT)
      }
      .width('100%')
      .height(NAV_HEIGHT)
    }
    .width('100%')
    .height(NAV_HEIGHT)
    .clip(true)
    // 大圆角：正好是高度的一半，形成完整胶囊
    .borderRadius(NAV_RADIUS)
    // 玻璃高光边框：极细的半透明白，模拟玻璃边缘的反光
    .border({ width: 1, color: '#99FFFFFF' })
    // 整条栏统一接管手势：按下即出光效，移动即跟手，抬起即选中。
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
