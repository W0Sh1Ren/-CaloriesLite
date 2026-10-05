/**
 * 餐次卡片的明细区（可折叠内容）。「展开动画 3.0」的容器实现。
 *
 * ══════════════════════════════════════════════════════════════
 * 【核心：高度用算术算出来，不做任何测量】
 * ══════════════════════════════════════════════════════════════
 * 每条记录卡片（RecordRow）的结构是固定的，所以高度是常量；
 * 明细区高度 = 上下内边距 + 条数 × 单条高度 + (条数-1) × 间距。
 * 见 mealDetailHeight()。
 *
 * 这样就不存在「先渲染再量、量到才撑开」那一步 ——
 * 高度在渲染之前就已经确定，**第一次展开也不会闪**。
 *
 * 为什么之前一直失败：一直在想办法「测量」内容高度，
 * 而在这个结构下（收起态外层高度 0 + clip）根本量不到，
 * 试过 visibility / opacity / 不裁切 / 父页面存高度，全部行不通。
 * 换成算术之后问题消失 —— 因为压根不需要测量。
 *
 * ⚠️ 代价：RECORD_ROW_H 等常量必须与 RecordRow.ets 的实际尺寸保持一致。
 *    改 RecordRow 的字体或内边距时要同步改（文件顶部有说明）。
 *
 * ── 动效
 * 高度即时变化 + 透明度用 animateTo 插值，动效来自透明度。
 * 不用高度动画（.height() 从无到有那一帧不可插值，没有中间帧），
 * 也不用 transition（挂在会卸载的节点上会与下方控件重叠）。
 */

/**
 * 单条记录卡片的高度（vp）。
 *
 * **这个值是实测出来的，不是按字体行高估算的。**
 * 真机 dump 边界（density 3.5）：
 *   6 条午餐记录 → 每张卡片 251px = 71.7vp，六张完全一致。
 *
 * 估算为什么靠不住：我按「内边距 + 16sp行高 + 12sp行高 + 11sp行高 + 间距」
 * 算出 80，但 ArkUI 的实际行高系数与字体度量都不是简单相加，
 * 差 8vp/条 —— 6 条就多出 50vp 空白，表现是「菜越多底部空白越厚」。
 *
 * ⚠️ 改动 RecordRow 的字体、内边距或行数后，必须重新实测并改这里：
 *    临时把它改成 0 与 200 各跑一次，用 dump 的 bounds 差值倒推，
 *    或直接把单条卡片放进一个不裁切的容器里读 onAreaChange。
 */
const RECORD_ROW_H: number = 72;

/** 明细区上下内边距（须与 mealDetail 的 padding 一致） */
const DETAIL_PAD_V: number = 12;

/** 明细区相邻记录之间的间距（须与 mealDetail 的 Column space 一致） */
const DETAIL_GAP: number = 8;

/** 「还没有记录」提示行的高度（fontSize 13 + 上下 padding 14） */
const EMPTY_HINT_H: number = 46;

/**
 * 算出一餐明细区应有的高度（vp）。
 *
 * 纯算术，不测量。详见文件头说明。
 */
export function mealDetailHeight(count: number): number {
  if (count <= 0) {
    return DETAIL_PAD_V * 2 + EMPTY_HINT_H;
  }
  return DETAIL_PAD_V * 2 + count * RECORD_ROW_H + (count - 1) * DETAIL_GAP;
}

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

  /** 这一餐的记录条数：高度由它直接算出来 */
  @Prop count: number = 0;

  /** 明细内容 */
  @BuilderParam content: () => void;

  build() {
    Column() {
      if (this.expanded) {
        Column() {
          this.content()
        }
        .width('100%')
      }
    }
    .width('100%')
    // 高度是算出来的：展开 = 算术高度，收起 = 0。两端都是数字，可插值。
    .height(this.expanded ? mealDetailHeight(this.count) : 0)
    .clip(true)
    .opacity(this.expanded ? this.alpha : 0)
  }
}
