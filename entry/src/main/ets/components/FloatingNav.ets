/**
 * 悬浮导航栏。
 *
 * 做成独立组件而不是用 Tabs 自带的 tabBar，原因有三：
 *   1. Tabs 的 tabBar 贴着屏幕底边，做不出「悬浮」的观感；
 *   2. 悬浮栏需要毛玻璃材质（backgroundBlurStyle）透出下方滚动的内容，tabBar 做不到；
 *   3. 指示滑块的弹性动画要自己控制，才能和页面切换动画对齐。
 *
 * 视觉：一条圆角胶囊，毛玻璃底 + 柔和投影；选中项主色高亮，
 * 底下有一个会滑动的高亮胶囊。
 */
import { CARD_SHADOW, COLOR_PRIMARY, COLOR_PRIMARY_SOFT, COLOR_TEXT_SUB, CURVE_SPRING, DUR_FAST, DUR_NORMAL, NAV_HEIGHT } from '../common/Theme';

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

  /** 单个格子的宽度 */
  private cellWidth(): number {
    const n: number = this.items.length > 0 ? this.items.length : 1;
    return this.barWidth > 0 ? this.barWidth / n : 0;
  }

  build() {
    // Stack 让高亮胶囊垫在文字下层，同时自己不吃点击事件
    Stack({ alignContent: Alignment.Start }) {
      // 高亮胶囊
      Row()
        .width(this.cellWidth() > 0 ? this.cellWidth() - 16 : 0)
        .height(NAV_HEIGHT - 14)
        .backgroundColor(COLOR_PRIMARY_SOFT)
        .borderRadius((NAV_HEIGHT - 14) / 2)
        .margin({ left: this.cellWidth() * this.activeIndex + 8, top: 7 })
        // 弹性曲线：切换标签时胶囊是「滑过去」而不是「跳过去」
        .animation({ curve: CURVE_SPRING })
        .hitTestBehavior(HitTestMode.Transparent)

      // 三个导航项
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
              .animation({ duration: DUR_NORMAL, curve: Curve.EaseOut })

            Text(item.label)
              .fontSize(11)
              .fontWeight(this.activeIndex === index ? FontWeight.Medium : FontWeight.Normal)
              .fontColor(this.activeIndex === index ? COLOR_PRIMARY : COLOR_TEXT_SUB)
              .animation({ duration: DUR_FAST })
          }
          .width(this.cellWidth())
          .height(NAV_HEIGHT)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            this.onSelect(index);
          })
        }, (item: NavItem, index: number) => `${index}-${item.label}`)
      }
      .width('100%')
      .height(NAV_HEIGHT)
    }
    .width('100%')
    .height(NAV_HEIGHT)
    // 毛玻璃底：透出下方滚动的内容，这是「悬浮」观感的关键
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK, {
      colorMode: ThemeColorMode.LIGHT,
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: 1.0
    })
    .backgroundColor('#D9FFFFFF')
    .borderRadius(NAV_HEIGHT / 2)
    .border({ width: 1, color: '#33FFFFFF' })
    .shadow(CARD_SHADOW)
  }
}
