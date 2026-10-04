/**
 * 会滚动的数字。
 *
 * 做法：维护一个 0→1 的进度状态，用 animateTo 把它从 0 推到 1；
 * 同一帧里按「起始值 + 进度 × 差值」渲染整数文本。
 * ArkUI 会为每一帧重算 build，于是数字看起来就是滚上去的。
 *
 * 为什么不用位移动画：把新旧两条文本上下平移，在位数变化（比如 99→100）
 * 时宽度跳变会很明显。逐帧改文本没有这个问题，位数变化也自然。
 */
import { CURVE_COUNT, DUR_SLOW } from '../common/Theme';

@Component
export struct RollingNumber {
  /** 目标数值 */
  @Prop value: number = 0;
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

  onDidUpdate(): void {
    if (!this.initialized || this.value === this.settled) {
      return;
    }
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
