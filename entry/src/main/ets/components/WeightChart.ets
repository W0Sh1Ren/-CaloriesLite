/**
 * 体重趋势折线图。
 *
 * 用 Canvas 手绘：只有一条折线 + 数据点 + 首尾标注，
 * 相比引入图表库更轻，也更容易保持一致视觉。
 *
 * 坐标轴说明：
 *   纵轴 = 体重（kg），刻度值标在左侧
 *   横轴 = 日期，只标首尾两天（点多了会糊成一片）
 * 轴名称用固定文字标在左上 / 右下角，省掉刻度的空间又保证看得懂。
 */
import { WeightRecord } from '../model/Types';
import { CARD_SHADOW, COLOR_CARD, COLOR_DIVIDER, COLOR_PRIMARY, COLOR_TEXT, COLOR_TEXT_SUB, RADIUS } from '../common/Theme';

/** 图表内边距。左边留给体重刻度，下边留给日期 */
const PAD_LEFT = 46;
const PAD_RIGHT = 16;
const PAD_TOP = 26;
const PAD_BOTTOM = 32;

@Component
export struct WeightChart {
  @Prop records: WeightRecord[] = [];
  @Prop chartHeight: number = 170;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  /** Canvas 是否已完成布局。未就绪时拿不到真实宽高 */
  private canvasReady: boolean = false;

  /**
   * 数据变化时重绘。
   *
   * 必须显式重绘：Canvas 内容不是声明式的，onReady 只在首次布局时触发一次。
   * 少这一步就会出现「记录了体重、『N 次记录』也变了，
   * 但图里还写着还没有体重记录」（实测踩过）。
   */
  onDidUpdate(): void {
    if (this.canvasReady) {
      this.draw(this.ctx.width, this.ctx.height);
    }
  }

  /** 把 YYYY-MM-DD 压成 M/D，横轴用 */
  private shortDate(dayKey: string): string {
    const parts: string[] = dayKey.split('-');
    if (parts.length < 3) {
      return dayKey;
    }
    return `${Number.parseInt(parts[1])}/${Number.parseInt(parts[2])}`;
  }

  /** 按当前数据重绘 */
  private draw(width: number, height: number): void {
    const ctx = this.ctx;
    ctx.clearRect(0, 0, width, height);

    const list: WeightRecord[] = this.records;
    if (list.length === 0) {
      ctx.font = '15px sans-serif';
      ctx.fillStyle = COLOR_TEXT_SUB;
      ctx.textAlign = 'center';
      ctx.fillText('还没有体重记录', width / 2, height / 2);
      return;
    }

    // Y 轴范围：留余量，避免折线贴边
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

    // Y 轴刻度文字（体重）
    ctx.font = '14px sans-serif';
    ctx.fillStyle = COLOR_TEXT_SUB;
    ctx.textAlign = 'right';
    ctx.fillText(max.toFixed(1), PAD_LEFT - 7, PAD_TOP + 5);
    ctx.fillText(((max + min) / 2).toFixed(1), PAD_LEFT - 7, PAD_TOP + plotH / 2 + 5);
    ctx.fillText(min.toFixed(1), PAD_LEFT - 7, PAD_TOP + plotH + 5);

    // 轴名称：左上标「体重(kg)」，右下标「日期」
    ctx.textAlign = 'left';
    ctx.fillStyle = COLOR_TEXT_SUB;
    ctx.font = '13px sans-serif';
    ctx.fillText('体重(kg)', 2, 15);

    // X 轴日期：首尾各标一个
    ctx.textAlign = 'center';
    ctx.fillText(this.shortDate(list[0].dayKey), PAD_LEFT, height - 14);
    if (list.length > 1) {
      ctx.fillText(this.shortDate(list[list.length - 1].dayKey), width - PAD_RIGHT, height - 14);
    }
    // 横轴名称放在最底一行，与日期错开避免重叠
    ctx.textAlign = 'right';
    ctx.fillText('日期', width - PAD_RIGHT, height - 2);

    // 折线
    ctx.strokeStyle = COLOR_PRIMARY;
    ctx.lineWidth = 2.5;
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

    // 数据点：点太多时缩小，避免糊成一片
    const dotRadius: number = list.length > 30 ? 2 : 3.5;
    for (let i = 0; i < list.length; i++) {
      ctx.beginPath();
      ctx.fillStyle = COLOR_PRIMARY;
      ctx.arc(xAt(i), yAt(list[i].weightKg), dotRadius, 0, Math.PI * 2);
      ctx.fill();
    }

    // 最新值标注在最后一个点上方
    const lastIndex: number = list.length - 1;
    ctx.fillStyle = COLOR_TEXT;
    ctx.font = '15px sans-serif';
    ctx.textAlign = 'right';
    ctx.fillText(`${list[lastIndex].weightKg} kg`, width - PAD_RIGHT,
      Math.max(18, yAt(list[lastIndex].weightKg) - 12));
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
