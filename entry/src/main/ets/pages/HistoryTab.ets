/**
 * 「记录」标签页：月历热力 + 当日明细 + 体重趋势 + 运动录入。
 */
import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { DayCell, CalendarHeatmap } from '../components/CalendarHeatmap';
import { WeightChart } from '../components/WeightChart';
import { MealType, FoodRecord, WeightRecord, ExerciseRecord, DailySummary } from '../model/Types';
import { MEAL_ORDER, mealTypeLabel } from '../model/Enums';
import { buildMonthGrid, friendlyDate, fromDayKey, todayKey, timeLabel } from '../common/DateUtil';
import { makeId } from '../common/JsonUtil';
import { DailyService } from '../service/DailyService';
import { FoodRepo } from '../service/FoodRepo';
import { BodyRepo } from '../service/BodyRepo';
import { ExerciseRepo } from '../service/ExerciseRepo';
import { calcExerciseKcal, MET_TABLE, MetItem } from '../service/CalorieCalc';
import { COLOR_BG, COLOR_CARD, COLOR_DIVIDER, COLOR_OK, COLOR_PRIMARY, COLOR_TEXT, COLOR_TEXT_SUB, COLOR_WARN, GAP, PAGE_PAD, RADIUS } from '../common/Theme';

const DOMAIN = 0x0000;

@Component
export struct HistoryTab {
  /** 主页面当前选中的日期 */
  @Prop dayKey: string = todayKey();
  /** 主页面自增的刷新信号 */
  @Prop refreshTick: number = 0;

  /** 月历当前显示的月份 */
  @State viewYear: number = 0;
  @State viewMonth0: number = 0;
  @State selectedDay: string = '';
  @State cells: DayCell[] = [];
  @State detail: DailySummary = new DailySummary('', 0, 0, 0, 0, 0, 0, 0);
  @State detailRecords: FoodRecord[] = [];
  @State weights: WeightRecord[] = [];
  @State exercises: ExerciseRecord[] = [];
  @State weightInput: string = '';

  aboutToAppear(): void {
    const now = new Date();
    this.viewYear = now.getFullYear();
    this.viewMonth0 = now.getMonth();
    this.selectedDay = this.dayKey;
    this.rebuild();
  }

  /** 主页面翻日期或恢复前台时同步过来 */
  onDidUpdate(): void {
    if (this.selectedDay !== this.dayKey && this.dayKey.length > 0) {
      this.selectedDay = this.dayKey;
      const d = new Date(fromDayKey(this.dayKey));
      this.viewYear = d.getFullYear();
      this.viewMonth0 = d.getMonth();
    }
    this.rebuild();
  }

  /** 重算月历格子与当日明细 */
  private rebuild(): void {
    this.cells = this.buildCells();
    this.detail = DailyService.summaryOf(this.selectedDay);
    this.detailRecords = FoodRepo.loadDay(this.selectedDay);
    this.weights = BodyRepo.recent(60);
    this.exercises = ExerciseRepo.loadDay(this.selectedDay);
  }

  private buildCells(): DayCell[] {
    const raw = buildMonthGrid(this.viewYear, this.viewMonth0);
    const today: string = todayKey();
    const todayTs: number = fromDayKey(today);
    const out: DayCell[] = [];
    for (const c of raw) {
      if (!c.inMonth) {
        out.push(new DayCell('', 0, false, 0, false, false, false));
        continue;
      }
      const s: DailySummary = DailyService.summaryOf(c.dayKey);
      out.push(new DayCell(c.dayKey, c.day, true, s.deficit, s.recordCount > 0,
        c.dayKey === today, fromDayKey(c.dayKey) > todayTs));
    }
    return out;
  }

  /** 换月 */
  private shiftMonth(delta: number): void {
    let y: number = this.viewYear;
    let m: number = this.viewMonth0 + delta;
    if (m < 0) {
      m = 11;
      y--;
    } else if (m > 11) {
      m = 0;
      y++;
    }
    this.viewYear = y;
    this.viewMonth0 = m;
    this.cells = this.buildCells();
  }

  /** 保存体重：同一天覆盖 */
  private saveWeight(): void {
    const v: number = Number.parseFloat(this.weightInput);
    if (Number.isNaN(v) || v < 20 || v > 400) {
      promptAction.showToast({ message: '请输入 20-400 之间的体重（公斤）' });
      return;
    }
    BodyRepo.upsert(new WeightRecord(this.selectedDay, Math.round(v * 10) / 10, Date.now()));
    this.weightInput = '';
    this.weights = BodyRepo.recent(60);
    promptAction.showToast({ message: '已记录体重' });
  }

  /** 弹窗选择运动项目与时长 */
  private async pickExercise(): Promise<void> {
    const buttons: promptAction.Button[] = [];
    // 弹窗按钮上限有限，只放最常用的几项 + 取消
    const quick: MetItem[] = MET_TABLE.slice(0, 6);
    for (const m of quick) {
      buttons.push({ text: m.name, color: COLOR_TEXT });
    }
    buttons.push({ text: '取消', color: COLOR_TEXT_SUB });

    try {
      const res = await promptAction.showDialog({
        title: '选择运动项目',
        message: '点击后按 30 分钟估算消耗，可再修改',
        buttons: buttons
      });
      if (res.index < 0 || res.index >= quick.length) {
        return;
      }
      const item: MetItem = quick[res.index];
      this.addExercise(item, 30);
    } catch (err) {
      hilog.error(DOMAIN, 'CalorieLite', 'pickExercise failed: %{public}s', JSON.stringify(err));
    }
  }

  /** 按时长写入运动记录 */
  private addExercise(item: MetItem, minutes: number): void {
    const weight: number = DailyService.latestWeight();
    const kcal: number = calcExerciseKcal(item.met, weight, minutes);
    ExerciseRepo.add(new ExerciseRecord(
      makeId(), this.selectedDay, Date.now(), item.name, kcal, minutes, 'manual'
    ));
    this.exercises = ExerciseRepo.loadDay(this.selectedDay);
    this.detail = DailyService.summaryOf(this.selectedDay);
    this.cells = this.buildCells();
    promptAction.showToast({ message: `已记录 ${item.name}，消耗约 ${kcal} 千卡` });
  }

  build() {
    Scroll() {
      Column({ space: GAP }) {
        // ------------------------------------------------ 月历
        Column({ space: 10 }) {
          Row() {
            Button({ type: ButtonType.Circle }) {
              Text('‹').fontSize(20).fontColor(COLOR_TEXT)
            }
            .width(32).height(32).backgroundColor(COLOR_BG)
            .onClick(() => {
              this.shiftMonth(-1);
            })

            Text(`${this.viewYear}年${this.viewMonth0 + 1}月`)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(COLOR_TEXT)
              .layoutWeight(1)
              .textAlign(TextAlign.Center)

            Button({ type: ButtonType.Circle }) {
              Text('›').fontSize(20).fontColor(COLOR_TEXT)
            }
            .width(32).height(32).backgroundColor(COLOR_BG)
            .onClick(() => {
              this.shiftMonth(1);
            })
          }
          .width('100%')

          CalendarHeatmap({
            cells: this.cells,
            selectedDay: this.selectedDay,
            onSelectDay: (day: string) => {
              this.selectedDay = day;
              this.rebuild();
            }
          })
        }
        .width('100%')

        // ------------------------------------------------ 当日结算
        this.dayDetailCard()

        // ------------------------------------------------ 运动
        this.exerciseCard()

        // ------------------------------------------------ 体重
        this.weightCard()

        Row().height(16)
      }
      .width('100%')
      .padding({ left: PAGE_PAD, right: PAGE_PAD, top: 8, bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BG)
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
  }

  @Builder
  dayDetailCard() {
    Column({ space: 10 }) {
      Row() {
        Text(friendlyDate(this.selectedDay))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_TEXT)
        Blank()
        Text(this.detail.deficit < 0
          ? `超出 ${-this.detail.deficit}`
          : `缺口 ${this.detail.deficit}`)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.detail.deficit < 0 ? COLOR_WARN : COLOR_OK)
        Text(' 千卡')
          .fontSize(12)
          .fontColor(COLOR_TEXT_SUB)
      }
      .width('100%')

      Row() {
        this.miniStat('摄入', `${this.detail.intake}`)
        this.miniStat('预算', `${this.detail.budget}`)
        this.miniStat('运动', `${this.detail.exerciseKcal}`)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      if (this.detailRecords.length === 0) {
        Row() {
          Text('这天没有饮食记录')
            .fontSize(13)
            .fontColor(COLOR_TEXT_SUB)
        }
        .width('100%')
        .padding({ top: 4 })
      } else {
        Divider().color(COLOR_DIVIDER)

        ForEach(MEAL_ORDER, (meal: MealType) => {
          if (DailyService.recordsOf(this.detailRecords, meal).length > 0) {
            Column({ space: 4 }) {
              Text(mealTypeLabel(meal))
                .fontSize(12)
                .fontColor(COLOR_TEXT_SUB)
                .width('100%')

              ForEach(DailyService.recordsOf(this.detailRecords, meal), (r: FoodRecord) => {
                Row() {
                  Text(r.name)
                    .fontSize(14)
                    .fontColor(COLOR_TEXT)
                    .layoutWeight(1)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  Text(`${r.grams}g`)
                    .fontSize(12)
                    .fontColor(COLOR_TEXT_SUB)
                    .margin({ right: 8 })
                  Text(`${r.kcal} 千卡`)
                    .fontSize(13)
                    .fontColor(COLOR_TEXT)
                }
                .width('100%')
              }, (r: FoodRecord) => r.id)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
        }, (meal: MealType) => `m-${meal}`)
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(COLOR_CARD)
    .borderRadius(RADIUS)
  }

  @Builder
  miniStat(label: string, value: string) {
    Column({ space: 2 }) {
      Text(value)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_TEXT)
      Text(label)
        .fontSize(11)
        .fontColor(COLOR_TEXT_SUB)
    }
    .layoutWeight(1)
  }

  @Builder
  exerciseCard() {
    Column({ space: 10 }) {
      Row() {
        Text('运动')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_TEXT)
        Blank()
        Button({ type: ButtonType.Capsule }) {
          Text('+ 记录').fontSize(13).fontColor(COLOR_PRIMARY)
        }
        .height(30)
        .backgroundColor('#FFF3EC')
        .onClick(() => {
          this.pickExercise();
        })
      }
      .width('100%')

      if (this.exercises.length === 0) {
        Text('这天没有运动记录')
          .fontSize(13)
          .fontColor(COLOR_TEXT_SUB)
          .width('100%')
      } else {
        ForEach(this.exercises, (e: ExerciseRecord) => {
          Row() {
            Column({ space: 3 }) {
              Text(e.name)
                .fontSize(14)
                .fontColor(COLOR_TEXT)
              Text(`${timeLabel(e.timestamp)} · ${e.minutes > 0 ? `${e.minutes} 分钟` : '未记时长'}`)
                .fontSize(11)
                .fontColor(COLOR_TEXT_SUB)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Text(`${e.kcal} 千卡`)
              .fontSize(14)
              .fontColor(COLOR_OK)

            Button({ type: ButtonType.Circle }) {
              Text('✕').fontSize(12).fontColor(COLOR_TEXT_SUB)
            }
            .width(26).height(26).backgroundColor(COLOR_DIVIDER)
            .margin({ left: 10 })
            .onClick(() => {
              ExerciseRepo.remove(e.dayKey, e.id);
              this.exercises = ExerciseRepo.loadDay(this.selectedDay);
              this.detail = DailyService.summaryOf(this.selectedDay);
              this.cells = this.buildCells();
            })
          }
          .width('100%')
        }, (e: ExerciseRecord) => e.id)
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(COLOR_CARD)
    .borderRadius(RADIUS)
  }

  @Builder
  weightCard() {
    Column({ space: 12 }) {
      WeightChart({ records: this.weights })

      Row({ space: 10 }) {
        TextInput({ text: this.weightInput, placeholder: '输入体重（公斤）' })
          .type(InputType.NUMBER_DECIMAL)
          .height(42)
          .layoutWeight(1)
          .backgroundColor(COLOR_BG)
          .borderRadius(10)
          .onChange((v: string) => {
            this.weightInput = v;
          })

        Button({ type: ButtonType.Capsule }) {
          Text('记录').fontSize(14).fontColor(Color.White)
        }
        .height(42)
        .backgroundColor(COLOR_PRIMARY)
        .onClick(() => {
          this.saveWeight();
        })
      }
      .width('100%')

      Text(`记录到 ${this.selectedDay}`)
        .fontSize(11)
        .fontColor(COLOR_TEXT_SUB)
        .width('100%')
    }
    .width('100%')
  }
}
