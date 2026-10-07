/**
 * Canvas 专用的颜色 —— **字符串**，但**会跟随系统深浅色**。
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
 * 【为什么不能只写死字符串】
 * 一开始这里全是固定色值，结果是：深色模式下首页那个热量环的**底环**
 * 是一圈发亮的白/浅色，非常扎眼，而且和桌面卡片里的环对不上
 *（卡片用 Progress 组件，底环走资源、深色下是深灰 #2C2C2E）。
 *
 * 【所以怎么做的】
 * 这里放**成对**的色值（浅色 / 深色），由 `resolveCanvasColor()` 按当前
 * 颜色模式返回字符串。当前模式由 EntryAbility 在启动与
 * onConfigurationUpdate 时通过 `setCanvasDarkMode()` 写入。
 *
 * ⚠️ 用法是 **`resolveCanvasColor(PAIR_XXX)`**，不要直接引用 ALPHA/BETA。
 *
 * 【已知限制】
 * 本文件**刻意零导入** —— 桌面卡片的 Ability 侧也要用它，
 * 而卡片进程不能把 ArkUI / Theme 的依赖带进去
 *（见 CardData.ets 文件头的说明）。所以深浅色开关只能靠外部写进来，
 * 不能自己读系统。
 *
 * 另外：切换深浅色时画布**不会自动重绘**（Canvas 不在 ArkUI 的重建通道里）。
 * 首页热量环的重绘由 `Index.onConfigurationUpdate` 触发（见那里）。
 */

/** 一对色值：浅色主题用 a，深色主题用 b */
export class CanvasColorPair {
  a: string;
  b: string;
  constructor(a: string, b: string) {
    this.a = a;
    this.b = b;
  }
}

/** 当前是否深色。由 EntryAbility 写入，默认浅色 */
let canvasDark: boolean = false;

/** 由 EntryAbility 在启动与系统主题变化时调用 */
export function setCanvasDarkMode(isDark: boolean): void {
  canvasDark = isDark;
}

/** 当前是否深色（画布侧可读，用来决定要不要重绘） */
export function isCanvasDark(): boolean {
  return canvasDark;
}

/** 按当前颜色模式取字符串色值 */
export function resolveCanvasColor(pair: CanvasColorPair): string {
  return canvasDark ? pair.b : pair.a;
}

/** 主色（品牌绿，深浅色同值） */
export const PAIR_PRIMARY: CanvasColorPair = new CanvasColorPair('#22C55E', '#22C55E');
/**
 * 环的底环色（未完成的那一段）。
 *
 * ⚠️ 这两个值要**分别**对上两个来源：
 *   浅色 #E8EBEF → 卡片里 color_card_track 的浅色值
 *   深色 #2C2C2E → 卡片里 color_card_track 的深色值
 * 这样首页的环和桌面卡片的环在两种主题下都一致。
 *
 * 早先浅色用的是浅绿 #DCFCE7，深色下没换 → 变成深底上一圈亮绿，
 * 与卡片对不上（用户反馈）。
 */
export const PAIR_RING_TRACK: CanvasColorPair = new CanvasColorPair('#E8EBEF', '#2C2C2E');
/** 次要文字 */
export const PAIR_TEXT_SUB: CanvasColorPair = new CanvasColorPair('#8A8F99', '#9BA1A6');
/** 主文字 */
export const PAIR_TEXT: CanvasColorPair = new CanvasColorPair('#1A1A1A', '#F2F2F2');
/** 分割线 / 网格 */
export const PAIR_DIVIDER: CanvasColorPair = new CanvasColorPair('#EEF0F3', '#2C2C2E');
/** 导航未选中 */
export const PAIR_NAV_IDLE: CanvasColorPair = new CanvasColorPair('#8E8E93', '#9BA1A6');
/** 导航选中 */
export const PAIR_NAV_ACTIVE: CanvasColorPair = new CanvasColorPair('#10B981', '#34D399');
