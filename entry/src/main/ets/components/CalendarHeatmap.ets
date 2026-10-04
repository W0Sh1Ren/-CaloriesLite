/**
 * 月历热力图。
 *
 * 纯展示组件：格子数据由父组件一次算好传入，组件本身不碰存储，
 * 避免 ForEach 里反复触发计算。
 *
 * 配色含义：绿 = 当天有热量缺口（达标），橙 = 基本持平，红 = 超标，灰 = 没记录。
 */
import { CARD_SHADOW, COLOR_CARD, COLOR_DIVIDER, COLOR_OK, COLOR_PRIMARY, COLOR_TEXT, COLOR_TEXT_SUB, COLOR_WARN, RADIUS } from '../common/Theme';

/** 单个格子的展示数据 */
export class DayCell {
  dayKey: string = '';
  day: number = 0;
  inMonth: boolean = false;
  deficit: number = 0;
  hasRecord: boolean = false;
  isToday: boolean = false;
  isFuture: boolean = false;

  constructor(dayKey: string, day: number, inMonth: boolean, deficit: number,
    hasRecord: boolean, isToday: boolean, isFuture: boolean) {
    this.dayKey = dayKey;
    this.day = day;
    this.inMonth = inMonth;
    this.deficit = deficit;
    this.hasRecord = hasRecord;
    this.isToday = isToday;
    this.isFuture = isFuture;
  }
}

const WEEK_HEADER: string[] = ['日', '一', '二', '三', '四', '五', '六'];
const ROW_INDEXES: number[] = [0, 1, 2, 3, 4, 5];
const COL_INDEXES: number[] = [0, 1, 2, 3, 4, 5, 6];

@Component
export struct CalendarHeatmap {
  /** 42 个格子，由父组件算好 */
  @Prop cells: DayCell[] = [];
  @Prop selectedDay: string = '';
  onSelectDay: (dayKey: string) => void = () => {
  };

  /** 格子底色：按缺口正负与大小分级 */
  private dotColor(data: DayCell): string {
    if (!data.hasRecord) {
      return COLOR_DIVIDER;
    }
    if (data.deficit < 0) {
      return COLOR_WARN;
    }
    if (data.deficit <= 150) {
      return COLOR_PRIMARY;
    }
    return COLOR_OK;
  }

  /** 按下标取格子，越界返回占位，避免渲染期抛异常 */
  private cellAt(index: number): DayCell {
    if (index < 0 || index >= this.cells.length) {
      return new DayCell('', 0, false, 0, false, false, false);
    }
    return this.cells[index];
  }

  build() {
    Column({ space: 6 }) {
      // 星期表头
      Row() {
        ForEach(WEEK_HEADER, (w: string) => {
          Text(w)
            .fontSize(12)
            .fontColor(COLOR_TEXT_SUB)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
        }, (w: string) => w)
      }
      .width('100%')

      // 6 行 × 7 列
      ForEach(ROW_INDEXES, (rowIndex: number) => {
        Row() {
          ForEach(COL_INDEXES, (colIndex: number) => {
            this.dayCell(this.cellAt(rowIndex * 7 + colIndex))
          }, (colIndex: number) => `c${rowIndex}-${colIndex}`)
        }
        .width('100%')
      }, (rowIndex: number) => `r${rowIndex}`)

      // 图例
      Row({ space: 12 }) {
        this.legend(COLOR_OK, '有缺口')
        this.legend(COLOR_PRIMARY, '基本持平')
        this.legend(COLOR_WARN, '超标')
        this.legend(COLOR_DIVIDER, '未记录')
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .margin({ top: 4 })
    }
    .width('100%')
    .padding(14)
    .backgroundColor(COLOR_CARD)
    .borderRadius(RADIUS)
    .shadow(CARD_SHADOW)
  }

  @Builder
  dayCell(data: DayCell) {
    Column() {
      if (data.inMonth) {
        Text(`${data.day}`)
          .fontSize(14)
          .fontWeight(data.isToday ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(data.isFuture ? COLOR_DIVIDER : COLOR_TEXT)

        Row()
          .width(data.hasRecord ? 6 : 0)
          .height(6)
          .backgroundColor(this.dotColor(data))
          .borderRadius(3)
          .margin({ top: 2 })
      }
    }
    .layoutWeight(1)
    .height(40)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.selectedDay === data.dayKey && data.dayKey.length > 0 ? '#FFF3EC' : Color.Transparent)
    .borderRadius(8)
    .onClick(() => {
      if (data.inMonth && !data.isFuture) {
        this.onSelectDay(data.dayKey);
      }
    })
  }

  @Builder
  legend(color: string, label: string) {
    Row({ space: 4 }) {
      Row()
        .width(6)
        .height(6)
        .backgroundColor(color)
        .borderRadius(3)
      Text(label)
        .fontSize(11)
        .fontColor(COLOR_TEXT_SUB)
    }
  }
}
