/**
 * 首页核心：热量收支环。
 *
 * 展示「预算 / 已摄入 / 缺口」三个数字，
 * 环本身表示已摄入占预算的比例，超标时变红。
 */
import { DailySummary } from '../model/Types';
import { COLOR_CARD, COLOR_OK, COLOR_PRIMARY, COLOR_PRIMARY_SOFT, COLOR_TEXT, COLOR_TEXT_SUB, COLOR_WARN, GAP, RADIUS } from '../common/Theme';

@Component
export struct CalorieRing {
  @Prop summary: DailySummary = new DailySummary('', 0, 0, 0, 0, 0, 0, 0);
  /** 环直径 */
  @Prop diameter: number = 210;

  /** 已摄入占「预算 + 运动」的比例，封顶 100 */
  private ringPercent(): number {
    const capacity: number = this.summary.budget + this.summary.exerciseKcal;
    if (capacity <= 0) {
      return 0;
    }
    const pct: number = this.summary.intake / capacity * 100;
    return Math.min(100, Math.max(0, pct));
  }

  /** 超标时环变红 */
  private ringColor(): string {
    return this.summary.deficit < 0 ? COLOR_WARN : COLOR_PRIMARY;
  }

  /** 缺口文案：正数是缺口，负数是超出 */
  private deficitLabel(): string {
    return this.summary.deficit < 0 ? '超出' : '热量缺口';
  }

  private deficitValue(): string {
    return `${Math.abs(this.summary.deficit)}`;
  }

  build() {
    Column({ space: GAP }) {
      Stack() {
        // 底层环
        Progress({
          value: this.ringPercent(),
          total: 100,
          type: ProgressType.Ring
        })
          .width(this.diameter)
          .height(this.diameter)
          .color(this.ringColor())
          .backgroundColor(COLOR_PRIMARY_SOFT)
          .style({ strokeWidth: 14 })

        // 环心内容
        Column({ space: 2 }) {
          Text(this.deficitLabel())
            .fontSize(13)
            .fontColor(COLOR_TEXT_SUB)

          Text(this.deficitValue())
            .fontSize(48)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.summary.deficit < 0 ? COLOR_WARN : COLOR_TEXT)

          Text('千卡')
            .fontSize(13)
            .fontColor(COLOR_TEXT_SUB)
        }
        .alignItems(HorizontalAlign.Center)
      }
      .width(this.diameter)
      .height(this.diameter)

      // 预算与摄入明细
      Row() {
        this.statCell('已摄入', `${this.summary.intake}`, COLOR_PRIMARY)
        Divider().vertical(true).height(28).color(COLOR_PRIMARY_SOFT)
        this.statCell('基础预算', `${this.summary.budget}`, COLOR_TEXT)
        Divider().vertical(true).height(28).color(COLOR_PRIMARY_SOFT)
        this.statCell('运动消耗', `${this.summary.exerciseKcal}`, COLOR_OK)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceEvenly)
    }
    .width('100%')
    .padding(20)
    .backgroundColor(COLOR_CARD)
    .borderRadius(RADIUS)
  }

  @Builder
  statCell(label: string, value: string, valueColor: string) {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor(valueColor)
      Text(label)
        .fontSize(12)
        .fontColor(COLOR_TEXT_SUB)
    }
  }
}
