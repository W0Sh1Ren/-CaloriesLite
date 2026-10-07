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
import { CARD_SHADOW, COLOR_CARD, COLOR_OK, COLOR_PRIMARY, COLOR_PRIMARY_SOFT, COLOR_TEXT, COLOR_TEXT_SUB, DUR_SLOW, GAP, RADIUS, deficitColor, deficitLabel, deficitLabelColor } from '../common/Theme';
import { RollingNumber } from './RollingNumber';
import { CANVAS_PRIMARY_SOFT } from '../common/CanvasColors';

@Component
export struct CalorieRing {
  // ---- 当日数据，全部基本类型 ----
  @Prop @Watch('onDataChange') intake: number = 0;
  @Prop @Watch('onDataChange') budget: number = 0;
  /**
   * 当天总消耗 TDEE（维持体重所需）。
   *
   * 进度弧的分母用它而不是 budget：环要表达「吃进去的占身体实际消耗的多少」，
   * 而 budget 是计划（已减掉要减的部分），拿它当分母会让「吃到目标」看起来
   * 像「环画满了」。详见 ratio() 的说明。
   */
  @Prop @Watch('onDataChange') tdee: number = 0;
  @Prop @Watch('onDataChange') exerciseKcal: number = 0;
  @Prop @Watch('onDataChange') deficit: number = 0;
  /**
   * 计划缺口 = TDEE − 每日目标。
   *
   * 用于给缺口分三档（达标 / 未达标 / 超出）。**必须由父组件传入**，
   * 不在这里拿 tdee − budget 现算：那样要再引一个 prop，
   * 而且这段判定逻辑桌面卡片也要用（见 Theme.deficitColor），
   * 集中在一处才不会两边跑偏。
   */
  @Prop deficitPlanned: number = 0;
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
  /** Canvas 是否已完成布局。未就绪时 ctx.width/height 是 0，画不出别的 */
  private canvasReady: boolean = false;

  /**
   * 弧线的显示比例（0-1）。这个 @State 是动画的驱动源：
   * 每帧写入它会让组件重建，同时下面手动调 draw() 重绘 Canvas。
   */
  @State animRatio: number = 0;
  /** 逐帧动画的定时器句柄，-1 表示没在跑 */
  private animTimer: number = -1;

  aboutToAppear(): void {
    this.animRatio = this.ratio();
  }

  aboutToDisappear(): void {
    // 定时器必须在销毁时停掉，否则回调会打到已销毁的实例上
    this.stopAnim();
  }

  private stopAnim(): void {
    if (this.animTimer !== -1) {
      clearInterval(this.animTimer);
      this.animTimer = -1;
    }
  }

  /**
   * 数据变化时把弧线平滑推到新比例。
   *
   * 为什么自己跑定时器而不用 animateTo：
   * Canvas 里的圆弧是一次性画上去的路径，不在属性动画的插值通道里；
   * 而在 build 里调 draw() 又不允许（build 不能有副作用）。
   * 所以只能每帧同时做两件事：写 @State（触发重建）+ 调 draw()（重绘画布）。
   */
  onDataChange(): void {
    const target: number = this.ratio();
    if (!this.canvasReady) {
      this.animRatio = target;
      return;
    }
    if (Math.abs(target - this.animRatio) < 0.0001) {
      // 比例没变也要重绘一次，保证颜色（超标变红）能更新
      this.draw();
      return;
    }
    this.stopAnim();
    const from: number = this.animRatio;
    const startedAt: number = Date.now();
    const duration: number = DUR_SLOW;
    this.animTimer = setInterval(() => {
      const t: number = Math.min(1, (Date.now() - startedAt) / duration);
      // easeOutCubic：起步快、收尾缓，与应用其它动效节奏一致
      const eased: number = 1 - Math.pow(1 - t, 3);
      this.animRatio = from + (target - from) * eased;
      // 写 @State 会触发重建，但 Canvas 需要显式重画
      this.draw();
      if (t >= 1) {
        this.stopAnim();
      }
    }, 16);
  }

  /**
   * 进度弧的填充比例（0-1），超出按 1 画满。
   *
   * ⚠️ 分母是「总消耗 TDEE + 运动」，**不是每日目标**。
   *
   * 为什么换成 TDEE：环要回答的问题是「我今天吃进去的，占身体实际消耗的多少」。
   * 用每日目标当分母会把这个答案扭曲掉 —— 目标本身是**计划**（已经减掉
   * 要减的那部分），所以「吃到目标」会显示成环刚好画满，看起来像
   * 「今天吃够了/吃满了」，而实际只吃了总消耗的八成多。
   * 换成 TDEE 后：环满 = 吃到收支平衡点，超出才变红，语义一致。
   *
   * 副作用（有意为之）：吃到每日目标时环停在约 85%（减脂场景），
   * 剩下一小截就是「今天还没吃到收支平衡」的余量，和缺口数字互相印证。
   */
  private ratio(): number {
    const capacity: number = this.tdee + this.exerciseKcal;
    if (capacity <= 0) {
      return 0;
    }
    const r: number = this.intake / capacity;
    return Math.min(1, Math.max(0, r));
  }

  /**
   * 进度弧的颜色，三档（判定逻辑见 Theme.deficitColor，与桌面卡片共用）：
   *   绿 达标 / 黄 未达标 / 红 超出
   *
   * 只用「弧色 + 中心数字色」表达状态，不加边框或背景块 ——
   * 环本身就是最强的视觉元素，再加装饰会抢掉它。
   */
  private arcColor(): string {
    return deficitColor(this.deficit, this.deficitPlanned);
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
    ctx.strokeStyle = CANVAS_PRIMARY_SOFT;
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
            this.animRatio = this.ratio();
            this.draw();
          })
        // 环心数字
        Column({ space: 2 }) {
          /*
           * 标题文案跟着档位走：超出 →「超出」，未达标 →「未达标」，
           * 达标 →「热量缺口」。
           *
           * 用 deficitLabel 与卡片共用同一套措辞，避免出现
           * 「首页说达标、卡片说未达标」这种自相矛盾。
           */
          Text(deficitLabel(this.deficit, this.deficitPlanned))
            .fontSize(13)
            // 文案色也走共享逻辑：达标用中性灰，异常档才上彩色
            .fontColor(deficitLabelColor(this.deficit, this.deficitPlanned))

          // 数值变化时滚上去，而不是瞬间跳变
          RollingNumber({
            value: Math.abs(this.deficit),
            refreshKey: this.refreshKey,
            fontSize: 48,
            fontWeight: FontWeight.Bold,
            /*
             * 达标时用深色正文色而不是绿色：绿色已经给了弧线，
             * 数字再上绿色会让「数值」和「状态」两个信息互相稀释。
             * 未达标/超出才给彩色，让异常状态自己跳出来。
             */
            textColor: this.deficit < this.deficitPlanned ? this.arcColor() : COLOR_TEXT(),
            duration: DUR_SLOW
          })

          Text('千卡')
            .fontSize(13)
            .fontColor(COLOR_TEXT_SUB())
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
            textColor: COLOR_PRIMARY(),
            duration: DUR_SLOW
          })
          Text('已摄入')
            .fontSize(12)
            .fontColor(COLOR_TEXT_SUB())
        }
        Divider().vertical(true).height(28).color(COLOR_PRIMARY_SOFT())

        Column({ space: 4 }) {
          RollingNumber({
            value: this.budget,
            refreshKey: this.refreshKey,
            fontSize: 20,
            fontWeight: FontWeight.Medium,
            textColor: COLOR_TEXT(),
            duration: DUR_SLOW
          })
          Text('每日目标')
            .fontSize(12)
            .fontColor(COLOR_TEXT_SUB())
        }
        Divider().vertical(true).height(28).color(COLOR_PRIMARY_SOFT())

        Column({ space: 4 }) {
          RollingNumber({
            value: this.exerciseKcal,
            refreshKey: this.refreshKey,
            fontSize: 20,
            fontWeight: FontWeight.Medium,
            textColor: COLOR_OK(),
            duration: DUR_SLOW
          })
          Text('运动消耗')
            .fontSize(12)
            .fontColor(COLOR_TEXT_SUB())
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceEvenly)
    }
    .width('100%')
    .padding(20)
    .backgroundColor(COLOR_CARD())
    .borderRadius(RADIUS)
    .shadow(CARD_SHADOW)
  }
}
