/**
 * 三大营养素进度条。
 *
 * 显示当日摄入量相对「推荐量」的完成度。推荐量由每日总消耗按
 * 碳水 50% / 蛋白质 30% / 脂肪 20% 的热量占比反推克数得到
 * （见 Enums.macroTargetFor），所以换个人、换个目标都会自动跟着变。
 *
 * 用推荐量做分母而不是「三项里的最大值」：后者只能看出三项的相对高低，
 * 看不出「离推荐量还差多少」，而后者才是用户真正关心的。
 *
 * 条形宽度带连续动画：数据变化时不是瞬间跳到新比例，而是从当前位置推过去。
 */
import {
  CARD_SHADOW, COLOR_CARB, COLOR_CARD, COLOR_DIVIDER, COLOR_FAT,
  COLOR_PROTEIN, COLOR_TEXT, COLOR_TEXT_SUB, DUR_SLOW, RADIUS
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
  // 加 @Watch 是为了在数据变化时推动条形动画。
  // 注意监测的是「克数」而不是算出来的百分比：两者同步变化，
  // 但克数是入参本身，@Watch 一定能收到。
  @Prop @Watch('onDataChange') protein: number = 0;
  @Prop @Watch('onDataChange') fat: number = 0;
  @Prop @Watch('onDataChange') carb: number = 0;
  /** 三大营养素的推荐克数，由调用方按当日预算算好后传入 */
  @Prop carbTarget: number = 0;
  @Prop proteinTarget: number = 0;
  @Prop fatTarget: number = 0;

  /**
   * 三项的显示百分比。
   *
   * 用 @State 数组 + animateTo：animateTo 每帧重建组件，
   * 而 width 是属性、可被插值，于是三根条连续滑动。
   */
  @State animPct: number[] = [0, 0, 0];

  aboutToAppear(): void {
    // 首帧直接落位，避免一进页面三根条从 0 长出来
    this.snapAll();
  }

  /** 数据变化：把三根条平滑推到新比例 */
  onDataChange(): void {
    const list: MacroItem[] = this.items();
    const from: number[] = this.animPct.slice();
    const target: number[] = [];
    for (let i = 0; i < list.length; i++) {
      target.push(list[i].percent());
    }
    // 先把起点写回，再从起点推到目标，连续切换时不会跳
    this.animPct = from;
    this.getUIContext().animateTo({ duration: DUR_SLOW, curve: Curve.EaseOut }, () => {
      this.animPct = target;
    });
  }

  /** 不做动画，直接把显示值设为目标 */
  private snapAll(): void {
    const list: MacroItem[] = this.items();
    const next: number[] = [];
    for (let i = 0; i < list.length; i++) {
      next.push(list[i].percent());
    }
    this.animPct = next;
  }

  private items(): MacroItem[] {
    return [
      new MacroItem('碳水', this.carb, this.carbTarget, COLOR_CARB),
      new MacroItem('蛋白质', this.protein, this.proteinTarget, COLOR_PROTEIN),
      new MacroItem('脂肪', this.fat, this.fatTarget, COLOR_FAT)
    ];
  }

  /** 取第 i 项的显示宽度百分比 */
  private pctAt(i: number): number {
    return i < this.animPct.length ? this.animPct[i] : 0;
  }

  build() {
    Column({ space: 12 }) {
      ForEach(this.items(), (item: MacroItem, index: number) => {
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

          /*
           * 条形：外层浅灰底，内层按完成度着色。
           *
           * 宽度交给外层 Row 撑满，Stack 只负责把两层条子叠在一起。
           * 注意这里绝不能在 Stack 上写 layoutWeight：
           * Stack 的父级是 Column（纵向），layoutWeight 会被解释成
           * **纵向**扩张，把每一项都拉到整张卡片那么高
           * （实测过：卡片被撑满屏、条形漂到屏幕中间）。
           */
          Row() {
            Stack({ alignContent: Alignment.Start }) {
              Row()
                .width('100%')
                .height(8)
                .backgroundColor(COLOR_DIVIDER)
                .borderRadius(4)

              Row()
                .width(`${this.pctAt(index)}%`)
                .height(8)
                .backgroundColor(item.color)
                .borderRadius(4)
            }
            .width('100%')
            .height(8)
          }
          .width('100%')
          .height(8)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }, (item: MacroItem, index: number) => `${index}-${item.label}`)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(COLOR_CARD)
    .borderRadius(RADIUS)
    .shadow(CARD_SHADOW)
  }
}
