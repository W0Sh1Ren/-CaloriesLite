/**
 * 会滚动的数字。
 *
 * 做法：维护一个 0→1 的进度状态，用 animateTo 把它从 0 推到 1；
 * 同一帧里按「起始值 + 进度 × 差值」渲染整数文本。
 * ArkUI 会为每一帧重算 build，于是数字看起来就是滚上去的。
 *
 * 为什么不用位移动画：把新旧两条文本上下平移，在位数变化（比如 99→100）
 * 时宽度跳变会很明显。逐帧改文本没有这个问题，位数变化也自然。
 *
 * 重播动画靠 @Watch 监听 value，**不要**改用 onDidUpdate：
 * 实测 onDidUpdate 在「父组件只换了数据对象」时不一定触发，
 * 结果就是数字卡在旧值不动（切换日期后环里的缺口一直显示当天那个数）。
 */
import { CURVE_COUNT, DUR_SLOW } from '../common/Theme';

@Component
export struct RollingNumber {
  /** 目标数值 */
  @Prop @Watch('onValueChange') value: number = 0;
  /**
   * 外部刷新键：父组件每次重读数据都换一个新值。
   *
   * 单靠 @Prop 的 @Watch 已经够用，加这一层是因为「只改数据、不改引用」
   * 的场景下 @Watch 也可能收不到通知；刷新键是显式信号，最稳。
   */
  @Prop @Watch('onValueChange') refreshKey: number = 0;
  @Prop fontSize: number = 48;
  @Prop fontWeight: FontWeight = FontWeight.Bold;
  @Prop textColor: string = '#1A1A1A';
  @Prop duration: number = DUR_SLOW;

  /** 动画进度 0→1 */
  @State progress: number = 1;
  /** 本次滚动的起始值 */
  @State fromValue: number = 0;
  /** 已经滚到的目标值，用来判断是否需要重新起动画 */
  @State settled: number = 0;
  /** 首帧不播动画 */
  private initialized: boolean = false;

  aboutToAppear(): void {
    this.settled = this.value;
    this.fromValue = this.value;
    this.progress = 1;
    this.initialized = true;
  }

  /** value 或 refreshKey 变化时重播滚动动画 */
  onValueChange(): void {
    if (!this.initialized || this.value === this.settled) {
      return;
    }
    // 从「当前显示到哪」接着滚，而不是从上一段动画的起点重来，
    // 这样连续快速变化也不会跳
    this.fromValue = this.fromValue + (this.settled - this.fromValue) * this.progress;
    this.settled = this.value;
    this.progress = 0;
    this.getUIContext().animateTo({
      duration: this.duration,
      curve: CURVE_COUNT
    }, () => {
      this.progress = 1;
    });
  }

  /** 当前这一帧应该显示的值 */
  private display(): number {
    const v: number = this.fromValue + (this.settled - this.fromValue) * this.progress;
    return Math.round(v);
  }

  build() {
    Text(`${this.display()}`)
      .fontSize(this.fontSize)
      .fontWeight(this.fontWeight)
      .fontColor(this.textColor)
  }
}
