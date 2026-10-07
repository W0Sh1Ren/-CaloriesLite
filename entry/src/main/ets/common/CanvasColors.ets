/**
 * Canvas 专用的颜色常量（**字符串**，不是资源引用）。
 *
 * ══════════════════════════════════════════════════════════════
 * 【为什么需要单独一个文件】
 * ══════════════════════════════════════════════════════════════
 * 全应用的颜色已经改成资源引用（`Theme.COLOR_*()` → `$r('app.color.*')`），
 * 这样深色模式能自动切换。
 *
 * 但 **Canvas 的 API 不吃 Resource**：
 *     ctx.strokeStyle / ctx.fillStyle / ctx.shadowColor
 *   类型是 `string | number | CanvasGradient | CanvasPattern`，
 *   传 `Resource` 编译不过。
 *
 * 所以画布上的颜色只能用字符串字面量 —— 代价是**这些颜色不跟随深色模式**。
 *
 * 【为什么不做成随主题切换】
 * 理论上可以：让这里的函数读一个「当前是否深色」的开关，切换时重绘画布。
 * 但 Canvas 不在 ArkUI 的属性动画/重建通道里，颜色变了必须**手动重绘**，
 * 而画布本身有逐帧动画（热量环的进度、体重曲线的描点），
 * 引入主题监听会让重绘时机和动画打架。收益（几个画布元素换色）
 * 远小于风险，所以这里保持固定色值。
 *
 * ⚠️ 数值必须与 `resources/base/element/color.json` 里的同名色保持一致。
 *    改配色时这两处要一起改。
 *
 * 另外：本文件**刻意零导入** —— 桌面卡片的 Ability 侧也要用它，
 * 而卡片进程不能把 ArkUI / Theme 的依赖带进去
 *（见 CardData.ets 文件头的说明）。
 */

/** 与 color_primary 一致（品牌绿） */
export const CANVAS_PRIMARY: string = '#22C55E';
/** 与 color_primary_soft 一致（环底浅绿） */
export const CANVAS_PRIMARY_SOFT: string = '#DCFCE7';
/** 与 color_text_sub 一致（次要文字） */
export const CANVAS_TEXT_SUB: string = '#8A8F99';
/** 与 color_text 一致（主文字） */
export const CANVAS_TEXT: string = '#1A1A1A';
/** 与 color_divider 一致（分割线 / 网格） */
export const CANVAS_DIVIDER: string = '#EEF0F3';
/** 与 color_nav_idle 一致（导航未选中） */
export const CANVAS_NAV_IDLE: string = '#8E8E93';
/** 与 color_nav_active 一致（导航选中） */
export const CANVAS_NAV_ACTIVE: string = '#10B981';

/** 全透明（Canvas 清屏用） */
export const CANVAS_TRANSPARENT: string = '#00000000';
