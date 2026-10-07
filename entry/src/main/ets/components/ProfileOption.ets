/**
 * 「个人情况」两列布局里的一个选项卡片。
 *
 * ── 为什么必须是 @Component，而不是页面里的 @Builder
 * 这个选项同时要「显示选中态」和「响应点击」，两者都依赖参数随状态更新：
 *
 *   @Builder 的参数**只在容器构建时求值一次**，之后再改状态不会重新求值。
 *   表现是：点了没反应（回调是旧的）、选中态也不跟着变。
 *   本项目在顶栏标题、热量环、日历格子上都踩过同一个坑。
 *
 * 做成 @Component 后：
 *   · @Prop 的更新会驱动重建，选中态能跟着变；
 *   · onClick 直接绑在组件内部的根容器上，不存在「包一层 Row 才绑得上」的问题；
 *   · 回调通过构造参数传入，每次重建都是新的闭包。
 *
 * 高度固定（OPTION_ROW_H）：两列并排时左右描述行数不同，
 * 不固定会高矮不一、看着错落。
 */
import { COLOR_BG, COLOR_PRIMARY, COLOR_PRIMARY_SOFT, COLOR_TEXT, COLOR_TEXT_SUB } from '../common/Theme';

/** 单个选项卡片的固定高度（vp）：标题 17 + 间距 2 + 说明两行 24 */
export const OPTION_ROW_H: number = 44;

@Component
export struct ProfileOption {
  /** 选项标题，例如「轻度活动」 */
  @Prop label: string = '';
  /** 一行说明，例如「每周运动 1-3 天」 */
  @Prop desc: string = '';
  /** 是否当前选中 */
  @Prop selected: boolean = false;
  /** 点击回调，由父组件决定改哪个字段 */
  onPick: () => void = () => {
  };

  build() {
    Column({ space: 2 }) {
      Row({ space: 4 }) {
        Text(this.label)
          .fontSize(14)
          .fontColor(this.selected ? COLOR_PRIMARY() : COLOR_TEXT())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        if (this.selected) {
          Text('✓')
            .fontSize(14)
            .fontColor(COLOR_PRIMARY())
        }
      }
      .width('100%')

      Text(this.desc)
        .fontSize(10)
        .fontColor(COLOR_TEXT_SUB())
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .width('100%')
    .height(OPTION_ROW_H)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 8, right: 8 })
    .backgroundColor(this.selected ? COLOR_PRIMARY_SOFT() : COLOR_BG())
    .borderRadius(10)
    // 事件绑在组件自己的根节点上，不依赖父级再包一层
    .onClick(() => {
      this.onPick();
    })
  }
}
