/**
 * 首页核心：热量收支环。
 *
 * 用 Canvas 手绘两个同心圆弧（底环 + 进度弧），而不是 ArkUI 的 Progress 组件：
 * Progress 在 Ring 模式下不会把自身尺寸撑开给父 Stack，实测会被压扁成几十像素高，
 * 环只露出一小段。自绘既确定又可控。
 *
 * 环内显示当天的热量缺口，环下方列预算 / 摄入 / 运动三项。
 *
 * 注意入参刻意全部用**基本类型数字**，而不是整个 DailySummary 对象：
 * 实测传类实例时 @Prop 在父组件换数据后不更新——切日期后环里永远是当天的数，
 * 而同一份数据用基本类型传的 MacroBar 却是正常的。
 * 另外数字也不要经 @Builder 参数传（@Builder 的参数只求值一次），直接内联。
 */
import { AnimatedValue, CARD_SHADOW, COLOR_CARD, COLOR_OK, COLOR_PRIMARY, COLOR_PRIMARY_SOFT, COLOR_TEXT, COLOR_TEXT_SUB, COLOR_WARN, DUR_SLOW, GAP, RADIUS } from '../common/Theme';
import { RollingNumber } from './RollingNumber';

@Component
export struct CalorieRing {
  // ---- 当日数据，全部基本类型 ----
  @Prop @Watch('onDataChange') intake: number = 0;
  @Prop @Watch('onDataChange') budget: number = 0;
  @Prop @Watch('onDataChange') exerciseKcal: number = 0;
  @Prop @Watch('onDataChange') deficit: number = 0;
  /**
   * 外部刷新键：父组件每次重读数据都换一个新值。
   *
   * 数字本身变化时 @Watch 已经会触发；加这一层是为了覆盖
   * 「两个日期数值恰好相同」或「只换引用不改数值」的场景。
   */
  @Prop @Watch('onDataChange') refreshKey: number = 0;
  /** 环外径（vp） */
  @Prop diameter: number = 210;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  /** Canvas 是否已完成布局。未就绪时 ctx.width/height 是 0，画不出东西 */
  private canvasReady: boolean = false;

  /**
   * 弧线的动画比例。
   *
   * 不直接用 ratio() 画：那样数据一变弧线会瞬移。
   * 这里由 AnimatedValue 逐帧把显示比例推向目标比例，
   * 每帧写回 animRatio 触发重建，Canvas 在重建里按新比例重绘。
   */
  @State animRatio: number = 0;
  private arcValue: AnimatedValue = new AnimatedValue();

  /**
   * 数据变化时：推动弧线动画，并在动画过程中持续重绘。
   *
   * Canvas 的内容不是声明式的，onReady 只在首次布局时触发一次，
   * 之后数据变了没人再调 draw()，弧线就会停在旧位置。
   */
  onDataChange(): void {
    if (!this.canvasReady) {
      return;
    }
    this.arcValue.animate(this, () => this.ratio(), (v: number) => {
      this.animRatio = v;
      // 每帧重绘：@State 写入会触发重建，但 Canvas 需要显式重画
      this.draw();
    });
    // 比例没变时也要重绘一次，保证颜色（超标变红）能跟着更新
    this.draw();
  }

  /** 已摄入占「预算 + 运动」的比例（0-1），超出按 1 画满 */
  private ratio(): number {
    const capacity: number = this.budget + this.exerciseKcal;
    if (capacity <= 0) {
      return 0;
    }
    const r: number = this.intake / capacity;
    return Math.min(1, Math.max(0, r));
  }

  /** 超标时进度弧变红 */
  private arcColor(): string {
    return this.deficit < 0 ? COLOR_WARN : COLOR_PRIMARY;
  }

  /** 按当前数据重绘 */
  private draw(): void {
    const ctx = this.ctx;
    const w: number = ctx.width;
    const h: number = ctx.height;
    ctx.clearRect(0, 0, w, h);
    if (w <= 0 || h <= 0) {
      return;
    }

    const stroke: number = 14;
    const radius: number = Math.min(w, h) / 2 - stroke / 2;
    const cx: number = w / 2;
    const cy: number = h / 2;

    // 底环：整圈浅色
    ctx.beginPath();
    ctx.strokeStyle = COLOR_PRIMARY_SOFT;
    ctx.lineWidth = stroke;
    ctx.lineCap = 'round';
    ctx.arc(cx, cy, radius, 0, Math.PI * 2);
    ctx.stroke();

    // 进度弧：从 12 点方向顺时针。用动画比例而不是目标比例，弧线才会连续增长
    const r: number = this.animRatio;
    if (r > 0) {
      const start: number = -Math.PI / 2;
      const end: number = start + Math.PI * 2 * r;
      ctx.beginPath();
      ctx.strokeStyle = this.arcColor();
      ctx.lineWidth = stroke;
      ctx.lineCap = 'round';
      ctx.arc(cx, cy, radius, start, end);
      ctx.stroke();
    }
  }

  build() {
    Column({ space: GAP }) {
      Stack() {
        // 自绘圆环
        Canvas(this.ctx)
          .width(this.diameter)
          .height(this.diameter)
          .onReady(() => {
            // onReady 时才能拿到真实绘制尺寸
            this.canvasReady = true;
            // 首个值直接落位，避免页面一打开弧线从 0 长出来
            this.arcValue.animate(this, () => this.ratio(), (v: number) => {
              this.animRatio = v;
              this.draw();
            });
            this.draw();
          })

        // 环心数字
        Column({ space: 2 }) {
          Text(this.deficit < 0 ? '超出' : '热量缺口')
            .fontSize(13)
            .fontColor(COLOR_TEXT_SUB)

          // 数值变化时滚上去，而不是瞬间跳变
          RollingNumber({
            value: Math.abs(this.deficit),
            refreshKey: this.refreshKey,
            fontSize: 48,
            fontWeight: FontWeight.Bold,
            textColor: this.deficit < 0 ? COLOR_WARN : COLOR_TEXT,
            duration: DUR_SLOW
          })

          Text('千卡')
            .fontSize(13)
            .fontColor(COLOR_TEXT_SUB)
        }
        .alignItems(HorizontalAlign.Center)
      }
      .width(this.diameter)
      .height(this.diameter)

      /*
       * 预算与摄入明细。
       *
       * 三个数字直接内联，不走 @Builder 参数：
       * @Builder 的入参只在容器构建时求值一次，之后数据变了不会重新求值，
       * 表现就是「切换日期后这三项一直显示当天那一组」（实测踩过两次）。
       */
      Row() {
        Column({ space: 4 }) {
          RollingNumber({
            value: this.intake,
            refreshKey: this.refreshKey,
            fontSize: 20,
            fontWeight: FontWeight.Medium,
            textColor: COLOR_PRIMARY,
            duration: DUR_SLOW
          })
          Text('已摄入')
            .fontSize(12)
            .fontColor(COLOR_TEXT_SUB)
        }
        Divider().vertical(true).height(28).color(COLOR_PRIMARY_SOFT)

        Column({ space: 4 }) {
          RollingNumber({
            value: this.budget,
            refreshKey: this.refreshKey,
            fontSize: 20,
            fontWeight: FontWeight.Medium,
            textColor: COLOR_TEXT,
            duration: DUR_SLOW
          })
          Text('基础预算')
            .fontSize(12)
            .fontColor(COLOR_TEXT_SUB)
        }
        Divider().vertical(true).height(28).color(COLOR_PRIMARY_SOFT)

        Column({ space: 4 }) {
          RollingNumber({
            value: this.exerciseKcal,
            refreshKey: this.refreshKey,
            fontSize: 20,
            fontWeight: FontWeight.Medium,
            textColor: COLOR_OK,
            duration: DUR_SLOW
          })
          Text('运动消耗')
            .fontSize(12)
            .fontColor(COLOR_TEXT_SUB)
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceEvenly)
    }
    .width('100%')
    .padding(20)
    .backgroundColor(COLOR_CARD)
    .borderRadius(RADIUS)
    .shadow(CARD_SHADOW)
  }
}
