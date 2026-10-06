/**
 * 热量缺口的分档与配色 —— **首页与桌面卡片共用的唯一来源**。
 *
 * ══════════════════════════════════════════════════════════════
 * 【为什么单独一个文件，而不是放进 Theme.ets】
 * ══════════════════════════════════════════════════════════════
 * Theme.ets 里有 `import { curves } from '@kit.ArkUI'`（动画曲线需要它）。
 * 而桌面卡片的 Ability 侧**不能把 UI 依赖带进卡片服务进程** ——
 * CardData.ets 的文件头专门强调了这一点。
 *
 * 所以这段「纯比较 + 三个色值」的逻辑放在这里：
 * 它只依赖字符串和数字，任何一侧引用都不会牵连 ArkUI 或 FormKit。
 *
 *   Theme.ets      → 主应用侧再导出一次（页面从 Theme 取，少改调用点）
 *   CardData.ets   → 卡片侧直接从这里取
 *
 * 两边拿到的是**同一份实现**，不会出现「首页说达标、卡片说未达标」。
 */

/** 达标（实际缺口 ≥ 计划缺口） */
export const DEFICIT_COLOR_ON_TRACK: string = '#22C55E';
/** 未达标（0 ≤ 实际 < 计划） */
export const DEFICIT_COLOR_BELOW: string = '#E8A33D';
/** 超出（实际 < 0，能量盈余） */
export const DEFICIT_COLOR_OVER: string = '#E5533D';
/** 中性灰：达标时的文案色（状态已由环色表达，文案不必再上色） */
export const DEFICIT_COLOR_NEUTRAL: string = '#8A8F99';

/**
 * 热量缺口的三档状态。
 *
 *   达标  （ON_TRACK）实际缺口 ≥ 计划缺口   → 绿
 *   未达标（BELOW）   0 ≤ 实际 < 计划      → 黄
 *   超出  （OVER）    实际 < 0（能量盈余） → 红
 */
export enum DeficitState {
  ON_TRACK = 0,
  BELOW = 1,
  OVER = 2
}

/**
 * 判定缺口属于哪一档。
 *
 * 为什么和「计划缺口」比，而不是和 0 比：
 *   每日目标本身已含「想减的那部分」（plannedDeficit = TDEE − 目标）。
 *   按计划吃到目标那天，实际缺口正好等于 plannedDeficit —— 那是**达标**，
 *   不该因为「没有额外少吃」就变黄。
 *   只有吃得比目标还多（实际 < 计划）才算没跟上进度。
 */
export function deficitState(deficit: number, plannedDeficit: number): DeficitState {
  if (deficit < 0) {
    return DeficitState.OVER;
  }
  if (deficit < plannedDeficit) {
    return DeficitState.BELOW;
  }
  return DeficitState.ON_TRACK;
}

/** 按档位取颜色 */
export function deficitColor(deficit: number, plannedDeficit: number): string {
  switch (deficitState(deficit, plannedDeficit)) {
    case DeficitState.OVER:
      return DEFICIT_COLOR_OVER;
    case DeficitState.BELOW:
      return DEFICIT_COLOR_BELOW;
    default:
      return DEFICIT_COLOR_ON_TRACK;
  }
}

/**
 * 档位对应的极短文案。
 *
 * 保持两三个字：卡片一行只放得下约 20 个字符，长了会被截断成省略号。
 */
export function deficitLabel(deficit: number, plannedDeficit: number): string {
  switch (deficitState(deficit, plannedDeficit)) {
    case DeficitState.OVER:
      return '超出';
    case DeficitState.BELOW:
      return '未达标';
    default:
      return '缺口';
  }
}

/** 档位文案的颜色：达标用中性灰，异常档才上彩色 */
export function deficitLabelColor(deficit: number, plannedDeficit: number): string {
  if (deficit < plannedDeficit) {
    return deficitColor(deficit, plannedDeficit);
  }
  return DEFICIT_COLOR_NEUTRAL;
}
