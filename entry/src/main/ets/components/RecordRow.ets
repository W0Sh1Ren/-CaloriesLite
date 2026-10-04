/**
 * 单条饮食记录。
 */
import { FoodRecord, FoodSource, MealType } from '../model/Types';
import { foodSourceLabel } from '../model/Enums';
import { timeLabel } from '../common/DateUtil';
import { COLOR_CARD, COLOR_DIVIDER, COLOR_OK, COLOR_PRIMARY, COLOR_TEXT, COLOR_TEXT_SUB, RADIUS } from '../common/Theme';

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
  }
}
