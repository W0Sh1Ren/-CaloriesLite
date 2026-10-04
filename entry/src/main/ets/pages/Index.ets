/**
 * 轻卡记 —— 主页面。
 *
 * 结构：Stack 分三层，从下往上依次是
 *   1. 顶部柔光层（沉浸光感的来源，颜色随时段变化）
 *   2. 内容层（三个视图按选中项切换，带淡入位移动画）
 *   3. 悬浮导航栏（毛玻璃胶囊，浮在内容之上）
 *
 * 没有用 Tabs 组件：Tabs 的 tabBar 贴底且做不出毛玻璃悬浮效果，
 * 自己搭反而更好控制动画与层次。
 */
import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { MealType, FoodRecord, ExerciseRecord } from '../model/Types';
import { MEAL_ORDER, mealTypeLabel } from '../model/Enums';
import { friendlyDate, todayKey, shiftDay, hourOf } from '../common/DateUtil';
import { DailyService, HomeData } from '../service/DailyService';
import { FoodRepo } from '../service/FoodRepo';
import { AppState } from '../common/AppState';
import {
  COLOR_BG, COLOR_CARD, COLOR_DIVIDER, COLOR_PRIMARY, COLOR_TEXT, COLOR_TEXT_SUB,
  CARD_SHADOW, CURVE_BOUNCE, DUR_NORMAL, DUR_VIEW_SWITCH, GAP, GlowPalette, NAV_MARGIN,
  NAV_RESERVE, PAGE_PAD, RADIUS, VIEW_INACTIVE_SCALE, VIEW_SLIDE_X, glowForHour
} from '../common/Theme';
import { CalorieRing } from '../components/CalorieRing';
import { MacroBar } from '../components/MacroBar';
import { RecordRow } from '../components/RecordRow';
import { FloatingNav, NavItem } from '../components/FloatingNav';
import { HistoryTab } from './HistoryTab';
import { ProfileTab } from './ProfileTab';

const DOMAIN = 0x0000;

/** 三个导航项 */
const NAV_ITEMS: NavItem[] = [
  new NavItem('首页', '◉'),
  new NavItem('记录', '▤'),
  new NavItem('我的', '☰')
];

@Entry
@Component
struct Index {
  @State dayKey: string = todayKey();
  @State data: HomeData = new HomeData();
  /** 当前视图下标。名字不能叫 tabIndex：ArkUI 的 CustomComponent 已有同名属性 */
  @State activeTab: number = 0;
  /** 每次从子页面返回自增，驱动子视图重新读数据 */
  @State refreshTick: number = 0;
  /** 顶部柔光配色，按当前时段取 */
  @State glow: GlowPalette = glowForHour(hourOf(Date.now()));
  /** 悬浮导航栏实测宽度，用于算高亮胶囊位置 */
  @State navWidth: number = 0;
  /** 顶部安全区（状态栏）高度，全屏布局后需要自行避让 */
  @State topInset: number = 0;
  /** 底部安全区（手势条）高度，导航栏必须抬到它之上才能点到 */
  @State bottomInset: number = 0;
  /** 已展开明细的餐次。默认为空即全部收起 */
  @State expandedMeals: MealType[] = [];

  aboutToAppear(): void {
    this.syncInsets();
    this.reload();
  }

  /** 从子页面返回或回到前台时刷新。
   *
   * refreshTick 必须自增：ProfileTab / HistoryTab 靠它触发 onDidUpdate 重新读配置，
   * 否则从 AI 配置页保存后返回，「我的」页仍会显示未配置。 */
  onPageShow(): void {
    this.glow = glowForHour(hourOf(Date.now()));
    // 安全区是窗口异步量出来的，首次渲染时可能还是 0，回到前台再取一次
    this.syncInsets();
    if (AppState.needRefreshHome) {
      AppState.needRefreshHome = false;
      this.dayKey = todayKey();
      this.switchTo(0);
    }
    this.reload();
    this.refreshTick++;
  }
  /** 把 EntryAbility 量好的安全区尺寸取到本地状态，驱动布局重算 */
  private syncInsets(): void {
    this.topInset = AppState.topInset;
    this.bottomInset = AppState.bottomInset;
  }

  private reload(): void {
    this.data = DailyService.homeData(this.dayKey);
  }

  /** 切换视图：改下标并同时刷新数据 */
  private switchTo(index: number): void {
    // 「我的」页可能刚改过档案，回到首页要按新预算重算
    if (AppState.profileDirty) {
      AppState.profileDirty = false;
      this.reload();
    }
    this.activeTab = index;
  }

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

  private shiftDate(delta: number): void {
    const next: string = shiftDay(this.dayKey, delta);
    if (next > todayKey()) {
      return;
    }
    this.dayKey = next;
    this.reload();
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // ---------------------------------------------------- 1. 柔光背景
      // 铺满整屏（含状态栏区域），这才是「沉浸」的前提
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [[this.glow.from, 0.0], [this.glow.to, 0.42], [COLOR_BG, 1.0]]
        })

      // ---------------------------------------------------- 2. 内容层
      // 三个视图都常驻在 Stack 里，靠属性动画做切换过渡。
      // 不用 if/else 是因为那会销毁并重建视图，过渡动画会被打断。
      // 未选中的视图缩到 0.94 并移出屏幕，同时屏蔽命中测试。
      Stack() {
        Column() {
          this.todayView()
        }
        .width('100%')
        .height('100%')
        .opacity(this.activeTab === 0 ? 1 : 0)
        .translate({ x: this.activeTab === 0 ? 0 : (this.activeTab > 0 ? -VIEW_SLIDE_X : VIEW_SLIDE_X) })
        .scale({ x: this.activeTab === 0 ? 1 : VIEW_INACTIVE_SCALE, y: this.activeTab === 0 ? 1 : VIEW_INACTIVE_SCALE })
        .hitTestBehavior(this.activeTab === 0 ? HitTestMode.Default : HitTestMode.None)
        .animation({ duration: DUR_VIEW_SWITCH, curve: CURVE_BOUNCE })

        Column() {
          HistoryTab({ dayKey: this.dayKey, refreshTick: this.refreshTick })
        }
        .width('100%')
        .height('100%')
        .opacity(this.activeTab === 1 ? 1 : 0)
        .translate({ x: this.activeTab === 1 ? 0 : (this.activeTab > 1 ? -VIEW_SLIDE_X : VIEW_SLIDE_X) })
        .scale({ x: this.activeTab === 1 ? 1 : VIEW_INACTIVE_SCALE, y: this.activeTab === 1 ? 1 : VIEW_INACTIVE_SCALE })
        .hitTestBehavior(this.activeTab === 1 ? HitTestMode.Default : HitTestMode.None)
        .animation({ duration: DUR_VIEW_SWITCH, curve: CURVE_BOUNCE })

        Column() {
          ProfileTab({ refreshTick: this.refreshTick })
        }
        .width('100%')
        .height('100%')
        .opacity(this.activeTab === 2 ? 1 : 0)
        .translate({ x: this.activeTab === 2 ? 0 : (this.activeTab > 2 ? -VIEW_SLIDE_X : VIEW_SLIDE_X) })
        .scale({ x: this.activeTab === 2 ? 1 : VIEW_INACTIVE_SCALE, y: this.activeTab === 2 ? 1 : VIEW_INACTIVE_SCALE })
        .hitTestBehavior(this.activeTab === 2 ? HitTestMode.Default : HitTestMode.None)
        .animation({ duration: DUR_VIEW_SWITCH, curve: CURVE_BOUNCE })
      }
      .width('100%')
      .height('100%')
      .padding({ top: this.topInset })
      .clip(true)

      // ---------------------------------------------------- 3. 悬浮导航栏
      // 关键：bottom 里必须加上 bottomInset。
      // 底部手势条区域会吃掉点击，导航栏压在上面就会「点了没反应」。
      Column() {
        FloatingNav({
          items: NAV_ITEMS,
          activeIndex: this.activeTab,
          barWidth: this.navWidth,
          onSelect: (index: number) => {
            this.switchTo(index);
          }
        })
          .onAreaChange((oldValue: Area, newValue: Area) => {
            this.navWidth = Number.parseFloat(`${newValue.width}`);
          })
      }
      .width('100%')
      .height('100%')
      // 底部再让出手势条：实测根节点下沿离屏幕底还有约 63px，
      // 不留这一截，导航栏的圆角指示器会贴到屏幕边缘被视觉裁切
      .padding({ left: NAV_MARGIN, right: NAV_MARGIN, bottom: this.bottomInset + NAV_MARGIN + 18 })
      .justifyContent(FlexAlign.End)
      // 整层只是定位容器：自己不响应点击，也不拦截，事件留给下面的导航栏与内容
      .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .height('100%')
    // 让背景铺到状态栏和手势区下面。不加这句，根节点会被安全区限制在
    // [0,137] 起，顶部柔光就永远铺不到屏幕顶端（实测确认过）。
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .backgroundColor(COLOR_BG)
  }

  // ================================================== 首页
  @Builder
  todayView() {
    Column() {
      this.dateBar()

      Scroll() {
        Column({ space: GAP }) {
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

          Row({ space: 14 }) {
            if (this.data.streak > 0) {
              this.chip(`连续达标 ${this.data.streak} 天`)
            }
            if (this.data.summary.exerciseKcal > 0) {
              this.chip(`运动 +${this.data.summary.exerciseKcal}`)
            }
          }
          .width('100%')
          .padding({ left: 4, right: 4 })

          if (this.data.summary.recordCount > 0) {
            MacroBar({
              protein: this.data.summary.protein,
              fat: this.data.summary.fat,
              carb: this.data.summary.carb
            })
          }

          ForEach(MEAL_ORDER, (meal: MealType) => {
            this.mealSection(meal)
          }, (meal: MealType) => `${meal}-${this.data.summary.recordCount}`)

          this.exerciseSection()

          // 给悬浮导航栏留出空间
          Row().height(NAV_RESERVE)
        }
        .width('100%')
        .padding({ left: PAGE_PAD, right: PAGE_PAD, top: 4 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)

      // 底部主操作只剩拍照识别
      this.cameraBar()
    }
    .width('100%')
    .height('100%')
  }

  /** 日期切换条 */
  @Builder
  dateBar() {
    Row() {
      Button({ type: ButtonType.Circle }) {
        Text('‹').fontSize(20).fontColor(COLOR_TEXT)
      }
      .width(36)
      .height(36)
      .backgroundColor(COLOR_CARD)
      .shadow(CARD_SHADOW)
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
          .fontSize(20)
          .fontColor(this.dayKey === todayKey() ? COLOR_DIVIDER : COLOR_TEXT)
      }
      .width(36)
      .height(36)
      .backgroundColor(COLOR_CARD)
      .shadow(CARD_SHADOW)
      .enabled(this.dayKey !== todayKey())
      .opacity(this.dayKey === todayKey() ? 0.5 : 1)
      .onClick(() => {
        this.shiftDate(1);
      })
    }
    .width('100%')
    .padding({ left: PAGE_PAD, right: PAGE_PAD, top: 10, bottom: 10 })
  }

  /** 一个小标签 */
  @Builder
  chip(text: string) {
    Text(text)
      .fontSize(12)
      .fontColor(COLOR_PRIMARY)
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .backgroundColor('#1AFF7A45')
      .borderRadius(12)
  }

  /** 展开/收起某一餐 */
  private toggleMeal(meal: MealType): void {
    const next: MealType[] = [];
    let removed: boolean = false;
    for (const m of this.expandedMeals) {
      if (m === meal) {
        removed = true;
      } else {
        next.push(m);
      }
    }
    if (!removed) {
      next.push(meal);
    }
    this.expandedMeals = next;
  }

  private isExpanded(meal: MealType): boolean {
    return this.expandedMeals.includes(meal);
  }

  /**
   * 一餐的分组。
   *
   * 默认收起，只显示餐次名与合计热量；点标题才展开逐条明细。
   * 刚记完一餐时列表会一下子变很长，收起是更好的默认状态。
   */
  @Builder
  mealSection(meal: MealType) {
    Column({ space: 8 }) {
      // 标题行：整行可点，右侧箭头随展开状态旋转
      Row({ space: 6 }) {
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

        Text('⌄')
          .fontSize(14)
          .fontColor(COLOR_TEXT_SUB)
          .rotate({ angle: this.isExpanded(meal) ? 180 : 0 })
          .animation({ duration: DUR_NORMAL, curve: Curve.EaseInOut })
      }
      .width('100%')
      .padding({ left: 4, right: 4, top: 4, bottom: 4 })
      .onClick(() => {
        this.toggleMeal(meal);
      })

      if (this.isExpanded(meal)) {
        Column({ space: 8 }) {
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
            .shadow(CARD_SHADOW)
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
        // 展开/收起都走同一个过渡，收起时自动反向播放
        .transition(TransitionEffect.OPACITY
          .combine(TransitionEffect.scale({ x: 1, y: 0.94, centerY: '0%' }))
          .animation({ duration: DUR_NORMAL, curve: Curve.EaseOut }))
      } else if (DailyService.recordsOf(this.data.records, meal).length > 0) {
        // 收起态给一行摘要，避免完全看不到吃了什么
        Row() {
          Text(this.mealSummary(meal))
            .fontSize(12)
            .fontColor(COLOR_TEXT_SUB)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .padding({ left: 4, right: 4, bottom: 2 })
      }
    }
    .width('100%')
  }

  /** 收起态的一行摘要，例如「白米饭、番茄炒蛋」 */
  private mealSummary(meal: MealType): string {
    const list: FoodRecord[] = DailyService.recordsOf(this.data.records, meal);
    const names: string[] = [];
    for (const r of list) {
      names.push(r.name);
      if (names.length >= 4) {
        break;
      }
    }
    return names.length < list.length ? `${names.join('、')} 等 ${list.length} 项` : names.join('、');
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
        .shadow(CARD_SHADOW)
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
          .shadow(CARD_SHADOW)
        }, (item: ExerciseRecord) => item.id)
      }
    }
    .width('100%')
  }

  /** 底部唯一的操作入口：拍照识别 */
  @Builder
  cameraBar() {
    Row() {
      Button({ type: ButtonType.Capsule }) {
        Text('拍照识别热量')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
      }
      .width('100%')
      .height(50)
      .backgroundColor(COLOR_PRIMARY)
      .shadow(CARD_SHADOW)
      .onClick(() => {
        try {
          router.pushUrl({ url: 'pages/Camera' });
        } catch (err) {
          const e: BusinessError = err as BusinessError;
          hilog.error(DOMAIN, 'CalorieLite', 'goCamera failed: %{public}s', e.message);
        }
      })
    }
    .width('100%')
    // 这是固定底栏，必须整体抬到悬浮导航栏之上，否则会被导航栏压住。
    // 让出的高度 = 导航栏高度 + 两个间距 + 一点额外余量。
    .padding({ left: PAGE_PAD, right: PAGE_PAD, top: 8, bottom: NAV_RESERVE + 12 })
  }
}
