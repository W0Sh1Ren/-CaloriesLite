/**
 * 单条饮食记录。
 */
import { FoodRecord, FoodSource, MealType } from '../model/Types';
import { foodSourceLabel } from '../model/Enums';
import { timeLabel } from '../common/DateUtil';
import { CARD_SHADOW, COLOR_CARB, COLOR_CARD, COLOR_DIVIDER, COLOR_FAT, COLOR_OK, COLOR_PROTEIN, COLOR_PRIMARY, COLOR_TEXT, COLOR_TEXT_SUB, RADIUS } from '../common/Theme';

/**
 * 一条记录卡片的**固定高度**（vp）。
 *
 * ── 为什么必须固定
 * 卡片内部是「菜名 / 份量·来源·时间 / 三大营养素」三行，其中营养素那行是
 * **条件渲染**的（全为 0 时不显示）。所以自然高度有两种：
 *   · 有营养素数据 → 约 72vp
 *   · 没有营养素数据（旧记录，或 AI 三项都返回 0）→ 矮约 14vp
 *
 * 而餐次明细区的展开高度是**算出来**的（见 MealFold.mealDetailHeight）：
 *   上下内边距 + 条数 × RECORD_ROW_H + (条数-1) × 间距
 * 一旦同一餐里混着两种高度的卡片，这个乘法就不成立了 ——
 * 算出来的高度会与实际不符，表现是底部多出空白、或最后一条被裁掉一截。
 *
 * 所以这里把高度**钉死**，让「每张卡片等高」成为代码保证的事实，
 * 而不是一个需要靠运气吻合的观测值。
 *
 * ⚠️ 这个常量必须与 MealFold.ets 的 RECORD_ROW_H 保持一致。
 *    改这里的值，那边要同步改（两边都指向同一个物理高度）。
 */
export const RECORD_ROW_FIXED_H: number = 72;

@Component
export struct RecordRow {
  @Prop record: FoodRecord =
    new FoodRecord('', '', 0, MealType.SNACK, '', 0, 0, 0, 0, 0, FoodSource.MANUAL, '', '');
  /** 删除回调，由父组件处理数据与刷新 */
  onDelete: (id: string) => void = () => {
  };

  /** 来源标签的颜色：查表命中用绿色，AI 估算用主色，提醒用户可信度不同 */
  private sourceColor(): string {
    return this.record.source === FoodSource.DATABASE ? COLOR_OK : COLOR_PRIMARY;
  }

  @Builder
  macro(label: string, grams: number, color: string) {
    Row({ space: 3 }) {
      // 一个小色点代替图标，标明是哪一项
      Row()
        .width(5)
        .height(5)
        .backgroundColor(color)
        .borderRadius(3)
      Text(`${label} ${grams}g`)
        .fontSize(11)
        .fontColor(COLOR_TEXT_SUB)
    }
  }

  build() {
    Row({ space: 12 }) {
      // 左侧：来源标识条
      Row()
        .width(3)
        .height(34)
        .backgroundColor(this.sourceColor())
        .borderRadius(2)

      Column({ space: 3 }) {
        Text(this.record.name)
          .fontSize(16)
          .fontColor(COLOR_TEXT)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Row({ space: 6 }) {
          Text(`${this.record.grams} g`)
            .fontSize(12)
            .fontColor(COLOR_TEXT_SUB)

          Text('·')
            .fontSize(12)
            .fontColor(COLOR_DIVIDER)

          Text(foodSourceLabel(this.record.source))
            .fontSize(12)
            .fontColor(this.sourceColor())

          Text('·')
            .fontSize(12)
            .fontColor(COLOR_DIVIDER)

          Text(timeLabel(this.record.timestamp))
            .fontSize(12)
            .fontColor(COLOR_TEXT_SUB)
        }

        /*
         * 三大营养素：**常显**，不再条件渲染。
         *
         * 原来写成 `if (hasMacros())`，全为 0 时整行不显示，理由是
         * 「避免出现『蛋白 0g 脂肪 0g 碳水 0g』这种误导性的空数据」。
         * 但那样带来两个更大的问题：
         *   1. **同一餐里卡片高矮不一**（有营养素的高约 14vp），
         *      而明细区展开高度是算出来的（条数 × 单条高度），
         *      高度一旦不齐，算式就不成立 —— 底部会多空白或裁掉最后一条；
         *   2. 缺数据时**整行消失**，用户看到的是「这里本来就没这项」，
         *      而不是「这项没记到」，信息反而更糊。
         *
         * 现在常显：0g 就是 0g，它是**真实数据**而不是缺失标记；
         * 且每张卡片天然等高，算式与实际自然吻合。
         * RecordRow 另外还钉了固定高度兜底（见 RECORD_ROW_FIXED_H）。
         */
        Row({ space: 8 }) {
          this.macro('蛋白', this.record.protein, COLOR_PROTEIN)
          this.macro('脂肪', this.record.fat, COLOR_FAT)
          this.macro('碳水', this.record.carb, COLOR_CARB)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text(`${this.record.kcal}`)
        .fontSize(19)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_TEXT)

      Text('千卡')
        .fontSize(11)
        .fontColor(COLOR_TEXT_SUB)

      // 删除按钮：点击后再弹确认，避免误删
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        Text('✕')
          .fontSize(13)
          .fontColor(COLOR_TEXT_SUB)
      }
      .width(28)
      .height(28)
      .backgroundColor(COLOR_DIVIDER)
      .onClick(() => {
        this.onDelete(this.record.id);
      })
    }
    .width('100%')
    /*
     * 固定高度 + 内容垂直居中。
     *
     * 固定：保证同一餐里每张卡片等高，让 MealFold 算出的展开高度始终准确
     *（原因见文件顶部 RECORD_ROW_FIXED_H 的说明）。
     * 现在三行内容是常显的（营养素那行不再条件渲染），所以内容高度本来
     * 就一致；这里是**双保险** —— 万一以后又加了条件渲染的行、
     * 或者换了字体导致行高变化，卡片高度仍然固定，算式不会被破坏。
     *
     * 居中：内容比固定高度矮时，文字不会贴着上边显得被"顶"在卡片上方。
     */
    .height(RECORD_ROW_FIXED_H)
    .alignItems(VerticalAlign.Center)
    .padding({ left: 12, right: 12 })
    .backgroundColor(COLOR_CARD)
    .borderRadius(RADIUS)
    .shadow(CARD_SHADOW)
  }
}
