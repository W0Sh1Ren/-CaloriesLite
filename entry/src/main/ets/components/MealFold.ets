/**
 * 餐次卡片的明细区（可折叠内容）。「展开动画 2.0」的容器实现。
 *
 * ── 结构照抄已验证可用的 profileCard（「我的 → 个人情况」）
 * 明细用 `if (expanded)` **条件渲染**：展开那一刻才挂载，
 * onAreaChange 立刻量到它的自然高度，写进 measuredH 后进入动画阶段。
 *
 * 为什么不能「内容一直挂着」：外层高度是 0，内层在高度 0 的容器里
 * 量不到自然高度，展开后就是一片空白（踩过）。
 *
 * ── 与 profileCard 的差别：高度状态在这里，而不是父页面
 * 父页面有四个餐次共用一份状态时，会出现
 * 「折叠 B 把 A 也裁了」「展开长度由最后量的那张决定」等问题。
 * 组件实例天然隔离，不需要 key，也不会互相污染。
 *
 * ── 动效
 * 高度即时变化 + 透明度用 animateTo 插值，动效来自透明度。
 * 不用高度动画（.height() 从占位值跳到实测值那一帧不可插值，没有中间帧），
 * 也不用 transition（挂在会卸载的节点上会与下方控件重叠）。
 * 详见 docs/展开动画2.0.md。
 */

/**
 * 未量到高度之前的占位值（vp）。
 *
 * 必须足够大：它是第一帧渲染明细时用的高度，测量就在这个高度下发生，
 * 给小了会把内容截断，量到的偏小值写回去长度就永远不够
 *（早期用 400，表现是超过 5 道菜只显示 5 道、第 5 道还被裁）。
 * 给大只会多渲染一帧空白（内容被 clip 住，看不到），没有副作用。
 */
const MEASURE_PLACEHOLDER_H: number = 2000;

@Component
export struct MealFold {
  /**
   * 是否展开。用 @Prop（单向）而**不是 @Link**：展开状态由父组件持有，这里只读。
   *
   * 踩过的坑：写成 @Link 时父组件传的是 `this.isExpanded(meal)` ——
   * 方法返回值不是状态变量，而 @Link 要求父组件用 $ 绑定状态变量，
   * 运行期直接抛 "source variable in parent/ancestor @Component must be defined"，
   * 应用一启动就闪退（编译期不报错，很隐蔽）。
   */
  @Prop expanded: boolean = false;

  /** 展开时的透明度目标，由父组件在同一个 animateTo 里一起设，动效才同步。只读。 */
  @Prop alpha: number = 0;

  /** 明细内容 */
  @BuilderParam content: () => void;

  /** 实测的明细高度（vp） */
  @State measuredH: number = MEASURE_PLACEHOLDER_H;

  /** 是否已量到过高度；量到前不加 clip，避免把测量的内容裁掉 */
  @State measured: boolean = false;

  /**
   * 容器当前应有的高度。
   *
   * **始终返回数字**，不返回 undefined：
   * 高度从「未设置」跳到某个值的那一帧没有可插值的起点，不会有动画。
   */
  private targetH(): number {
    if (!this.measured) {
      // 还没量到：展开时先给占位高度把内容渲染出来（外面不裁切，看不到）
      return this.expanded ? MEASURE_PLACEHOLDER_H : 0;
    }
    return this.expanded ? this.measuredH : 0;
  }

  build() {
    Column() {
      if (this.expanded) {
        Column() {
          this.content()
        }
        .width('100%')
        // 展开时量一次自然高度，供收起动画用
        .onAreaChange((oldValue: Area, newValue: Area) => {
          const h: number = Number.parseFloat(`${newValue.height}`);
          if (Number.isNaN(h) || h <= 0.5) {
            return;
          }
          if (this.measured && Math.abs(h - this.measuredH) < 0.5) {
            return;
          }
          this.measuredH = h;
          this.measured = true;
        })
      }
    }
    .width('100%')
    .height(this.targetH())
    // 量到之后才裁切：测量那一帧不裁，否则内容会被占位高度之外的裁切吃掉
    .clip(this.measured)
    .opacity(this.expanded ? this.alpha : 0)
  }
}
