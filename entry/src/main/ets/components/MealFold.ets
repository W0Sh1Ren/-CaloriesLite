/**
 * 餐次卡片的明细区（可折叠内容）。「展开动画 3.0」的容器实现。
 *
 * ══════════════════════════════════════════════════════════════
 * 【核心：高度用算术算出来，不做任何测量】
 * ══════════════════════════════════════════════════════════════
 * 每条记录卡片（RecordRow）的高度是**定值**（那边显式钉死了），
 * 所以明细区高度 = 上下内边距 + 条数 × 单条高度 + (条数-1) × 间距。
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
 * ⚠️ 明细区高度依赖三个常量，它们必须与实际渲染一致：
 *    · RECORD_ROW_H  —— **从 RecordRow 导入**（那边把卡片高度钉死了），
 *                       所以它不再是「两处各写一个数字」的隐患
 *    · DETAIL_PAD_V  —— 须与 Index.ets 的 mealDetail() padding 一致
 *    · DETAIL_GAP    —— 须与 Index.ets 的 mealDetail() Column space 一致
 *
 * ── 动效
 * 高度即时变化 + 透明度用 animateTo 插值，动效来自透明度。
 * 不用高度动画（.height() 从无到有那一帧不可插值，没有中间帧），
 * 也不用 transition（挂在会卸载的节点上会与下方控件重叠）。
 */

/**
 * 单条记录卡片的高度（vp）—— **从 RecordRow 导入，不在这里重复声明**。
 *
 * RecordRow 已经把卡片高度显式钉成了定值（见那边的 RECORD_ROW_FIXED_H），
 * 于是这个高度是**代码保证的**，不再是「实测出来、可能漂移」的观测值。
 *
 * 历史：这个值以前是本文件里的 `const RECORD_ROW_H = 72`，与 RecordRow
 * 的实际高度只是「碰巧相等」。一旦同一餐里混入不带营养素行的记录
 *（那张卡片天然矮约 14vp），乘法就不成立，展开高度会与实际对不上。
 */
import { RECORD_ROW_FIXED_H as RECORD_ROW_H } from './RecordRow';

/** 明细区上下内边距（须与 mealDetail 的 padding 一致） */
const DETAIL_PAD_V: number = 12;

/** 明细区相邻记录之间的间距（须与 mealDetail 的 Column space 一致） */
const DETAIL_GAP: number = 8;

/** 「还没有记录」提示行的高度（fontSize 13 + 上下 padding 14） */
const EMPTY_HINT_H: number = 43;

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
