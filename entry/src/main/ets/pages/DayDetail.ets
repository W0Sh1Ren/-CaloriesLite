/**
 * 每日饮食详情页。
 *
 * 从「记录」页的月历点击某一天进来，按日期展示那天的完整记录。
 *
 * 布局按「餐次」组织，不是按菜品平铺：
 *   顶部  当日汇总（总摄入 + 热量缺口 + 三大营养素）
 *   每餐  标题与餐次热量 → 一个大的图片预览框 → 这一餐的菜品列表
 * 图片挂在餐次上是因为一次识别可能拍多张（主菜、汤、饮料各一张），
 * 逐条菜各配一张图既冗余也对不上号；预览框支持左右滑动切换。
 *
 * 数据按需现读：路由只传日期字符串，进来再查存储
 * （路由参数是无类型 Object，ArkTS 里传复杂结构容易踩坑）。
 */
import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { MealType, FoodRecord, DailySummary } from '../model/Types';
import { MEAL_ORDER, mealTypeLabel } from '../model/Enums';
import { friendlyDate, todayKey, timeLabel } from '../common/DateUtil';
import { DailyService } from '../service/DailyService';
import { FoodRepo } from '../service/FoodRepo';
import { ImageService } from '../service/ImageService';
import { MealGallery } from '../components/MealGallery';
import {
  CARD_SHADOW, COLOR_BG, COLOR_CARD, COLOR_DIVIDER, COLOR_OK, COLOR_PRIMARY,
  COLOR_TEXT, COLOR_TEXT_SUB, COLOR_WARN, GAP, PAGE_PAD, RADIUS
} from '../common/Theme';

const DOMAIN = 0x0000;
/** 餐次预览框高度 */
const FRAME_HEIGHT: number = 190;

@Entry
@Component
struct DayDetail {
  @State dayKey: string = todayKey();
  @State summary: DailySummary = new DailySummary('', 0, 0, 0, 0, 0, 0, 0);
  @State records: FoodRecord[] = [];
  /** 防止同一张图被重复转存 */
  @State persisted: boolean = false;

  aboutToAppear(): void {
    const raw: Object | undefined = router.getParams();
    if (raw !== undefined && raw !== null) {
      const params = raw as Record<string, Object>;
      const d: Object = params['dayKey'];
      if (d !== undefined && d !== null) {
        const s: string = `${d}`;
        if (s.length > 0 && s !== 'undefined') {
          this.dayKey = s;
        }
      }
    }
    this.load();
  }

  onPageShow(): void {
    this.load();
  }

  private load(): void {
    this.summary = DailyService.summaryOf(this.dayKey);
    this.records = FoodRepo.loadDay(this.dayKey);
    this.persistImages();
  }

  /**
   * 图片转存与去重（每次进页面只跑一次）。
   *
   * 相机给的图片在临时目录，缓存也可能被系统回收，所以要转存到 filesDir。
   *
   * 两个关键点：
   *   1. dedupeImages 先把内容完全相同的重复文件合并掉。
   *      早期版本按记录逐条转存，把同一组照片复制了 N 份
   *      （实测 2 张照片变成 20 个文件，预览框里图片一直重复滚动）。
   *   2. 转存用 persistAll 整批共用一个 memo，避免又造出一批重复文件。
   *      落盘用 update 而不是 addMany，后者纯追加不去重。
   */
  private persistImages(): void {
    if (this.persisted) {
      return;
    }
    this.persisted = true;
    const ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;

    ImageService.dedupeImages(this.records, ctx, (r: FoodRecord) => {
      FoodRepo.update(r);
    });

    for (const r of this.records) {
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
      const saved: string[] = ImageService.persistAll(list, ctx);
      r.imageUris = saved;
      r.imageUri = saved[0];
      try {
        FoodRepo.update(r);
      } catch (err) {
        hilog.warn(DOMAIN, 'CalorieLite', 'update record images failed');
      }
    }
  }

  /** 按餐次筛出记录 */
  private ofMeal(meal: MealType): FoodRecord[] {
    const out: FoodRecord[] = [];
    for (const r of this.records) {
      if (r.mealType === meal) {
        out.push(r);
      }
    }
    return out;
  }

  private mealKcal(meal: MealType): number {
    let sum: number = 0;
    for (const r of this.ofMeal(meal)) {
      sum += r.kcal;
    }
    return Math.round(sum);
  }

  /**
   * 汇总一餐的全部图片并去重。
   *
   * 同一餐的每条记录都存了同一组图（识别结果是共享的），
   * 所以这里必须去重，否则 Swiper 里会出现重复的同一张照片。
   */
  private mealImages(meal: MealType): string[] {
    const seen: string[] = [];
    for (const r of this.ofMeal(meal)) {
      for (const u of r.gallery()) {
        if (u.length > 0 && !seen.includes(u)) {
          seen.push(u);
        }
      }
    }
    return seen;
  }

  /**
   * 页面推入/推出的过渡动画。
   *
   * 新页面从右侧滑入，旧页面稍向左让位并淡出；返回时整体反向，
   * 与系统返回手势的视觉方向一致。
   */
  pageTransition(): void {
    PageTransitionEnter({ type: RouteType.Push, duration: 300, curve: Curve.FastOutSlowIn })
      .translate({ x: 80 })
      .opacity(0)

    PageTransitionExit({ type: RouteType.Push, duration: 300, curve: Curve.FastOutSlowIn })
      .translate({ x: -40 })
      .opacity(0)

    PageTransitionEnter({ type: RouteType.Pop, duration: 300, curve: Curve.FastOutSlowIn })
      .translate({ x: -40 })
      .opacity(0)

    PageTransitionExit({ type: RouteType.Pop, duration: 300, curve: Curve.FastOutSlowIn })
      .translate({ x: 80 })
      .opacity(0)
  }

  build() {
    Column() {
      // ------------------------------------------------ 顶栏
      Row() {
        Button({ type: ButtonType.Circle }) {
          Text('‹').fontSize(22).fontColor(COLOR_TEXT)
        }
        .width(36).height(36)
        .backgroundColor(COLOR_CARD)
        .shadow(CARD_SHADOW)
        .onClick(() => {
          router.back();
        })

        Text(friendlyDate(this.dayKey))
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_TEXT)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Row().width(36).height(36)
      }
      .width('100%')
      .padding({ left: PAGE_PAD, right: PAGE_PAD, top: 8, bottom: 8 })

      Scroll() {
        Column({ space: GAP }) {
          this.summaryCard()

          if (this.records.length === 0) {
            this.emptyState()
          } else {
            ForEach(MEAL_ORDER, (meal: MealType) => {
              if (this.ofMeal(meal).length > 0) {
                this.mealSection(meal)
              }
            }, (meal: MealType) => `m-${meal}`)
          }

          Row().height(40)
        }
        .width('100%')
        .padding({ left: PAGE_PAD, right: PAGE_PAD })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BG)
  }

  /** 顶部汇总：总摄入 + 缺口徽标 + 三大营养素 */
  @Builder
  summaryCard() {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 2 }) {
          Text('总摄入')
            .fontSize(12)
            .fontColor(COLOR_TEXT_SUB)
          Row({ space: 4 }) {
            Text(`${this.summary.intake}`)
              .fontSize(30)
              .fontWeight(FontWeight.Bold)
              .fontColor(COLOR_TEXT)
            Text('千卡')
              .fontSize(12)
              .fontColor(COLOR_TEXT_SUB)
              .margin({ bottom: 4 })
          }
          .alignItems(VerticalAlign.Bottom)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(this.summary.deficit < 0
          ? `超出 ${-this.summary.deficit}`
          : `缺口 ${this.summary.deficit}`)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.summary.deficit < 0 ? COLOR_WARN : COLOR_OK)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor(this.summary.deficit < 0 ? '#1AE5533D' : '#1A2FA36B')
          .borderRadius(12)
      }
      .width('100%')

      Text(`预算 ${this.summary.budget} 千卡 · 共 ${this.summary.recordCount} 条记录`)
        .fontSize(11)
        .fontColor(COLOR_TEXT_SUB)
        .width('100%')
      // 这里刻意不放三大营养素：详情页的主角是「这天吃了什么」，
      // 营养素属于首页的当日总览。放在这里会把汇总卡撑得很高，
      // 一进页面先看到一堆进度条、看不到记录列表。
    }
    .width('100%')
    .padding(16)
    .backgroundColor(COLOR_CARD)
    .borderRadius(RADIUS)
    .shadow(CARD_SHADOW)
  }

  /** 一餐：标题 + 图片预览框 + 菜品列表 */
  @Builder
  mealSection(meal: MealType) {
    Column({ space: 10 }) {
      Row() {
        Text(mealTypeLabel(meal))
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_TEXT)
        Blank()
        Text(`${this.mealKcal(meal)} 千卡`)
          .fontSize(13)
          .fontColor(COLOR_TEXT_SUB)
      }
      .width('100%')

      // 整餐共用的大预览框（多图可左右滑动切换）
      MealGallery({
        images: this.mealImages(meal),
        frameHeight: FRAME_HEIGHT
      })

      // 菜品列表：图片已经在上面统一展示了，这里只列菜名与营养
      Column() {
        ForEach(this.ofMeal(meal), (r: FoodRecord, idx: number) => {
          this.dishRow(r, idx > 0)
        }, (r: FoodRecord) => r.id)
      }
      .width('100%')
      .padding({ left: 14, right: 14 })
      .backgroundColor(COLOR_CARD)
      .borderRadius(16)
      .shadow(CARD_SHADOW)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 一道菜：名称 + 克重/营养 + 热量，行间用细分隔线 */
  @Builder
  dishRow(r: FoodRecord, withDivider: boolean) {
    Column() {
      if (withDivider) {
        Divider().color(COLOR_DIVIDER)
      }
      Row({ space: 10 }) {
        Column({ space: 3 }) {
          Text(r.name)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLOR_TEXT)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.dishSubtitle(r))
            .fontSize(11)
            .fontColor(COLOR_TEXT_SUB)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Row({ space: 2 }) {
          Text(`${r.kcal}`)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLOR_PRIMARY)
          Text('千卡')
            .fontSize(10)
            .fontColor(COLOR_TEXT_SUB)
            .margin({ bottom: 2 })
        }
        .alignItems(VerticalAlign.Bottom)
      }
      .width('100%')
      .padding({ top: 12, bottom: 12 })
    }
    .width('100%')
  }

  /** 菜品副标题：克重 + 营养（没有营养数据时退回时间） */
  private dishSubtitle(r: FoodRecord): string {
    const base: string = `${r.grams} g`;
    if (r.protein <= 0 && r.fat <= 0 && r.carb <= 0) {
      return `${base} · ${timeLabel(r.timestamp)}`;
    }
    return `${base} · 蛋白 ${r.protein} · 脂肪 ${r.fat} · 碳水 ${r.carb}`;
  }

  /** 空状态 */
  @Builder
  emptyState() {
    Column({ space: 12 }) {
      Text('🍚')
        .fontSize(52)
      Text('这天还没有饮食记录哦')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_TEXT)
      Text('回到首页拍照识别，或在「记录」页用「补记」手动添加')
        .fontSize(12)
        .fontColor(COLOR_TEXT_SUB)
        .textAlign(TextAlign.Center)
      Button({ type: ButtonType.Capsule }) {
        Text('去补记一笔').fontSize(14).fontColor(Color.White)
      }
      .height(40)
      .backgroundColor(COLOR_PRIMARY)
      .margin({ top: 4 })
      .onClick(() => {
        router.pushUrl({ url: 'pages/ManualAdd' });
      })
    }
    .width('100%')
    .padding({ top: 44, bottom: 44, left: 24, right: 24 })
    .backgroundColor(COLOR_CARD)
    .borderRadius(RADIUS)
    .shadow(CARD_SHADOW)
    .justifyContent(FlexAlign.Center)
  }
}
