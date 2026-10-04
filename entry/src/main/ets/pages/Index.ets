/**
 * 轻卡记 —— 主页面。
 *
 * 三个标签页：今天 / 记录 / 我的。
 * 「今天」是核心：一个热量环讲清今天的收支，下面是四餐明细。
 */
import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { MealType, FoodRecord, ExerciseRecord } from '../model/Types';
import { MEAL_ORDER, mealTypeLabel } from '../model/Enums';
import { friendlyDate, todayKey, shiftDay } from '../common/DateUtil';
import { DailyService, HomeData } from '../service/DailyService';
import { FoodRepo } from '../service/FoodRepo';
import { AppState } from '../common/AppState';
import { COLOR_BG, COLOR_CARD, COLOR_DIVIDER, COLOR_PRIMARY, COLOR_TEXT, COLOR_TEXT_SUB, GAP, PAGE_PAD, RADIUS } from '../common/Theme';
import { CalorieRing } from '../components/CalorieRing';
import { MacroBar } from '../components/MacroBar';
import { RecordRow } from '../components/RecordRow';
import { HistoryTab } from './HistoryTab';
import { ProfileTab } from './ProfileTab';

const DOMAIN = 0x0000;

@Entry
@Component
struct Index {
  @State dayKey: string = todayKey();
  @State data: HomeData = new HomeData();
  /** 当前标签页。名字不能叫 tabIndex：ArkUI 的 CustomComponent 已有同名属性 */
  @State activeTab: number = 0;
  /** 每次从子页面返回自增，驱动子 Tab 刷新 */
  @State refreshTick: number = 0;

  private controller: TabsController = new TabsController();

  aboutToAppear(): void {
    this.reload();
  }

  /** 页面从后台或子页面返回时刷新 */
  onPageShow(): void {
    if (AppState.needRefreshHome) {
      AppState.needRefreshHome = false;
      this.dayKey = todayKey();
      this.reload();
      this.activeTab = 0;
      this.controller.changeIndex(0);
    } else {
      this.reload();
    }
  }

  private reload(): void {
    this.data = DailyService.homeData(this.dayKey);
  }

  /** 计算某餐的热量合计 */
  private mealKcal(records: FoodRecord[]): number {
    let sum: number = 0;
    for (const r of records) {
      sum += r.kcal;
    }
    return Math.round(sum);
  }

  /** 删除一条记录，删前确认 */
  private async confirmDelete(record: FoodRecord): Promise<void> {
    try {
      const result = await promptAction.showDialog({
        title: '删除记录',
        message: `确定删除「${record.name}」吗？`,
        buttons: [
          { text: '取消', color: COLOR_TEXT_SUB },
          { text: '删除', color: '#E5533D' }
        ]
      });
      if (result.index === 1) {
        FoodRepo.remove(record.dayKey, record.id);
        this.reload();
        this.refreshTick++;
      }
    } catch (err) {
      hilog.error(DOMAIN, 'CalorieLite', 'delete dialog failed: %{public}s', JSON.stringify(err));
    }
  }

  /** 切到前一天 / 后一天 */
  private shiftDate(delta: number): void {
    const next: string = shiftDay(this.dayKey, delta);
    // 不允许翻到未来
    if (next > todayKey()) {
      return;
    }
    this.dayKey = next;
    this.reload();
  }

  build() {
    Tabs({ barPosition: BarPosition.End, controller: this.controller }) {
      // ------------------------------------------------ 今天
      TabContent() {
        this.todayTab()
      }
      .tabBar(this.tabItem('今天', 0))

      // ------------------------------------------------ 记录
      TabContent() {
        HistoryTab({ dayKey: this.dayKey, refreshTick: this.refreshTick })
      }
      .tabBar(this.tabItem('记录', 1))

      // ------------------------------------------------ 我的
      TabContent() {
        ProfileTab({ refreshTick: this.refreshTick })
      }
      .tabBar(this.tabItem('我的', 2))
    }
    .barHeight(56)
    .barBackgroundColor(COLOR_CARD)
    .backgroundColor(COLOR_BG)
    .scrollable(false)
    .onChange((index: number) => {
      this.activeTab = index;
      // 从相机页回来可能改了数据，切标签时统一刷新
      this.reload();
    })
  }

  @Builder
  tabItem(label: string, index: number) {
    Column({ space: 2 }) {
      Text(label)
        .fontSize(14)
        .fontWeight(this.activeTab === index ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.activeTab === index ? COLOR_PRIMARY : COLOR_TEXT_SUB)
      // 选中下划线
      Row()
        .width(this.activeTab === index ? 18 : 0)
        .height(2)
        .backgroundColor(COLOR_PRIMARY)
        .borderRadius(1)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  // ================================================== 今天
  @Builder
  todayTab() {
    Column() {
      // 顶部：日期切换
      Row() {
        Button({ type: ButtonType.Circle }) {
          Text('‹').fontSize(22).fontColor(COLOR_TEXT)
        }
        .width(36)
        .height(36)
        .backgroundColor(COLOR_CARD)
        .onClick(() => {
          this.shiftDate(-1);
        })

        Column({ space: 2 }) {
          Text(this.dayKey === todayKey() ? '今天' : friendlyDate(this.dayKey))
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLOR_TEXT)
          Text(friendlyDate(this.dayKey))
            .fontSize(12)
            .fontColor(COLOR_TEXT_SUB)
        }
        .layoutWeight(1)

        Button({ type: ButtonType.Circle }) {
          Text('›')
            .fontSize(22)
            .fontColor(this.dayKey === todayKey() ? COLOR_DIVIDER : COLOR_TEXT)
        }
        .width(36)
        .height(36)
        .backgroundColor(COLOR_CARD)
        .enabled(this.dayKey !== todayKey())
        .onClick(() => {
          this.shiftDate(1);
        })
      }
      .width('100%')
      .padding({ left: PAGE_PAD, right: PAGE_PAD, top: 8, bottom: 8 })

      Scroll() {
        Column({ space: GAP }) {
          // 热量环
          CalorieRing({ summary: this.data.summary })

          // 结算评语
          Row() {
            Text(DailyService.verdict(this.data.summary))
              .fontSize(13)
              .fontColor(COLOR_TEXT_SUB)
              .layoutWeight(1)
          }
          .width('100%')
          .padding({ left: 4, right: 4 })

          // 连续达标
          if (this.data.streak > 0) {
            Row({ space: 6 }) {
              Text('连续达标')
                .fontSize(13)
                .fontColor(COLOR_TEXT_SUB)
              Text(`${this.data.streak} 天`)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(COLOR_PRIMARY)
            }
            .width('100%')
            .padding({ left: 4, right: 4 })
          }

          // 营养素
          if (this.data.summary.recordCount > 0) {
            MacroBar({
              protein: this.data.summary.protein,
              fat: this.data.summary.fat,
              carb: this.data.summary.carb
            })
          }

          // 四餐明细
          ForEach(MEAL_ORDER, (meal: MealType) => {
            this.mealSection(meal)
          }, (meal: MealType) => `${meal}-${this.data.summary.recordCount}`)

          // 运动记录入口
          this.exerciseSection()

          // 底部留白，避免被 tab 栏遮住
          Row().height(16)
        }
        .width('100%')
        .padding({ left: PAGE_PAD, right: PAGE_PAD, bottom: 16 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)

      // 底部主操作：拍照识别
      this.cameraBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BG)
  }

  @Builder
  mealSection(meal: MealType) {
    Column({ space: 8 }) {
      Row() {
        Text(mealTypeLabel(meal))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_TEXT)
        Blank()
        Text(this.mealKcal(DailyService.recordsOf(this.data.records, meal)) > 0
          ? `${this.mealKcal(DailyService.recordsOf(this.data.records, meal))} 千卡`
          : '')
          .fontSize(13)
          .fontColor(COLOR_TEXT_SUB)
      }
      .width('100%')
      .padding({ left: 4, right: 4 })

      if (DailyService.recordsOf(this.data.records, meal).length === 0) {
        Row() {
          Text('还没有记录')
            .fontSize(13)
            .fontColor(COLOR_TEXT_SUB)
        }
        .width('100%')
        .padding(14)
        .backgroundColor(COLOR_CARD)
        .borderRadius(RADIUS)
      } else {
        ForEach(DailyService.recordsOf(this.data.records, meal), (record: FoodRecord) => {
          RecordRow({
            record: record,
            onDelete: (id: string) => {
              const target: FoodRecord | undefined =
                this.data.records.find((r: FoodRecord) => r.id === id);
              if (target !== undefined) {
                this.confirmDelete(target);
              }
            }
          })
        }, (record: FoodRecord) => record.id)
      }
    }
    .width('100%')
  }

  @Builder
  exerciseSection() {
    Column({ space: 8 }) {
      Row() {
        Text('运动消耗')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_TEXT)
        Blank()
        if (this.data.summary.exerciseKcal > 0) {
          Text(`${this.data.summary.exerciseKcal} 千卡`)
            .fontSize(13)
            .fontColor(COLOR_TEXT_SUB)
        }
      }
      .width('100%')
      .padding({ left: 4, right: 4 })

      if (this.data.exercises.length === 0) {
        Row() {
          Text('没有运动记录')
            .fontSize(13)
            .fontColor(COLOR_TEXT_SUB)
        }
        .width('100%')
        .padding(14)
        .backgroundColor(COLOR_CARD)
        .borderRadius(RADIUS)
      } else {
        ForEach(this.data.exercises, (item: ExerciseRecord) => {
          Row({ space: 10 }) {
            Column({ space: 3 }) {
              Text(item.name)
                .fontSize(15)
                .fontColor(COLOR_TEXT)
              Text(item.minutes > 0 ? `${item.minutes} 分钟` : '未记录时长')
                .fontSize(12)
                .fontColor(COLOR_TEXT_SUB)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Text(`${item.kcal} 千卡`)
              .fontSize(15)
              .fontColor(COLOR_TEXT)
          }
          .width('100%')
          .padding(14)
          .backgroundColor(COLOR_CARD)
          .borderRadius(RADIUS)
        }, (item: ExerciseRecord) => item.id)
      }
    }
    .width('100%')
  }

  @Builder
  cameraBar() {
    Row({ space: 10 }) {
      Button({ type: ButtonType.Capsule }) {
        Text('拍照识别热量')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
      }
      .layoutWeight(1)
      .height(48)
      .backgroundColor(COLOR_PRIMARY)
      .onClick(() => {
        this.goCamera();
      })

      Button({ type: ButtonType.Capsule }) {
        Text('手动')
          .fontSize(15)
          .fontColor(COLOR_TEXT)
      }
      .height(48)
      .backgroundColor(COLOR_CARD)
      .onClick(() => {
        this.goManual();
      })
    }
    .width('100%')
    .padding({ left: PAGE_PAD, right: PAGE_PAD, top: 8, bottom: 8 })
    .backgroundColor(COLOR_BG)
  }

  private goCamera(): void {
    try {
      router.pushUrl({ url: 'pages/Camera' });
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, 'CalorieLite', 'goCamera failed: %{public}s', e.message);
    }
  }

  private goManual(): void {
    try {
      router.pushUrl({ url: 'pages/ManualAdd' });
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, 'CalorieLite', 'goManual failed: %{public}s', e.message);
    }
  }
}
