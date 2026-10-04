/**
 * 悬浮液态玻璃导航栏。
 *
 * 交互（对齐参考图的观感）：
 *   - 按住任意位置：以手指为圆心浮起一团柔光，手指移到哪光就跟到哪
 *   - 高亮胶囊实时跟到手指所在的项（弹簧曲线，不是硬切）
 *   - 手指抬起：选中抬起位置对应的项，并触发页面切换
 *   - 整条栏是毛玻璃胶囊，浮在内容之上
 *
 * 玻璃质感三层叠加：
 *   底 backgroundEffect 强模糊 + 提饱和提亮，让下方内容透出来并带一点厚度
 *   中 淡白底，保证文字在任何背景上都读得清
 *   上 自上而下由亮到透明的渐变，模拟玻璃边缘的高光
 * 再套一圈半透明白边，玻璃的「边」就出来了。
 *
 * 注意：底部安全区（手势条）会吃掉点击，整条栏必须由父组件抬到 bottomInset 之上。
 */
import {
  CARD_SHADOW, COLOR_PRESS_GLOW, COLOR_PRIMARY, COLOR_PRIMARY_SOFT, COLOR_TEXT_SUB,
  CURVE_SPRING, DUR_FAST, NAV_HEIGHT, PRESS_SCALE
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

  /** 玻璃的两层底色，包在一个不参与命中测试的 Stack 里 */
  @Builder
  glassLayers() {
    Stack() {
      // 中：淡白底，保证文字在任何背景上都读得清
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#8CFFFFFF')

      // 上：自上而下的高光渐变，玻璃的「光泽」
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [['#66FFFFFF', 0.0], ['#1AFFFFFF', 0.45], ['#00FFFFFF', 1.0]]
        })
    }
    .width('100%')
    .height('100%')
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
        colors: [[COLOR_PRESS_GLOW, 0.0], ['#00FF7A45', 1.0]]
      })
      .position({ x: this.pressX - NAV_HEIGHT * 1.1, y: -(NAV_HEIGHT * 1.1 - NAV_HEIGHT / 2) })
      .hitTestBehavior(HitTestMode.None)
      .visibility(this.pressing ? Visibility.Visible : Visibility.Hidden)
      .opacity(this.pressing ? 1 : 0)
      .animation({ duration: DUR_FAST, curve: Curve.EaseOut })
  }

  build() {
    Stack({ alignContent: Alignment.Start }) {
      this.glassLayers()

      Stack({ alignContent: Alignment.Start }) {
        // 高亮胶囊：弹簧曲线跟随，滑动而不是跳变
        Row()
          .width(this.cellWidth() > 0 ? this.cellWidth() - 16 : 0)
          .height(NAV_HEIGHT - 14)
          .backgroundColor(COLOR_PRIMARY_SOFT)
          .borderRadius((NAV_HEIGHT - 14) / 2)
          .margin({ left: this.cellWidth() * this.pillIndex() + 8, top: 7 })
          .animation({ curve: CURVE_SPRING })
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
    .backgroundEffect({
      radius: 36,
      saturation: 1.8,
      brightness: 1.08,
      color: '#33FFFFFF'
    })
    .clip(true)
    .borderRadius(NAV_HEIGHT / 2)
    .border({ width: 1, color: '#59FFFFFF' })
    .shadow(CARD_SHADOW)
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
