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
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { MealType, FoodRecord, ExerciseRecord } from '../model/Types';
import { MEAL_ORDER, mealTypeLabel } from '../model/Enums';
import { friendlyDate, todayKey, shiftDay, hourOf } from '../common/DateUtil';
import { DailyService, HomeData } from '../service/DailyService';
import { FoodRepo } from '../service/FoodRepo';
import { ImageService } from '../service/ImageService';
import { AppState } from '../common/AppState';
import {
  COLOR_BG, COLOR_CARD, COLOR_DIVIDER, COLOR_PRIMARY, COLOR_PRIMARY_SOFT, COLOR_TEXT, COLOR_TEXT_SUB,
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
  /**
   * 数据刷新计数器。
   *
   * 加 @Watch 是有意为之：increment 时直接把数据重读一遍。
   * 只靠 onPageShow 不够稳——从相机/结果页 router.back() 回来时，
   * 生命周期回调的触发时机取决于页面栈实现，实测出现过
   * 「识别完回到首页，热量和营养素还是旧值，退出重进才更新」。
   * 走 @Watch 就是把「刷新」和「生命周期」解耦，只要计数器变了就一定重读。
   */
  @State @Watch('onRefreshTick') refreshTick: number = 0;
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
  /** 本次切换的方向：1 向右切、-1 向左切，决定入场从哪一侧滑入 */
  @State navDir: number = 1;
  /** 视图入场动画的重放键：每次切换自增，迫使动画重新播放 */
  @State viewAnimKey: number = 0;

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
  /**
   * refreshTick 变化时重读当日数据。
   *
   * 注意 dayKey 也要在这里重新取一次：识别可能跨过零点，
   * 或者页面在后台待了很久，回来时应显示当天而不是离开时那一天。
   */
  onRefreshTick(): void {
    this.reload();
  }

  /** 把 EntryAbility 量好的安全区尺寸取到本地状态，驱动布局重算 */
  private syncInsets(): void {
    this.topInset = AppState.topInset;
    this.bottomInset = AppState.bottomInset;
  }

  /** 按当前下标渲染视图，并播放从切换方向滑入的入场动画 */
  @Builder
  contentView() {
    Column() {
      if (this.activeTab === 0) {
        this.todayView()
      } else if (this.activeTab === 1) {
        HistoryTab({ dayKey: this.dayKey, refreshTick: this.refreshTick })
      } else {
        ProfileTab({ refreshTick: this.refreshTick })
      }
    }
    .width('100%')
    .height('100%')
    // 新视图从切换方向那一侧滑入并淡入；旧视图立即移除，所以不存在
    // 「透明层挡住点击」的问题
    .transition(TransitionEffect.asymmetric(
      TransitionEffect.OPACITY
        .combine(TransitionEffect.translate({ x: this.navDir >= 0 ? 56 : -56 }))
        .animation({ duration: DUR_VIEW_SWITCH, curve: Curve.FastOutSlowIn }),
      TransitionEffect.OPACITY
        .animation({ duration: 120, curve: Curve.EaseIn })
    ))
  }

  /**
   * 把记录里的图片从缓存转存到持久目录。
   *
   * 相机与相册给的 uri 都在临时目录，缓存也可能被系统回收，
   * 直接落库的话过几天图片就丢了。这里在读取记录时顺手转存一份，
   * 并把记录里的 uri 换成持久路径。
   *
   * 注意必须用 update 而不是 addMany：addMany 是纯追加、不按 id 去重，
   * 用它会把当天每条记录都复制一遍。
   */
  /**
   * 图片转存与去重（每次加载只跑一次）。
   *
   * 相机与相册给的 uri 都在临时目录，缓存也可能被系统回收，
   * 直接落库的话过几天图片就丢了，所以要转存到 filesDir。
   *
   * 两个关键点：
   *   1. 整批共用一个 memo（persistAll）。同一餐的多道菜共享同一组照片，
   *      逐条转存会把一张图复制 N 份——实测 2 张照片被复制成 20 个文件，
   *      详情页里图片就会一直重复滚动。
   *   2. 落盘必须用 update 而不是 addMany：后者纯追加、不按 id 去重，
   *      会把当天记录整体复制一遍。
   */
  private persistImages(): void {
    // 先做一次全量收敛：合并内容相同的重复文件并删掉孤立的
    ImageService.dedupeImages(this.data.records, this.uiContext(), (r: FoodRecord) => {
      FoodRepo.update(r);
    });

    for (const r of this.data.records) {
      const list: string[] = r.gallery();
      if (list.length === 0) {
        continue;
      }
      let needs: boolean = false;
      for (const u of list) {
        if (!u.includes('/food_images/')) {
          needs = true;
          break;
        }
      }
      if (!needs) {
        continue;
      }
      const saved: string[] = ImageService.persistAll(list, this.uiContext());
      r.imageUris = saved;
      r.imageUri = saved[0];
      FoodRepo.update(r);
      hilog.info(DOMAIN, 'CalorieLite', 'persisted %{public}d image(s) for %{public}s',
        saved.length, r.id);
    }
  }

  private uiContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private reload(): void {
    this.data = DailyService.homeData(this.dayKey);
    this.persistImages();
  }

  /** 切换视图：改下标并同时刷新数据 */
  private switchTo(index: number): void {
    if (index === this.activeTab) {
      // 已经在这一页：仍然重读一次，避免「点了没反应但数据其实变了」的情况
      if (index === 0) {
        this.dayKey = todayKey();
        this.refreshTick++;
      }
      return;
    }
    // 「我的」页可能刚改过档案，回到首页要按新预算重算
    if (AppState.profileDirty) {
      AppState.profileDirty = false;
      this.reload();
    }
    this.navDir = index > this.activeTab ? 1 : -1;
    this.activeTab = index;
    // 重放入场动画
    this.viewAnimKey++;
    // 回到首页时按当天重读，保证刚记录的餐次立刻出现
    if (index === 0) {
      this.dayKey = todayKey();
      this.refreshTick++;
    }
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
      // 只渲染当前视图，靠入场动画完成切换。
      //
      // 之前试过让三个视图常驻 Stack、用 opacity 切换，结果未激活视图
      // 虽然透明但仍参与命中测试，把下面的按钮点击全吃掉了
      // （实测拍照按钮和餐次折叠都点不动）。条件渲染没有这个问题。
      Column() {
        this.contentView()
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
      .backgroundColor(COLOR_PRIMARY_SOFT)
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
