/**
 * 视觉常量。
 *
 * 风格取向：暖色主调 + 大量留白，数字大、其余信息压低对比度；
 * 顶部用一层随时间变化的柔光渐变营造「沉浸光感」，底部导航栏做成悬浮毛玻璃。
 */
import { curves } from '@kit.ArkUI';

/** 主色：暖橙，代表热量 */
export const COLOR_PRIMARY: string = '#22C55E';
/** 主色的浅色版本，用于进度环底色与标签背景 */
export const COLOR_PRIMARY_SOFT: string = '#DCFCE7';
/**
 * 选中气泡的玻璃绿。
 *
 * 半透明的品牌绿 + 白色柔光叠成，既看得出是选中态，
 * 又保留玻璃的通透感（纯不透明绿会变成一块实心色，纯白又看不出选中）。
 */
export const COLOR_PRIMARY_GLASS: string = '#4D22C55E';
/** 缺口为负（超标）时的警示色 */
export const COLOR_WARN: string = '#E5533D';
/** 达标色 */
export const COLOR_OK: string = '#2FA36B';

/** 页面背景 */
export const COLOR_BG: string = '#F5F8F6';
/** 卡片背景 */
export const COLOR_CARD: string = '#FFFFFF';
/** 主文字 */
export const COLOR_TEXT: string = '#1A1A1A';
/** 次要文字 */
export const COLOR_TEXT_SUB: string = '#8A8F99';
/**
 * 底部导航未选中项的颜色。
 *
 * 用中性灰而不是次级文字色：导航栏浮在内容之上、背景不可控，
 * 纯中性灰在任何底色上都能保持「未选中」的语义，不会和品牌绿抢注意力。
 */
export const COLOR_NAV_IDLE: string = '#999999';
/** 分割线 */
export const COLOR_DIVIDER: string = '#EEF0F3';

/** 三大营养素配色 */
/** 碳水：浅蓝 */
export const COLOR_CARB: string = '#4C8DFF';
/** 蛋白质：浅绿（与主色同系） */
export const COLOR_PROTEIN: string = '#22C55E';
/** 脂肪：淡黄 */
export const COLOR_FAT: string = '#F5C142';

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

/** 悬浮导航栏高度。取 70 是为了让 borderRadius 正好是高度的一半（35），capsule 才对称 */
export const NAV_HEIGHT: number = 70;
/** 悬浮导航栏圆角：固定为高度的一半，形成完整胶囊 */
export const NAV_RADIUS: number = NAV_HEIGHT / 2;
/** 悬浮导航栏离屏幕左右的距离 */
export const NAV_MARGIN: number = 18;
/**
 * 内容区底部要为悬浮导航栏留出的空间。
 *
 * 组成：导航栏自身高度 + 上下两个外边距 + 让开底部手势条的一点余量。
 * 首页的固定底栏（拍照按钮）与滚动区末尾都用这个值，避免被导航栏压住。
 */
export const NAV_RESERVE: number = NAV_HEIGHT + NAV_MARGIN * 2 + 6;

/** 动效时长（毫秒）。任何状态变化都要有过渡，时长统一在这里取 */
export const DUR_FAST: number = 180;
export const DUR_NORMAL: number = 260;
export const DUR_SLOW: number = 420;
/** 弹性曲线，用于导航指示器的滑动 */
export const CURVE_SPRING: ICurve = curves.springMotion(0.42, 0.9);
/** 更「弹」一点的曲线，用于页面切换、展开收起这类需要存在感的地方 */
export const CURVE_BOUNCE: ICurve = curves.springMotion(0.34, 0.72);
/** 数字滚动用的曲线：先快后慢，像是「滚到位」 */
export const CURVE_COUNT: ICurve = curves.responsiveSpringMotion(0.5, 0.86);

/** 按压反馈：按下时缩到的比例 */
export const PRESS_SCALE: number = 0.9;
/** 按压/高亮光效的底色 */
export const COLOR_PRESS_GLOW: string = '#2622C55E';

/**
 * 把「当前显示值」平滑推动到「目标值」，用于进度条 / 圆环这类需要连续变化的图形。
 *
 * 用法（放在组件的 @Prop 的 @Watch 回调里）：
 *
 *   onTargetChange(): void {
 *     animated.animate(this, () => this.ratio, (v) => { this.animRatio = v; });
 *   }
 *
 * 为什么不直接用 `.animation()` 修饰符：那个只对「属性修饰符」生效，
 * 而这里的宽度是算出来的百分比字符串、圆环是 Canvas 绘制的，
 * 都不走属性动画通道，只能自己逐帧插值。
 */
export class AnimatedValue {
  /** 当前显示的值 */
  current: number = 0;
  /** 是否已初始化过（首个值不播动画，直接落位） */
  private started: boolean = false;

  /**
   * 从当前显示值平滑推到 target。
   *
   * @param host    调用它的组件（用来取 UIContext 起 animateTo）
   * @param ratio   取目标值的函数
   * @param apply   把插值写回 @State 的回调，写回会触发重建从而重绘
   */
  animate(host: CustomComponent, ratio: () => number, apply: (v: number) => void,
    duration: number = DUR_SLOW, curve: ICurve = CURVE_COUNT): void {
    const target: number = ratio();
    if (!this.started) {
      // 首次进入直接落位，否则页面一打开就会从 0 长出来
      this.started = true;
      this.current = target;
      apply(target);
      return;
    }
    if (Math.abs(target - this.current) < 0.0001) {
      return;
    }
    host.getUIContext().animateTo({ duration: duration, curve: curve }, () => {
      this.current = target;
      apply(target);
    });
  }
}

/**
 * 页面切换动画参数。
 *
 * 未选中的视图缩到 VIEW_INACTIVE_SCALE 并整体平移出屏，
 * 切换时用弹性曲线滑入，形成「左右切换」的方向感。
 */
export const VIEW_INACTIVE_SCALE: number = 0.94;
/** 视图平移出屏的距离，要足够大才能完全移出可视区 */
export const VIEW_SLIDE_X: number = 96;
/** 切换动画时长，比普通过渡略长，让方向感看得清 */
export const DUR_VIEW_SWITCH: number = 340;

/** 透明度过渡：淡出快一点，避免两个视图同时可见时发灰 */
export const VIEW_TRANSITION_OUT: TransitionEffect = TransitionEffect.OPACITY
  .animation({ duration: DUR_FAST, curve: Curve.EaseIn });

/** 透明度过渡：淡入慢一点，配合位移形成层次 */
export const VIEW_TRANSITION_IN: TransitionEffect = TransitionEffect.OPACITY
  .animation({ duration: DUR_VIEW_SWITCH, curve: Curve.EaseOut });

/**
 * 取相机式的位移过渡。每次调用都新建实例——
 * TransitionEffect 携带内部状态，复用同一个实例会导致动画不重放。
 */
export function cameralSlide(fromX: number, toX: number): TransitionEffect {
  return TransitionEffect.asymmetric(
    TransitionEffect.OPACITY
      .combine(TransitionEffect.translate({ x: toX }))
      .animation({ duration: DUR_VIEW_SWITCH, curve: Curve.FastOutSlowIn }),
    TransitionEffect.OPACITY
      .combine(TransitionEffect.translate({ x: fromX }))
      .animation({ duration: DUR_FAST, curve: Curve.EaseIn })
  );
}

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
    // 清晨到上午：嫩绿
    return new GlowPalette('#DFF5E3', '#F6F7F9');
  }
  if (hour >= 11 && hour < 17) {
    // 白天：极淡薄荷
    return new GlowPalette('#E8F8EC', '#F6F7F9');
  }
  if (hour >= 17 && hour < 21) {
    // 傍晚：淡青
    return new GlowPalette('#DCF2EA', '#F6F7F9');
  }
  // 夜间：冷蓝（保留一点暖夜对比）
  return new GlowPalette('#DCE6F5', '#F6F7F9');
}
