/**
 * 体重趋势折线图。
 *
 * 用 Canvas 手绘：只有一条折线 + 数据点 + 首尾标注，
 * 相比引入图表库更轻，也更容易保持一致视觉。
 */
import { WeightRecord } from '../model/Types';
import { CARD_SHADOW, COLOR_CARD, COLOR_DIVIDER, COLOR_PRIMARY, COLOR_TEXT, COLOR_TEXT_SUB, RADIUS } from '../common/Theme';

/** 图表内的内边距，给坐标文字留位置 */
const PAD_LEFT = 34;
const PAD_RIGHT = 12;
const PAD_TOP = 14;
const PAD_BOTTOM = 20;

@Component
export struct WeightChart {
  @Prop records: WeightRecord[] = [];
  @Prop chartHeight: number = 160;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  /** Canvas 是否已经完成布局。未就绪时 draw 拿不到真实宽高 */
  private canvasReady: boolean = false;

  /**
   * 数据变化时重绘。
   *
   * 这里必须显式重绘：Canvas 的内容不是声明式的，onReady 只在
   * 组件首次布局完成时触发一次。少了这一步就会出现
   * 「记录了体重、『1 次记录』也变了，但图里还写着还没有体重记录」，
   * 因为 records 更新后根本没人再调用 draw。
   */
  onDidUpdate(): void {
    if (this.canvasReady) {
      this.draw(this.ctx.width, this.ctx.height);
    }
  }

  /** 按当前数据重绘 */
  private draw(width: number, height: number): void {
    const ctx = this.ctx;
    ctx.clearRect(0, 0, width, height);

    const list: WeightRecord[] = this.records;
    if (list.length === 0) {
      ctx.font = '13px sans-serif';
      ctx.fillStyle = COLOR_TEXT_SUB;
      ctx.textAlign = 'center';
      ctx.fillText('还没有体重记录', width / 2, height / 2);
      return;
    }

    // Y 轴范围：留 0.5kg 余量，避免折线贴边
    let min: number = list[0].weightKg;
    let max: number = list[0].weightKg;
    for (const r of list) {
      min = Math.min(min, r.weightKg);
      max = Math.max(max, r.weightKg);
    }
    if (max - min < 1) {
      const mid: number = (max + min) / 2;
      min = mid - 0.5;
      max = mid + 0.5;
    } else {
      min -= 0.3;
      max += 0.3;
    }

    const plotW: number = width - PAD_LEFT - PAD_RIGHT;
    const plotH: number = height - PAD_TOP - PAD_BOTTOM;
    const range: number = max - min;

    // 横坐标
    const xAt = (i: number): number => {
      if (list.length === 1) {
        return PAD_LEFT + plotW / 2;
      }
      return PAD_LEFT + plotW * i / (list.length - 1);
    };
    // 纵坐标（数值越大越靠上）
    const yAt = (v: number): number => PAD_TOP + plotH * (1 - (v - min) / range);

    // 参考网格线：三条
    ctx.strokeStyle = COLOR_DIVIDER;
    ctx.lineWidth = 1;
    for (let i = 0; i <= 2; i++) {
      const y: number = PAD_TOP + plotH * i / 2;
      ctx.beginPath();
      ctx.moveTo(PAD_LEFT, y);
      ctx.lineTo(width - PAD_RIGHT, y);
      ctx.stroke();
    }

    // Y 轴刻度文字
    ctx.font = '10px sans-serif';
    ctx.fillStyle = COLOR_TEXT_SUB;
    ctx.textAlign = 'right';
    ctx.fillText(max.toFixed(1), PAD_LEFT - 5, PAD_TOP + 4);
    ctx.fillText(((max + min) / 2).toFixed(1), PAD_LEFT - 5, PAD_TOP + plotH / 2 + 4);
    ctx.fillText(min.toFixed(1), PAD_LEFT - 5, PAD_TOP + plotH + 4);

    // 折线
    ctx.strokeStyle = COLOR_PRIMARY;
    ctx.lineWidth = 2;
    ctx.lineJoin = 'round';
    ctx.lineCap = 'round';
    ctx.beginPath();
    for (let i = 0; i < list.length; i++) {
      const x: number = xAt(i);
      const y: number = yAt(list[i].weightKg);
      if (i === 0) {
        ctx.moveTo(x, y);
      } else {
        ctx.lineTo(x, y);
      }
    }
    ctx.stroke();

    // 数据点：点太多时只标首尾，避免糊成一片
    const dotRadius: number = list.length > 30 ? 1.5 : 3;
    for (let i = 0; i < list.length; i++) {
      ctx.beginPath();
      ctx.fillStyle = COLOR_PRIMARY;
      ctx.arc(xAt(i), yAt(list[i].weightKg), dotRadius, 0, Math.PI * 2);
      ctx.fill();
    }

    // 最新值标注在最后一个点上方
    const lastIndex: number = list.length - 1;
    ctx.fillStyle = COLOR_TEXT;
    ctx.font = '11px sans-serif';
    ctx.textAlign = 'right';
    ctx.fillText(`${list[lastIndex].weightKg} kg`, width - PAD_RIGHT, Math.max(12, yAt(list[lastIndex].weightKg) - 8));
  }

  build() {
    Column({ space: 8 }) {
      Row() {
        Text('体重趋势')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_TEXT)
        Blank()
        if (this.records.length > 0) {
          Text(`${this.records.length} 次记录`)
            .fontSize(12)
            .fontColor(COLOR_TEXT_SUB)
        }
      }
      .width('100%')

      Canvas(this.ctx)
        .width('100%')
        .height(this.chartHeight)
        .onReady(() => {
          // onReady 时才能拿到真实绘制尺寸
          this.canvasReady = true;
          this.draw(this.ctx.width, this.ctx.height);
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(COLOR_CARD)
    .borderRadius(RADIUS)
    .shadow(CARD_SHADOW)
  }
}
