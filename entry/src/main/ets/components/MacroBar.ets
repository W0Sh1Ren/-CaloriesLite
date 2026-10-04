/**
 * 三大营养素展示条。
 *
 * 只展示当日摄入的克数，不做「达标率」判断 —— 极简应用不该引入
 * 需要用户先设定营养素配比才能看懂的指标。
 */
import { CARD_SHADOW, COLOR_CARB, COLOR_CARD, COLOR_DIVIDER, COLOR_FAT, COLOR_PROTEIN, COLOR_TEXT, COLOR_TEXT_SUB, RADIUS } from '../common/Theme';

/** 单项数据 */
class MacroItem {
  label: string;
  grams: number;
  color: string;

  constructor(label: string, grams: number, color: string) {
    this.label = label;
    this.grams = grams;
    this.color = color;
  }
}

@Component
export struct MacroBar {
  @Prop protein: number = 0;
  @Prop fat: number = 0;
  @Prop carb: number = 0;

  /** 取三者最大值作为条形基准，突出相对比例 */
  private maxGrams(): number {
    const m: number = Math.max(this.protein, Math.max(this.fat, this.carb));
    return m <= 0 ? 1 : m;
  }

  private items(): MacroItem[] {
    return [
      new MacroItem('蛋白质', this.protein, COLOR_PROTEIN),
      new MacroItem('脂肪', this.fat, COLOR_FAT),
      new MacroItem('碳水', this.carb, COLOR_CARB)
    ];
  }

  build() {
    Column({ space: 10 }) {
      ForEach(this.items(), (item: MacroItem) => {
        Row({ space: 10 }) {
          Text(item.label)
            .fontSize(13)
            .fontColor(COLOR_TEXT_SUB)
            .width(48)

          // 条形：外层灰底，内层按比例着色
          Stack({ alignContent: Alignment.Start }) {
            Row()
              .width('100%')
              .height(8)
              .backgroundColor(COLOR_DIVIDER)
              .borderRadius(4)

            Row()
              .width(`${Math.min(100, item.grams / this.maxGrams() * 100)}%`)
              .height(8)
              .backgroundColor(item.color)
              .borderRadius(4)
          }
          .layoutWeight(1)
          .height(8)

          Text(`${item.grams} g`)
            .fontSize(13)
            .fontColor(COLOR_TEXT)
            .width(56)
            .textAlign(TextAlign.End)
        }
        .width('100%')
      })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(COLOR_CARD)
    .borderRadius(RADIUS)
    .shadow(CARD_SHADOW)
  }
}
