/**
 * 首页核心：热量收支环。
 *
 * 用 Canvas 手绘两个同心圆弧（底环 + 进度弧），而不是 ArkUI 的 Progress 组件：
 * Progress 在 Ring 模式下不会把自身尺寸撑开给父 Stack，实测会被压扁成几十像素高，
 * 环只露出一小段。自绘既确定又可控。
 *
 * 环内显示当天的热量缺口，环下方列预算 / 摄入 / 运动三项。
 */
import { DailySummary } from '../model/Types';
import { COLOR_CARD, COLOR_OK, COLOR_PRIMARY, COLOR_PRIMARY_SOFT, COLOR_TEXT, COLOR_TEXT_SUB, COLOR_WARN, GAP, RADIUS } from '../common/Theme';

@Component
export struct CalorieRing {
  @Prop summary: DailySummary = new DailySummary('', 0, 0, 0, 0, 0, 0, 0);
  /** 环外径（vp） */
  @Prop diameter: number = 210;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  /** 已摄入占「预算 + 运动」的比例（0-1），超出按 1 画满 */
  private ratio(): number {
    const capacity: number = this.summary.budget + this.summary.exerciseKcal;
    if (capacity <= 0) {
      return 0;
    }
    const r: number = this.summary.intake / capacity;
    return Math.min(1, Math.max(0, r));
  }

  /** 超标时进度弧变红 */
  private arcColor(): string {
    return this.summary.deficit < 0 ? COLOR_WARN : COLOR_PRIMARY;
  }

  /** 按当前数据重绘 */
  private draw(): void {
    const ctx = this.ctx;
    const w: number = ctx.width;
    const h: number = ctx.height;
    ctx.clearRect(0, 0, w, h);
    if (w <= 0 || h <= 0) {
      return;
    }

    const stroke: number = 14;
    const radius: number = Math.min(w, h) / 2 - stroke / 2;
    const cx: number = w / 2;
    const cy: number = h / 2;

    // 底环：整圈浅色
    ctx.beginPath();
    ctx.strokeStyle = COLOR_PRIMARY_SOFT;
    ctx.lineWidth = stroke;
    ctx.lineCap = 'round';
    ctx.arc(cx, cy, radius, 0, Math.PI * 2);
    ctx.stroke();

    // 进度弧：从 12 点方向顺时针
    const r: number = this.ratio();
    if (r > 0) {
      const start: number = -Math.PI / 2;
      const end: number = start + Math.PI * 2 * r;
      ctx.beginPath();
      ctx.strokeStyle = this.arcColor();
      ctx.lineWidth = stroke;
      ctx.lineCap = 'round';
      ctx.arc(cx, cy, radius, start, end);
      ctx.stroke();
    }
  }

  build() {
    Column({ space: GAP }) {
      Stack() {
        // 自绘圆环
        Canvas(this.ctx)
          .width(this.diameter)
          .height(this.diameter)
          .onReady(() => {
            // onReady 时才能拿到真实绘制尺寸
            this.draw();
          })

        // 环心数字
        Column({ space: 2 }) {
          Text(this.summary.deficit < 0 ? '超出' : '热量缺口')
            .fontSize(13)
            .fontColor(COLOR_TEXT_SUB)

          Text(`${Math.abs(this.summary.deficit)}`)
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
