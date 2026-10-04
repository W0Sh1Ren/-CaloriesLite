/**
 * 三大营养素进度条。
 *
 * 显示当日摄入量相对「推荐量」的完成度。推荐量由每日总消耗按
 * 碳水 50% / 蛋白质 30% / 脂肪 20% 的热量占比反推克数得到
 * （见 Enums.macroTargetFor），所以换个人、换个目标都会自动跟着变。
 *
 * 用推荐量做分母而不是「三项里的最大值」：后者只能看出三项的相对高低，
 * 看不出「离推荐量还差多少」，而后者才是用户真正关心的。
 */
import {
  CARD_SHADOW, COLOR_CARB, COLOR_CARD, COLOR_DIVIDER, COLOR_FAT, COLOR_PROTEIN,
  COLOR_TEXT, COLOR_TEXT_SUB, RADIUS
} from '../common/Theme';

/** 单项数据 */
class MacroItem {
  label: string;
  grams: number;
  target: number;
  color: string;

  constructor(label: string, grams: number, target: number, color: string) {
    this.label = label;
    this.grams = grams;
    this.target = target;
    this.color = color;
  }

  /** 完成度百分比，封顶 100 以免条形溢出容器 */
  percent(): number {
    if (this.target <= 0) {
      return 0;
    }
    const p: number = this.grams / this.target * 100;
    return Math.max(0, Math.min(100, p));
  }
}

@Component
export struct MacroBar {
  @Prop protein: number = 0;
  @Prop fat: number = 0;
  @Prop carb: number = 0;
  /** 三大营养素的推荐克数，由调用方按当日预算算好后传入 */
  @Prop carbTarget: number = 0;
  @Prop proteinTarget: number = 0;
  @Prop fatTarget: number = 0;

  private items(): MacroItem[] {
    return [
      new MacroItem('碳水', this.carb, this.carbTarget, COLOR_CARB),
      new MacroItem('蛋白质', this.protein, this.proteinTarget, COLOR_PROTEIN),
      new MacroItem('脂肪', this.fat, this.fatTarget, COLOR_FAT)
    ];
  }

  build() {
    Column({ space: 12 }) {
      ForEach(this.items(), (item: MacroItem) => {
        Column({ space: 5 }) {
          Row() {
            Text(item.label)
              .fontSize(13)
              .fontColor(COLOR_TEXT_SUB)
            Blank()
            // 摄入 / 推荐，两个数字都给出，用户才知道自己处在什么位置
            Text(`${item.grams} / ${item.target} g`)
              .fontSize(12)
              .fontColor(COLOR_TEXT)
          }
          .width('100%')

          // 条形：外层浅灰底，内层按完成度着色
          Stack({ alignContent: Alignment.Start }) {
            Row()
              .width('100%')
              .height(8)
              .backgroundColor(COLOR_DIVIDER)
              .borderRadius(4)

            Row()
              .width(`${item.percent()}%`)
              .height(8)
              .backgroundColor(item.color)
              .borderRadius(4)
          }
          .layoutWeight(1)
          .width('100%')
          .height(8)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(COLOR_CARD)
    .borderRadius(RADIUS)
    .shadow(CARD_SHADOW)
  }
}
