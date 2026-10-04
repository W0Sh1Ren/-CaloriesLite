/**
 * 「记录」标签页：月历热力 + 当日明细 + 体重趋势 + 运动录入。
 */
import { promptAction, router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { DayCell, CalendarHeatmap } from '../components/CalendarHeatmap';
import { WeightChart } from '../components/WeightChart';
import { RollingNumber } from '../components/RollingNumber';
import { topReserve } from '../components/GlassTopBar';
import { MealType, FoodRecord, WeightRecord, ExerciseRecord, DailySummary } from '../model/Types';
import { MEAL_ORDER, mealTypeLabel } from '../model/Enums';
import { buildMonthGrid, friendlyDate, fromDayKey, todayKey, timeLabel } from '../common/DateUtil';
import { makeId } from '../common/JsonUtil';
import { AppState } from '../common/AppState';
import { DailyService } from '../service/DailyService';
import { FoodRepo } from '../service/FoodRepo';
import { BodyRepo } from '../service/BodyRepo';
import { ExerciseRepo } from '../service/ExerciseRepo';
import { calcExerciseKcal, MET_TABLE, MetItem } from '../service/CalorieCalc';
import {
  CARD_SHADOW, COLOR_BG, COLOR_CARD, COLOR_DIVIDER, COLOR_OK, COLOR_PRIMARY,
  COLOR_PRIMARY_SOFT, COLOR_TEXT, COLOR_TEXT_SUB, COLOR_WARN, DUR_SLOW, GAP, INPUT_PLACEHOLDER, INPUT_TEXT, NAV_RESERVE, PAGE_PAD, RADIUS
} from '../common/Theme';

const DOMAIN = 0x0000;

@Component
export struct HistoryTab {
  /** 主页面当前选中的日期 */
  @Prop dayKey: string = todayKey();
  /**
   * 主页面自增的刷新信号。
   *
   * **必须挂 @Watch**：三页用 Swiper 常驻之后，切页不再重建组件，
   * 原先靠「切回来时 aboutToAppear 重读」这条路失效了。
   * 触发不了重读的表现就是「别处改完体重/档案，回到这页还是旧数据」
   *（实测反馈「体重记录不能实时显示」）。
   */
  @Prop @Watch('onRefreshTick') refreshTick: number = 0;

  /**
   * 父组件要求重读数据。
   *
   * 两类触发要区分开：
   *   1. 主页面真的翻了日期 → 日历要跟过去
   *   2. 从二级页返回 / 别的页面写了记录 → 只重读数据，**不能动日历视口**
   * 靠 syncToMainDay() 里的 lastSyncedDay 判断，见该方法注释。
   */
  onRefreshTick(): void {
    this.syncToMainDay();
    this.bottomInset = AppState.bottomInset;
    this.rebuild();
  }

  /** 月历当前显示的月份 */
  @State viewYear: number = 0;
  @State viewMonth0: number = 0;
  @State selectedDay: string = '';
  @State cells: DayCell[] = [];
  /**
   * 换月动画的触发键，方向编码在键里：`n<序号>` 下个月 / `p<序号>` 上个月。
   *
   * 不用「序号 + 单独的方向字段」：两个 Prop 同帧更新时，
   * @Watch 回调读另一个 Prop 可能拿到上一帧的值，
   * 表现就是「连续点下月、再点上月，方向还是下月，要多点一次才对」。
   * 方向与触发同源才可靠。
   */
  @State monthAnimKey: string = '';
  /** 触发键里的序号，保证每次换月的键都不同（同方向连点也能重播） */
  @State monthSeq: number = 0;
  @State detail: DailySummary = new DailySummary('', 0, 0, 0, 0, 0, 0, 0);
  @State detailRecords: FoodRecord[] = [];
  @State weights: WeightRecord[] = [];
  /** 体重数据的版本号：每次写入自增，驱动折线图重绘（onDidUpdate 不总触发） */
  @State weightsVersion: number = 0;
  @State exercises: ExerciseRecord[] = [];
  @State weightInput: string = '';
  /** 底部安全区高度，由 EntryAbility 实测后写入 AppState */
  @State bottomInset: number = 0;
  /**
   * 上一次从主页面同步过来的日期。
   *
   * 用来区分「主页面真的翻了日期」与「只是子页面返回触发了刷新」：
   * 后者不能重置日历视口，否则从详情页返回时会被拉回主页面日期所在的月份
   *（实测反馈：翻到非本月、点进去再返回，回到了当前月）。
   */
  @State lastSyncedDay: string = '';

  aboutToAppear(): void {
    const now = new Date();
    this.viewYear = now.getFullYear();
    this.viewMonth0 = now.getMonth();
    this.selectedDay = this.dayKey;
    this.lastSyncedDay = this.dayKey;
    this.bottomInset = AppState.bottomInset;
    this.rebuild();
  }

  /** 主页面翻日期或恢复前台时同步过来 */
  onDidUpdate(): void {
    this.bottomInset = AppState.bottomInset;
    this.syncToMainDay();
    this.rebuild();
  }

  /**
   * 跟随主页面的选中日期。
   *
   * 只在**主页面日期真的变了**时才动日历视口。
   * 从二级页返回也会触发刷新，但那时 dayKey 没变，
   * 不能把用户自己翻到的月份重置掉。
   */
  private syncToMainDay(): void {
    if (this.dayKey.length === 0 || this.dayKey === this.lastSyncedDay) {
      return;
    }
    this.lastSyncedDay = this.dayKey;
    this.selectedDay = this.dayKey;
    const d = new Date(fromDayKey(this.dayKey));
    this.viewYear = d.getFullYear();
    this.viewMonth0 = d.getMonth();
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
    /*
     * 换月动画：方向编码进触发键（n = 下个月 / p = 上个月），
     * 一个 Prop 同时携带「要播动画」和「往哪边」两条信息。
     */
    this.monthSeq++;
    this.monthAnimKey = `${delta >= 0 ? 'n' : 'p'}${this.monthSeq}`;
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
    // 换新数组而不是原地改：@Prop 只比较引用，
    // 引用不变时子组件不会重建，Canvas 也就不会重绘
    this.weights = BodyRepo.recent(60).slice();
    // 显式自增版本号：Canvas 是自绘的，只换数组引用不保证重绘
    this.weightsVersion++;
    // 体重会影响预算（TDEE 按体重算），推给全局让首页一起更新
    AppState.mirrorToday(DailyService.summaryOf(this.selectedDay));
    AppState.notifyDataChanged();
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
      Column({ space: 14 }) {
        // ------------------------------------------------ 月份切换
        // 收成一行次级控件（原来是个 26pt 大标题，和毛玻璃顶栏的
        // 「记录」重复，一条屏幕上出现两个同级标题）。
        Row({ space: 8 }) {
          Text(`${this.viewYear}年${this.viewMonth0 + 1}月`)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLOR_TEXT)
            .layoutWeight(1)

          Button({ type: ButtonType.Circle }) {
            Text('‹').fontSize(18).fontColor(COLOR_TEXT)
          }
          .width(32).height(32)
          .backgroundColor(COLOR_CARD)
          .shadow(CARD_SHADOW)
          .onClick(() => {
            this.shiftMonth(-1);
          })

          Button({ type: ButtonType.Circle }) {
            Text('›').fontSize(18).fontColor(COLOR_TEXT)
          }
          .width(32).height(32)
          .backgroundColor(COLOR_CARD)
          .shadow(CARD_SHADOW)
          .onClick(() => {
            this.shiftMonth(1);
          })
        }
        .width('100%')
        .padding({ left: 4, right: 4, top: 4, bottom: 2 })

        // ------------------------------------------------ 月历
        // 点击有记录的日期直接进当日详情页（那里能看照片和完整营养明细）
        CalendarHeatmap({
          cells: this.cells,
          selectedDay: this.selectedDay,
          animKey: this.monthAnimKey,
          // 左右滑也能换月，走同一条 shiftMonth 链路（含动画与数据重算）
          onSwipeMonth: (delta: number) => {
            this.shiftMonth(delta);
          },
          onSelectDay: (day: string) => {
            this.selectedDay = day;
            this.rebuild();
            this.openDayDetail(day);
          }
        })

        // ------------------------------------------------ 当日结算
        this.dayDetailCard()

        // ------------------------------------------------ 体重
        this.weightCard()

        // 底部占位：悬浮导航栏浮在内容之上，没有这段留白的话
        // 体重输入框和按钮会被压在导航栏下面点不到。
        // 用实测的 bottomInset（手势条高度）再加导航栏自身高度和一点余量。
        Row().height(this.bottomInset + NAV_RESERVE + 12)
      }
      .width('100%')
      // 顶部留出毛玻璃顶栏的高度，避免月份行被压住
      .padding({ left: PAGE_PAD, right: PAGE_PAD, top: topReserve() + 4 })
    }
    .width('100%')
    .height('100%')
    // 背景交给外层 Stack 的柔光层，这里保持透明让毛玻璃顶栏能透出内容
    .backgroundColor(Color.Transparent)
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

        // 缺口做成强调徽标：这是这一天最该一眼看到的信息。
        // 数字走滚动动效：图标与文字都在变，数字直接跳会很突兀。
        Row({ space: 2 }) {
          Text(this.detail.deficit < 0 ? '超出' : '缺口')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.detail.deficit < 0 ? COLOR_WARN : COLOR_OK)
          RollingNumber({
            value: Math.abs(this.detail.deficit),
            fontSize: 14,
            fontWeight: FontWeight.Medium,
            textColor: this.detail.deficit < 0 ? COLOR_WARN : COLOR_OK,
            duration: DUR_SLOW
          })
        }
        .padding({ left: 10, right: 10, top: 4, bottom: 4 })
        .backgroundColor(this.detail.deficit < 0 ? '#1AE5533D' : '#1A2FA36B')
        .borderRadius(10)
      }
      .width('100%')

      // 三项指标：之间加竖分隔线，比纯留白更容易读
      Row() {
        this.miniStat('摄入', () => this.detail.intake)
        Divider().vertical(true).height(26).color(COLOR_DIVIDER)
        this.miniStat('预算', () => this.detail.budget)
        Divider().vertical(true).height(26).color(COLOR_DIVIDER)
        this.miniStat('运动', () => this.detail.exerciseKcal)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceEvenly)

      if (this.detailRecords.length === 0) {
        Row({ space: 8 }) {
          Text('这天没有饮食记录')
            .fontSize(13)
            .fontColor(COLOR_TEXT_SUB)
            .layoutWeight(1)

          // 没有记录时把补记入口放在这里，指向更明确
          /*
           * 显式给宽度：ButtonType.Capsule 的宽度在 Row 里由内容决定，
           * 不给宽就会紧贴文字边缘，看着像背景和文字重叠（实测反馈）。
           * 高度 30 配 fontSize 12，宽度按文字量给足两侧留白。
           */
          Button({ type: ButtonType.Capsule }) {
            Text('+ 补记一笔').fontSize(12).fontColor(COLOR_PRIMARY)
          }
          .width(104)
          .height(30)
          .backgroundColor(COLOR_PRIMARY_SOFT)
          .onClick(() => {
            this.goManualAdd();
          })
        }
        .width('100%')
        .padding({ top: 2 })
      } else {
        Divider().color(COLOR_DIVIDER)

        ForEach(MEAL_ORDER, (meal: MealType) => {
          if (DailyService.recordsOf(this.detailRecords, meal).length > 0) {
            Column({ space: 6 }) {
              Text(mealTypeLabel(meal))
                .fontSize(12)
                .fontColor(COLOR_TEXT_SUB)
                .width('100%')

              ForEach(DailyService.recordsOf(this.detailRecords, meal), (r: FoodRecord) => {
                Row({ space: 8 }) {
                  Text(r.name)
                    .fontSize(14)
                    .fontColor(COLOR_TEXT)
                    .layoutWeight(1)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })

                  Text(`${r.grams}g`)
                    .fontSize(12)
                    .fontColor(COLOR_TEXT_SUB)

                  Text(`${r.kcal}`)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(COLOR_TEXT)
                    .width(42)
                    .textAlign(TextAlign.End)

                  Text('千卡')
                    .fontSize(11)
                    .fontColor(COLOR_TEXT_SUB)
                }
                .width('100%')
              }, (r: FoodRecord) => r.id)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
        }, (meal: MealType) => `m-${meal}`)

        // 有记录时补记入口放到底部，不打断阅读
        Row() {
          // 同样显式给宽，避免背景紧贴文字（见上面「补记一笔」的说明）
          Button({ type: ButtonType.Capsule }) {
            Text('+ 补记').fontSize(12).fontColor(COLOR_PRIMARY)
          }
          .width(84)
          .height(30)
          .backgroundColor(COLOR_PRIMARY_SOFT)
          .onClick(() => {
            this.goManualAdd();
          })
        }
        .width('100%')
        .justifyContent(FlexAlign.End)
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(COLOR_CARD)
    .borderRadius(RADIUS)
    .shadow(CARD_SHADOW)
  }

  /** 跳转手动补记页 */
  private goManualAdd(): void {
    try {
      router.pushUrl({ url: 'pages/ManualAdd' });
    } catch (err) {
      hilog.error(DOMAIN, 'CalorieLite', 'goManualAdd failed');
    }
  }

  /** 进入某一天的饮食详情页 */
  private openDayDetail(day: string): void {
    try {
      router.pushUrl({
        url: 'pages/DayDetail',
        params: { dayKey: day }
      });
    } catch (err) {
      hilog.error(DOMAIN, 'CalorieLite', 'openDayDetail failed');
    }
  }
  /**
   * 一项指标，数字带滚动动效。
   *
   * value 用取值函数而不是直接传值：@Builder 的参数在容器构建时求值一次，
   * 之后状态变化不会重新求值，传值会表现为「切换日期后数字不动」。
   */
  @Builder
  miniStat(label: string, value: () => number) {
    Column({ space: 2 }) {
      RollingNumber({
        value: value(),
        fontSize: 18,
        fontWeight: FontWeight.Medium,
        textColor: COLOR_TEXT,
        duration: DUR_SLOW
      })
      Text(label)
        .fontSize(11)
        .fontColor(COLOR_TEXT_SUB)
    }
    .layoutWeight(1)
  }

  /**
   * 体重趋势 + 输入。
   *
   * 间距压到 10：这两块本来就属于同一件事，之前 12 的间距加上卡片外边距
   * 让页面显得松散。
   */
  @Builder
  weightCard() {
    Column({ space: 10 }) {
      WeightChart({ records: this.weights, refreshKey: this.weightsVersion })

      Row({ space: 10 }) {
        TextInput({ text: this.weightInput, placeholder: '输入体重（公斤）' })
          .type(InputType.NUMBER_DECIMAL)
          .height(42)
          .layoutWeight(1)
          .fontColor(INPUT_TEXT)
          .placeholderColor(INPUT_PLACEHOLDER)
          .backgroundColor(COLOR_BG)
          .borderRadius(10)
          .onChange((v: string) => {
            this.weightInput = v;
          })

        // 输入框是圆角 10 的矩形，按钮也用矩形 + 同样的圆角才成一组
        Button({ type: ButtonType.Normal }) {
          Text('记录').fontSize(14).fontColor(Color.White)
        }
        .width(84)
        .height(42)
        .backgroundColor(COLOR_PRIMARY)
        .borderRadius(10)
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
    .padding(16)
    .backgroundColor(COLOR_CARD)
    .borderRadius(RADIUS)
    .shadow(CARD_SHADOW)
  }
}
