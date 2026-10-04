/**
 * 三大营养素：进度条滑动。
 *
 * 显示当日摄入量相对「推荐量」的完成度。推荐量由每日总消耗按
 * 碳水 50% / 蛋白质 30% / 脂肪 20% 的热量占比反推克数得到
 * （见 Enums.macroTargetFor），所以换个人、换个目标都会自动跟着变。
 *
 * 只给条形做连续动画，数字直接显示真实值——三条数字同时滚容易看花。
 *
 * ── 数字为什么需要 ForEach 键里带 frame ──
 * 数字是 Text(`${item.grams}`)，items() 每次 build 现读 props，
 * 看起来应该更新；但 ForEach 的键若与数值无关（如 `${index}-${label}`），
 * ArkUI 会直接复用子组件、跳过重建，数字就永远停在首帧的值。
 * 键里编入每帧递增的 frame 可强制重建（条能动是因为它的宽度来自
 * @State animPct，是另一条独立的更新路径）。
 */
import {
  CARD_SHADOW, COLOR_CARB, COLOR_CARD, COLOR_DIVIDER, COLOR_FAT,
  COLOR_PROTEIN, COLOR_TEXT, COLOR_TEXT_SUB, DUR_SLOW, RADIUS
} from '../common/Theme';

/** 单项数据 */
class MacroItem {
  label: string;
  grams: number;
  target: number;
  color: string;

  constructor(label: string, grams: number, target: number, color: string) {
    this.label = label;
    this.grams = grams;
    this.target = target;
    this.color = color;
  }

  /** 完成度百分比，封顶 100 以免条形溢出容器 */
  percent(): number {
    if (this.target <= 0) {
      return 0;
    }
    const p: number = this.grams / this.target * 100;
    return Math.max(0, Math.min(100, p));
  }
}

/** 每帧推进条形宽度 */
class MacroTicker {
  /** 当前显示的百分比 */
  shownPct: number = 0;

  private timer: number = -1;
  private fromP: number = 0;
  private toP: number = 0;
  private startedAt: number = 0;
  private duration: number = 420;

  stop(): void {
    if (this.timer !== -1) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  /** 停掉动画并立即落到目标值 */
  snap(pct: number): void {
    this.stop();
    this.shownPct = pct;
  }

  /**
   * 平滑推进到目标百分比。
   *
   * @param apply 每帧回调，让调用方把值写进 @State 触发重建
   */
  to(pct: number, apply: () => void, duration: number = 420): void {
    if (Math.abs(pct - this.shownPct) < 0.05) {
      this.snap(pct);
      apply();
      return;
    }
    this.stop();
    this.fromP = this.shownPct;
    this.toP = pct;
    this.startedAt = Date.now();
    this.duration = duration;

    this.timer = setInterval(() => {
      const t: number = this.duration <= 0 ? 1 : Math.min(1, (Date.now() - this.startedAt) / this.duration);
      // easeOutCubic：起步快、收尾缓，与应用其它动效节奏一致
      const eased: number = 1 - Math.pow(1 - t, 3);
      this.shownPct = this.fromP + (this.toP - this.fromP) * eased;
      apply();
      if (t >= 1) {
        this.snap(pct);
        apply();
      }
    }, 16);
  }
}

@Component
export struct MacroBar {
  // 加 @Watch 是为了在数据变化时推动动画。
  // 注意监测的是「克数」而不是算出来的百分比：两者同步变化，
  // 但克数是入参本身，@Watch 一定能收到。
  @Prop @Watch('onDataChange') protein: number = 0;
  @Prop @Watch('onDataChange') fat: number = 0;
  @Prop @Watch('onDataChange') carb: number = 0;
  /** 三大营养素的推荐克数，由调用方按当日预算算好后传入 */
  @Prop carbTarget: number = 0;
  @Prop proteinTarget: number = 0;
  @Prop fatTarget: number = 0;

  /**
   * 每帧递增的版本号。
   *
   * @State 数组本身在动画期间一直被改，但为了让「数字」也跟着重建，
   * 这里额外用一个计数器：build 里读它，就能保证整块内容每帧重算一次。
   */
  @State frame: number = 0;

  private tickers: MacroTicker[] = [new MacroTicker(), new MacroTicker(), new MacroTicker()];

  aboutToAppear(): void {
    // 首帧直接落位，避免一进页面三根条从 0 长出来
    this.snapAll();
  }

  aboutToDisappear(): void {
    // 定时器必须在销毁时停掉，否则回调会打到已销毁的实例上
    for (const t of this.tickers) {
      t.stop();
    }
  }

  /** 数据变化：把三根条平滑推到新比例 */
  onDataChange(): void {
    const list: MacroItem[] = this.items();
    for (let i = 0; i < list.length; i++) {
      this.tickers[i].to(list[i].percent(), () => {
        this.frame++;
      }, DUR_SLOW);
    }
  }

  /** 不做动画，直接落位 */
  private snapAll(): void {
    const list: MacroItem[] = this.items();
    for (let i = 0; i < list.length; i++) {
      this.tickers[i].snap(list[i].percent());
    }
  }

  private items(): MacroItem[] {
    return [
      new MacroItem('碳水', this.carb, this.carbTarget, COLOR_CARB),
      new MacroItem('蛋白质', this.protein, this.proteinTarget, COLOR_PROTEIN),
      new MacroItem('脂肪', this.fat, this.fatTarget, COLOR_FAT)
    ];
  }

  /** 第 i 项当前应显示的条形宽度百分比 */
  private pctAt(i: number): number {
    return i < this.tickers.length ? this.tickers[i].shownPct : 0;
  }

  build() {
    Column({ space: 12 }) {
      ForEach(this.items(), (item: MacroItem, index: number) => {
        Column({ space: 5 }) {
          Row() {
            Text(item.label)
              .fontSize(13)
              .fontColor(COLOR_TEXT_SUB)
            Blank()
            // 摄入 / 推荐。数字直接显示真实值，不做滚动动效——
            // 三条数字同时滚容易看花，这里只保留条的连续变化。
            // 注意：数字能更新靠的是下面 ForEach 键里编入了 frame，
            // 所以即使不插值，它也会随数据立刻刷新。
            Text(`${item.grams} / ${item.target} g`)
              .fontSize(12)
              .fontColor(COLOR_TEXT)
          }
          .width('100%')

          /*
           * 条形：外层浅灰底，内层按完成度着色。
           *
           * 宽度交给外层 Row 撑满，Stack 只负责把两层条子叠在一起。
           * 注意这里绝不能在 Stack 上写 layoutWeight：
           * Stack 的父级是 Column（纵向），layoutWeight 会被解释成
           * **纵向**扩张，把每一项都拉到整张卡片那么高
           * （实测过：卡片被撑满屏、条形漂到屏幕中间）。
           */
          Row() {
            Stack({ alignContent: Alignment.Start }) {
              Row()
                .width('100%')
                .height(8)
                .backgroundColor(COLOR_DIVIDER)
                .borderRadius(4)

              Row()
                .width(`${this.pctAt(index)}%`)
                .height(8)
                .backgroundColor(item.color)
                .borderRadius(4)
            }
            .width('100%')
            .height(8)
          }
          .width('100%')
          .height(8)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        /*
         * 键里带上 frame：ArkUI 的 ForEach 在键不变时会直接复用子组件、
         * 跳过重建。原来的键是 `${index}-${label}`，和数值无关，
         * 于是数字永远停在首帧的值（条能动是因为它的宽度来自另一条路径）。
         * 把每帧递增的 frame 编进键里，就能强制每帧重建。
         */
      }, (item: MacroItem, index: number) => `${index}-${this.frame}-${item.label}`)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(COLOR_CARD)
    .borderRadius(RADIUS)
    .shadow(CARD_SHADOW)
  }
}
