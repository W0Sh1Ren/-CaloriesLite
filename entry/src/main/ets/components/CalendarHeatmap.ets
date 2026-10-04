/**
 * 月历热力图。
 *
 * 纯展示组件：格子数据由父组件一次算好传入，组件本身不碰存储，
 * 避免在 ForEach 里反复触发计算。
 *
 * 视觉参考 Apple 日历/健身：
 *   - 7 列等宽，日号居中，格子略高于字高，形成稳定的栅格
 *   - 选中日与今天用浅色圆角底衬出，不再用整块色块
 *   - 有记录的日子在日号下方点一个小圆点表示状态
 */
import {
  COLOR_CARD, COLOR_DIVIDER, COLOR_OK, COLOR_PRIMARY, COLOR_PRIMARY_SOFT,
  COLOR_TEXT, COLOR_TEXT_SUB, COLOR_WARN, CARD_SHADOW, RADIUS
} from '../common/Theme';

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
/**
 * 一格的高度。
 *
 * 只包住「日号圆 34 + 状态点 5」并留一点呼吸量即可。设太大时
 * 6 行会撑出一大片空白，日历看着松散（之前踩过：设成 46 时
 * 每行实际占到 150px）。
 */
const CELL_HEIGHT: number = 40;
/** 全透明色。写成字符串而不是 Color.Transparent，保证辅助函数返回类型一致 */
const TRANSPARENT: string = '#00000000';

@Component
export struct CalendarHeatmap {
  /** 42 个格子，由父组件算好 */
  @Prop cells: DayCell[] = [];
  @Prop selectedDay: string = '';
  /**
   * 换月动画的重放键：父组件每次换月自增。
   *
   * 用 @Watch 而不是比较月份：组件不需要知道月份怎么算，
   * 收到新键就播一次滑入动画。
   */
  @Prop @Watch('onMonthChange') animKey: number = 0;
  /** 换月方向：1 向后、-1 向前，决定从哪一侧滑入 */
  @Prop shiftDir: number = 1;
  onSelectDay: (dayKey: string) => void = () => {
  };

  /**
   * 换月动画的两个可插值量。
   *
   * 名字刻意避开 offset / opacity / scale / translate 这类词：
   * ArkUI 的 CustomComponent 基类已占用了同名属性（`offset()` / `opacity()`），
   * 用 gridOffset 会报「not assignable to the same property in base type」
   *（之前 scale / tabIndex 也踩过同一个坑）。
   */
  @State cellShift: number = 0;
  @State cellAlpha: number = 1;

  /**
   * 换月时播一次滑入。
   *
   * 先把位移摆到起点、透明度归零（**无动画**），下一帧再 animateTo 归位。
   * 同一帧里既摆起点又开动画，起点会来不及上屏就被覆盖，
   * 观感是「从中间冒出来」而不是「滑进来」。
   */
  onMonthChange(): void {
    this.cellShift = this.shiftDir >= 0 ? 40 : -40;
    this.cellAlpha = 0;
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: 260, curve: Curve.FastOutSlowIn }, () => {
        this.cellShift = 0;
        this.cellAlpha = 1;
      });
    }, 16);
  }

  /** 状态点的颜色：按缺口正负分级 */
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

  /** 选中态的底色。统一用字符串色值，避免 Color 枚举与 string 混用导致类型不匹配 */
  private cellBg(data: DayCell): string {
    if (!data.inMonth || data.isFuture) {
      return TRANSPARENT;
    }
    if (this.selectedDay === data.dayKey) {
      return COLOR_PRIMARY;
    }
    if (data.isToday) {
      return COLOR_PRIMARY_SOFT;
    }
    return TRANSPARENT;
  }

  /** 选中态的字色 */
  private cellTextColor(data: DayCell): string {
    if (!data.inMonth || data.isFuture) {
      return COLOR_DIVIDER;
    }
    if (this.selectedDay === data.dayKey) {
      return '#FFFFFF';
    }
    return data.isToday ? COLOR_PRIMARY : COLOR_TEXT;
  }

  /** 该格是否用中等字重（选中的今天） */
  private isEmphasized(index: number): boolean {
    const data: DayCell = this.cellAt(index);
    return this.selectedDay === data.dayKey || data.isToday;
  }

  /** 状态点底色：选中格不画点（与选中圆底撞色） */
  private dotBg(index: number): string {
    const data: DayCell = this.cellAt(index);
    return this.selectedDay === data.dayKey ? TRANSPARENT : this.dotColor(data);
  }

  build() {
    Column({ space: 2 }) {
      /*
       * 只有「格子区」参与换月动画，月份标题在父组件那边、不动。
       * 整块日历滑走会让上面的月份标题和下面的图例跟着跳，很乱。
       */
      Column({ space: 2 }) {
        // 星期表头：与下面的单元格共用同一套等宽栅格，保证对齐
        Row() {
          ForEach(WEEK_HEADER, (w: string) => {
            Text(w)
              .fontSize(11)
              .fontColor(COLOR_TEXT_SUB)
              .textAlign(TextAlign.Center)
              .layoutWeight(1)
              .height(28)
          }, (w: string) => w)
        }
        .width('100%')

      // 6 行 × 7 列。
      // 行高必须显式指定：只给格子设高度、行用默认约束时，
      // 纵向会被拉伸到填满可用空间，导致日历出现大片空白（踩过）。
      ForEach(ROW_INDEXES, (rowIndex: number) => {
        Row() {
          ForEach(COL_INDEXES, (colIndex: number) => {
            /*
             * 格子**必须内联**，不能抽成 this.dayCell(data) 这种 @Builder。
             *
             * @Builder 的入参只在容器构建时求值一次，之后数据变了不会重新求值，
             * 表现就是「切换月份后日历的日期与星期不跟着变」（实测反馈的 bug）。
             * 同一个坑在顶栏标题、热量环数字、首页标签上都踩过，
             * 解法统一是「内联，或改传 getter 函数」。
             */
            Column() {
              if (this.cellAt(rowIndex * 7 + colIndex).inMonth) {
                Stack() {
                  // 选中/今天底色：圆形而非方块，更接近 Apple 的日历
                  Row()
                    .width(32)
                    .height(32)
                    .backgroundColor(this.cellBg(this.cellAt(rowIndex * 7 + colIndex)))
                    .borderRadius(16)

                  Text(`${this.cellAt(rowIndex * 7 + colIndex).day}`)
                    .fontSize(15)
                    .fontWeight(this.isEmphasized(rowIndex * 7 + colIndex)
                      ? FontWeight.Medium : FontWeight.Normal)
                    .fontColor(this.cellTextColor(this.cellAt(rowIndex * 7 + colIndex)))
                }
                .width(32)
                .height(32)

                // 状态点：有记录才画，没记录留空占位保持行高一致
                Row()
                  .width(5)
                  .height(5)
                  .backgroundColor(this.dotBg(rowIndex * 7 + colIndex))
                  .borderRadius(3)
                  .margin({ top: 2 })
              }
            }
            .layoutWeight(1)
            .height(CELL_HEIGHT)
            .justifyContent(FlexAlign.Center)
            // 点击热区覆盖整格，而不是只有日号那么大
            .onClick(() => {
              const data: DayCell = this.cellAt(rowIndex * 7 + colIndex);
              if (data.inMonth && !data.isFuture) {
                this.onSelectDay(data.dayKey);
              }
            })
          }, (colIndex: number) => `c${rowIndex}-${colIndex}`)
        }
        .width('100%')
        .height(CELL_HEIGHT)
        }, (rowIndex: number) => `r${rowIndex}`)
      }
      .width('100%')
      // 换月动画：位移 + 淡入。两者都是可插值属性，animateTo 每帧重绘
      .translate({ x: `${this.cellShift}%` })
      .opacity(this.cellAlpha)

      // 图例
      Row({ space: 14 }) {
        this.legend(COLOR_OK, '有缺口')
        this.legend(COLOR_PRIMARY, '基本持平')
        this.legend(COLOR_WARN, '超标')
        this.legend(COLOR_DIVIDER, '未记录')
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .margin({ top: 10 })
    }
    .width('100%')
    .padding({ left: 8, right: 8, top: 14, bottom: 14 })
    .backgroundColor(COLOR_CARD)
    .borderRadius(RADIUS)
    .shadow(CARD_SHADOW)
  }

  @Builder
  legend(color: string, label: string) {
    Row({ space: 5 }) {
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
