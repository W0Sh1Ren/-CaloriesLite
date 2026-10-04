/**
 * 视觉常量。
 *
 * 风格取向：暖色主调 + 大量留白，数字大、其余信息压低对比度；
 * 顶部用一层随时间变化的柔光渐变营造「沉浸光感」，底部导航栏做成悬浮毛玻璃。
 */
import { curves } from '@kit.ArkUI';

/** 主色：暖橙，代表热量 */
export const COLOR_PRIMARY: string = '#FF7A45';
/** 主色的浅色版本，用于进度环底色与标签背景 */
export const COLOR_PRIMARY_SOFT: string = '#FFE7DC';
/** 缺口为负（超标）时的警示色 */
export const COLOR_WARN: string = '#E5533D';
/** 达标色 */
export const COLOR_OK: string = '#2FA36B';

/** 页面背景 */
export const COLOR_BG: string = '#F6F7F9';
/** 卡片背景 */
export const COLOR_CARD: string = '#FFFFFF';
/** 主文字 */
export const COLOR_TEXT: string = '#1A1A1A';
/** 次要文字 */
export const COLOR_TEXT_SUB: string = '#8A8F99';
/** 分割线 */
export const COLOR_DIVIDER: string = '#EEF0F3';

/** 三大营养素配色 */
export const COLOR_PROTEIN: string = '#4C8DFF';
export const COLOR_FAT: string = '#FFB020';
export const COLOR_CARB: string = '#2FA36B';

/** 常规间距 */
export const GAP: number = 12;
/** 页面左右内边距 */
export const PAGE_PAD: number = 16;
/** 卡片圆角 */
export const RADIUS: number = 18;
/** 卡片内边距 */
export const CARD_PAD: number = 16;
/** 卡片柔和投影（悬浮导航栏与卡片共用同一套，保证视觉一致） */
export const CARD_SHADOW: ShadowOptions = {
  radius: 18,
  color: 'rgba(24, 28, 36, 0.06)',
  offsetX: 0,
  offsetY: 6
};

/** 换算：1 公斤脂肪约等于多少千卡 */
export const KCAL_PER_KG_FAT: number = 7700;

/** 悬浮导航栏高度 */
export const NAV_HEIGHT: number = 62;
/** 悬浮导航栏离屏幕左右与底部的距离 */
export const NAV_MARGIN: number = 18;
/**
 * 内容区底部要为悬浮导航栏留出的空间。
 *
 * 组成：导航栏自身高度 + 上下两个外边距 + 让开底部手势条的一点余量。
 * 首页的固定底栏（拍照按钮）与滚动区末尾都用这个值，避免被导航栏压住。
 */
export const NAV_RESERVE: number = NAV_HEIGHT + NAV_MARGIN * 2 + 6;

/** 动效时长（毫秒） */
export const DUR_FAST: number = 180;
export const DUR_NORMAL: number = 260;
/** 弹性曲线，用于导航指示器的滑动 */
export const CURVE_SPRING: ICurve = curves.springMotion(0.42, 0.9);

/**
 * 顶部柔光渐变的配色。
 *
 * 「沉浸光感」的做法：在页面顶部铺一层很淡的径向暖光，
 * 颜色随一天中的时段轻微变化，让界面不至于整天一个死板的底色。
 */
export class GlowPalette {
  /** 渐变起点色（最亮处） */
  from: string;
  /** 渐变终点色（淡出到页面底色） */
  to: string;

  constructor(from: string, to: string) {
    this.from = from;
    this.to = to;
  }
}

/** 按小时取柔光配色：清晨偏暖橙，白天偏中性，夜晚偏冷蓝 */
export function glowForHour(hour: number): GlowPalette {
  if (hour >= 5 && hour < 11) {
    // 清晨到上午：暖橙
    return new GlowPalette('#FFE3D2', '#F6F7F9');
  }
  if (hour >= 11 && hour < 17) {
    // 白天：淡金
    return new GlowPalette('#FFF0D9', '#F6F7F9');
  }
  if (hour >= 17 && hour < 21) {
    // 傍晚：霞粉
    return new GlowPalette('#FFE0DC', '#F6F7F9');
  }
  // 夜间：冷蓝
  return new GlowPalette('#DCE6F5', '#F6F7F9');
}
