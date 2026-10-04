/**
 * 单条饮食记录。
 */
import { FoodRecord, FoodSource, MealType } from '../model/Types';
import { foodSourceLabel } from '../model/Enums';
import { timeLabel } from '../common/DateUtil';
import { CARD_SHADOW, COLOR_CARB, COLOR_CARD, COLOR_DIVIDER, COLOR_FAT, COLOR_OK, COLOR_PROTEIN, COLOR_PRIMARY, COLOR_TEXT, COLOR_TEXT_SUB, RADIUS } from '../common/Theme';

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

  /** 是否记录了营养素。三项全为 0 视为没有数据 */
  private hasMacros(): boolean {
    return this.record.protein > 0 || this.record.fat > 0 || this.record.carb > 0;
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

        // 三大营养素。旧记录没存过这些值，全为 0 时整行不显示，
        // 避免出现「蛋白 0g 脂肪 0g 碳水 0g」这种误导性的空数据。
        if (this.hasMacros()) {
          Row({ space: 8 }) {
            this.macro('蛋白', this.record.protein, COLOR_PROTEIN)
            this.macro('脂肪', this.record.fat, COLOR_FAT)
            this.macro('碳水', this.record.carb, COLOR_CARB)
          }
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
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor(COLOR_CARD)
    .borderRadius(RADIUS)
    .shadow(CARD_SHADOW)
  }
}
