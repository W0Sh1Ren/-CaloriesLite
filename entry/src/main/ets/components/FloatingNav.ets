/**
 * 悬浮导航栏。
 *
 * 做成独立组件而不是用 Tabs 自带的 tabBar，原因：
 *   1. Tabs 的 tabBar 贴着屏幕底边并占布局空间，做不出「悬浮在内容之上」的观感；
 *   2. 悬浮栏需要毛玻璃材质透出下方滚动的内容，tabBar 做不到；
 *   3. 高亮胶囊的弹性滑动、图标的按压反馈都要自己控制。
 *
 * 液态玻璃质感的做法（三层叠加）：
 *   底：backgroundEffect 强模糊 + 提饱和 + 提亮，让下方内容透出来并带一点「厚度」
 *   中：很淡的白色半透明，保证文字在任何背景上都可读
 *   上：一条自上而下由亮到透明的线性渐变，模拟玻璃边缘的高光
 * 外面再套一圈半透明白边，玻璃的「边缘」就出来了。
 *
 * 注意：底部安全区（手势条）会吃掉点击，所以整条导航栏必须由父组件
 * 抬到 bottomInset 之上，否则表现为「点了没反应」。
 */
import { CARD_SHADOW, COLOR_PRIMARY, COLOR_PRIMARY_SOFT, COLOR_TEXT_SUB, CURVE_SPRING, DUR_FAST, NAV_HEIGHT } from '../common/Theme';

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
  @Prop activeIndex: number = 0;
  /** 导航栏总宽度（vp），由父组件用 onAreaChange 传入，用于算指示器位置 */
  @Prop barWidth: number = 0;
  onSelect: (index: number) => void = () => {
  };

  /** 按下的项，用于做按压反馈；-1 表示没有 */
  @State pressedIndex: number = -1;

  private cellWidth(): number {
    const n: number = this.items.length > 0 ? this.items.length : 1;
    return this.barWidth > 0 ? this.barWidth / n : 0;
  }

  build() {
    Stack({ alignContent: Alignment.Start }) {
      // ------------------------------------------------ 液态玻璃三层
      // 中：淡白底，保证可读性
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#8CFFFFFF')
        .hitTestBehavior(HitTestMode.None)

      // 上：自上而下的高光渐变，玻璃的「光泽」
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [['#66FFFFFF', 0.0], ['#1AFFFFFF', 0.45], ['#00FFFFFF', 1.0]]
        })
        .hitTestBehavior(HitTestMode.None)

      // ------------------------------------------------ 内容
      Stack({ alignContent: Alignment.Start }) {
        // 高亮胶囊，垫在文字下层且自己不吃点击
        Row()
          .width(this.cellWidth() > 0 ? this.cellWidth() - 16 : 0)
          .height(NAV_HEIGHT - 14)
          .backgroundColor(COLOR_PRIMARY_SOFT)
          .borderRadius((NAV_HEIGHT - 14) / 2)
          .margin({ left: this.cellWidth() * this.activeIndex + 8, top: 7 })
          // 弹性曲线：切换标签时胶囊是「滑过去」而不是「跳过去」
          .animation({ curve: CURVE_SPRING })
          .hitTestBehavior(HitTestMode.None)

        Row() {
          ForEach(this.items, (item: NavItem, index: number) => {
            Column({ space: 2 }) {
              Text(item.glyph)
                .fontSize(19)
                .fontColor(this.activeIndex === index ? COLOR_PRIMARY : COLOR_TEXT_SUB)
                .scale({
                  x: this.activeIndex === index ? 1.15 : 1,
                  y: this.activeIndex === index ? 1.15 : 1
                })
                .animation({ duration: DUR_FAST, curve: Curve.EaseOut })

              Text(item.label)
                .fontSize(11)
                .fontWeight(this.activeIndex === index ? FontWeight.Medium : FontWeight.Normal)
                .fontColor(this.activeIndex === index ? COLOR_PRIMARY : COLOR_TEXT_SUB)
                .animation({ duration: DUR_FAST })
            }
            .width(this.cellWidth())
            .height(NAV_HEIGHT)
            .justifyContent(FlexAlign.Center)
            // 跟手：按下立刻缩小并压暗，抬起恢复，反馈时长压到 90ms 才不显得拖沓
            .scale({
              x: this.pressedIndex === index ? 0.9 : 1,
              y: this.pressedIndex === index ? 0.9 : 1
            })
            .opacity(this.pressedIndex === index ? 0.6 : 1)
            .animation({ duration: 90, curve: Curve.EaseOut })
            .onTouch((event: TouchEvent) => {
              if (event.type === TouchType.Down) {
                this.pressedIndex = index;
              } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                this.pressedIndex = -1;
              }
            })
            .onClick(() => {
              this.pressedIndex = -1;
              this.onSelect(index);
            })
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
    // 底：强模糊 + 提饱和提亮。radius 越大越糊，saturation 给玻璃一点通透感
    .backgroundEffect({
      radius: 36,
      saturation: 1.8,
      brightness: 1.08,
      color: '#33FFFFFF'
    })
    .backgroundColor(Color.Transparent)
    .clip(true)
    .borderRadius(NAV_HEIGHT / 2)
    // 半透明白边＝玻璃的边缘
    .border({ width: 1, color: '#59FFFFFF' })
    .shadow(CARD_SHADOW)
  }
}
