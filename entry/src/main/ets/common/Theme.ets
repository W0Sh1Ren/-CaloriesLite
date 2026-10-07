/**
 * 视觉常量。
 *
 * 风格取向：暖色主调 + 大量留白，数字大、其余信息压低对比度；
 * 顶部用一层随时间变化的柔光渐变营造「沉浸光感」，底部导航栏做成悬浮毛玻璃。
 */
import { curves } from '@kit.ArkUI';

/** 主色：暖橙，代表热量 */
export function COLOR_PRIMARY(): Resource { return $r('app.color.color_primary'); }
/** 主色的浅色版本，用于进度环底色与标签背景 */
export function COLOR_PRIMARY_SOFT(): Resource { return $r('app.color.color_primary_soft'); }
/**
 * 选中气泡的玻璃绿。
 *
 * 半透明的品牌绿 + 白色柔光叠成，既看得出是选中态，
 * 又保留玻璃的通透感（纯不透明绿会变成一块实心色，纯白又看不出选中）。
 */
export function COLOR_PRIMARY_GLASS(): Resource { return $r('app.color.color_primary_glass'); }
/** 缺口为负（超标）时的警示色 */
export function COLOR_WARN(): Resource { return $r('app.color.color_warn'); }
/** 达标色 */
export function COLOR_OK(): Resource { return $r('app.color.color_ok'); }

/** 页面背景 */
export function COLOR_BG(): Resource { return $r('app.color.color_bg'); }
/** 卡片背景 */
export function COLOR_CARD(): Resource { return $r('app.color.color_card'); }
/** 主文字 */
export function COLOR_TEXT(): Resource { return $r('app.color.color_text'); }
/** 次要文字 */
export function COLOR_TEXT_SUB(): Resource { return $r('app.color.color_text_sub'); }
/**
 * 底部导航未选中项的颜色。
 *
 * 用 iOS 系的中性灰：导航栏浮在内容之上、背景不可控，
 * 纯中性灰在任何底色上都能保持「未选中」的语义，不会和品牌绿抢注意力。
 */
export function COLOR_NAV_IDLE(): Resource { return $r('app.color.color_nav_idle'); }
/** 底部导航选中项的颜色：比主色更亮的绿，浮在玻璃上更醒目 */
export function COLOR_NAV_ACTIVE(): Resource { return $r('app.color.color_nav_active'); }
/** 分割线 */
export function COLOR_DIVIDER(): Resource { return $r('app.color.color_divider'); }

/** 三大营养素配色 */
/** 碳水：浅蓝 */
export function COLOR_CARB(): Resource { return $r('app.color.color_carb'); }
/** 蛋白质：浅绿（与主色同系） */
export function COLOR_PROTEIN(): Resource { return $r('app.color.color_protein'); }
/** 脂肪：淡黄 */
export function COLOR_FAT(): Resource { return $r('app.color.color_fat'); }

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

/*
 * ============================================================
 * 玻璃（沉浸光感）参数
 *
 * 口径参考 WeiboPura《新 API26 沉浸光感经验汇总》的自绘玻璃配方：
 *   半透明底 + 真模糊(带 scale) + 0.5vp 极细描边 + 深色大半径投影
 * 该文档全工程的玻璃都收敛到这几个值，此处集中一处便于统一调整。
 * ============================================================
 */

/**
 * 玻璃的极细高光描边。
 *
 * 文档里所有自绘玻璃都是 0.5vp（不是 1~1.5）：
 * 描边只负责勾出「玻璃有厚度」这一条信息，粗了就变成实体边框，
 * 通透感反而下降。
 */
export const GLASS_HAIRLINE: number = 0.5;
/**
 * 玻璃描边颜色。
 *
 * 偏亮的白 —— 这圈边是「折射」最直接的视觉信号：
 * 光线在玻璃边缘被折弯，看起来就是一条比底色亮得多的细边。
 */
export function COLOR_GLASS_BORDER(): Resource { return $r('app.color.color_glass_border'); }

/**
 * 玻璃的深色大半径投影 —— 「浮起感」的来源。
 *
 * 与白色内光晕（GLASS_GLOW）分工不同：
 *   这条深色投影负责与下方内容拉开层次（浮在内容之上）
 *   白色光晕负责边缘的内发光（玻璃厚度）
 * 只留后者会显得「贴」在内容上、没有高度。
 */
export const GLASS_LIFT_SHADOW: ShadowOptions = {
  radius: 32,
  color: 'rgba(20, 30, 24, 0.8)',
  offsetX: 0,
  offsetY: 8
};

/**
 * 玻璃边缘的白色内发光，模拟光线在玻璃里的折射。
 *
 * offsetY 取负：把光晕推到**上缘**，形成顶部的弧形高光。
 * 真实的厚玻璃受光主要在上沿，方向性内光比均匀发光更像玻璃。
 */
export const GLASS_GLOW: ShadowOptions = {
  radius: 8,
  color: 'rgba(200, 240, 210, 0.75)',
  offsetX: 0,
  offsetY: 3
};

/**
 * 玻璃内部的纵向高光渐变。
 *
 * 上端略亮、下端接近透明 —— 模拟光线斜射进玻璃后在内侧的衰减。
 * 这是「折射」里最容易被眼睛识别的一层：玻璃上缘总比下缘亮一点。
 */
export const GLASS_INNER_GRADIENT: Array<[ResourceColor, number]> = [
  ['rgba(255, 255, 255, 0.34)', 0.0],
  ['rgba(255, 255, 255, 0.06)', 0.55],
  ['rgba(255, 255, 255, 0.0)', 1.0]
];

/** 顶栏底缘的分隔投影：比悬浮件更轻，只把顶栏和滚动内容分开 */
export const TOP_BAR_SHADOW: ShadowOptions = {
  radius: 12,
  color: 'rgba(0, 0, 0, 0.03)',
  offsetX: 0,
  offsetY: 4
};

/**
 * 输入框文字对比度（务必在每个 TextInput / TextArea 上显式设置）。
 *
 * 问题：不指定时用系统默认色，在本应用的浅色底（COLOR_BG #F5F8F6）上
 * 对比度很低，正文与占位符都几乎与背景同色，读不出来（实测反馈）。
 *
 * 试过用 @Styles 全局收敛，但 @Styles 只能作用于 CommonAttribute，
 * 而 fontColor / placeholderColor 是 TextInput 的专属属性，
 * 会报「Property 'fontColor' does not exist on type 'CommonAttribute'」。
 * 所以只能逐处写，新增输入框时照抄这两行。
 */
export const INPUT_TEXT: Resource = COLOR_TEXT();
export const INPUT_PLACEHOLDER: Resource = COLOR_TEXT_SUB();

/** 换算：1 公斤脂肪约等于多少千卡 */
export const KCAL_PER_KG_FAT: number = 7700;

/**
 * 缺口分档与配色 —— 实现在 common/DeficitStyle.ets。
 *
 * 这里只做**转发**，让页面继续从 Theme 取（少改调用点）。
 * 为什么实现不放本文件：Theme 依赖 @kit.ArkUI（动画曲线），
 * 而桌面卡片的 Ability 侧不能把 UI 依赖带进卡片进程 ——
 * DeficitStyle 是纯净的，卡片可以直接引用同一份实现。
 */
export { DeficitState, deficitState, deficitColor, deficitLabel, deficitLabelColor } from './DeficitStyle';

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

/**
 * 官方标题栏（HdsNavigation titleBar）**本体**的高度（vp）。
 *
 * ⚠️ 一般不要直接用这个常量，用 AppState.contentTopOffset（见下）。
 *
 * 为什么需要留位：titleBar 是**悬浮在内容之上**的，不像早先的自绘顶栏
 * 那样占布局位置。所以每个页面的内容都得自己让出来，否则第一行会被压住。
 *
 * 数值来源：用户真机校准。起初按标题栏文本区推算为 56，
 * 但 70 的观感更合适（内容与标题栏之间留出更自然的呼吸）。
 */
export const TOP_BAR_RESERVE: number = 70;

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
export function COLOR_PRESS_GLOW(): Resource { return $r('app.color.color_press_glow'); }

/**
 * 手动逐帧数值动画器。
 *
 * 给 Canvas 自绘图形用。
 *
 * 为什么不能像营养素条那样用 animateTo：
 * animateTo 只能插值「属性」，而 Canvas 里的圆弧是一次性画上去的路径，
 * 不在属性动画通道里。实测在 animateTo 回调里改状态 + 手动 draw()，
 * 拿到的是目标值，弧线直接瞬移——所以必须自己按帧推进。
 *
 * 用法：
 *   ticker.to(target, (v) => { this.animRatio = v; this.draw(v); });
 */
export class ValueTicker {
  /** 当前显示值 */
  current: number = 0;
  /** 定时器句柄，-1 表示没有在跑 */
  private timer: number = -1;
  /** 本次动画的起止与起始时刻 */
  private from: number = 0;
  private to_: number = 0;
  private startedAt: number = 0;
  private duration: number = 420;

  /** 是否正在动画中 */
  isRunning(): boolean {
    return this.timer !== -1;
  }

  /** 停掉当前动画（组件销毁时必须调用，否则回调会打到已销毁的实例上） */
  stop(): void {
    if (this.timer !== -1) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  /**
   * 平滑推进到 target。
   *
   * @param target   目标值
   * @param apply    每帧回调，拿到当前插值
   * @param duration 时长（毫秒）
   * @param duration 不传则用默认
   */
  to(target: number, apply: (v: number) => void, duration: number = 420): void {
    // 起止相同就没必要起动画
    if (Math.abs(target - this.current) < 0.0001) {
      this.current = target;
      apply(target);
      return;
    }
    this.stop();
    this.from = this.current;
    this.to_ = target;
    this.startedAt = Date.now();
    this.duration = duration;

    this.timer = setInterval(() => {
      const elapsed: number = Date.now() - this.startedAt;
      const t: number = this.duration <= 0 ? 1 : Math.min(1, elapsed / this.duration);
      // easeOutCubic：起步快、收尾缓，和应用的其它动效节奏一致
      const eased: number = 1 - Math.pow(1 - t, 3);
      this.current = this.from + (this.to_ - this.from) * eased;
      apply(this.current);
      if (t >= 1) {
        this.current = this.to_;
        apply(this.current);
        this.stop();
      }
    }, 16);
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
/**
 * 折叠面板（餐次明细 / 个人情况明细）展开与收起的时长。
 *
 * 比 DUR_NORMAL(260) 长一些：这是一次**高度变化**（可能几百 vp），
 * 260ms 显得急、像硬切；320ms 能看清「撑开/收起」的过程。
 */
export const DUR_MEAL_EXPAND: number = 320;

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
 * ══════════════════════════════════════════════════════════════
 * 【当前状态：柔光已关掉色偏，四个时段都等于页面底色】
 * ══════════════════════════════════════════════════════════════
 * 原本的设计是「按一天中的时段给不同的淡色光」：
 *   清晨嫩绿 / 白天薄荷 / 傍晚淡青 / 夜间冷蓝。
 *
 * 但用户反馈**首页与记录页的背景发绿**——那层柔光铺满整屏，
 * 深色下尤其明显（深底上一点色偏就看得出来），
 * 而「我的」页因为内容结构不同观感偏中性，于是三个页面不一致。
 *
 * 处理方式：把 base 与 dark 里的 color_glow_* 全部改成**页面底色本身**
 * （浅色 #F5F8F6 / 深色 #121212）。渐变依然在渲染，
 * 但两端同色 → 视觉上就是干净的纯色背景，三个页面完全一致。
 *
 * 想恢复时段色偏：只改 resources 里那 5 个 color_glow_* 的值即可，
 * 代码不用动。当时用的值记在下面备查：
 *   浅色  #DFF5E3 / #E8F8EC / #DCF2EA / #DCE6F5，尾色 #F6F7F9
 *   深色  #1B2A20 / #182720 / #17262A / #171E2A，尾色 #161616
 *
 * ⚠️ 类型是 Resource（不是 string）：这样深色模式能自动切到另一套色值。
 */
export class GlowPalette {
  /** 渐变起点色（最亮处） */
  from: Resource;
  /** 渐变终点色（淡出到页面底色） */
  to: Resource;

  constructor(from: Resource, to: Resource) {
    this.from = from;
    this.to = to;
  }
}

/**
 * 按小时取柔光配色。
 *
 * ⚠️ 目前四个时段的色值在 resources 里**都是页面底色**，
 *    所以这个函数实际上返回恒定的同色渐变（见上面 GlowPalette 的说明）。
 *    保留按小时分支是为了以后想恢复时段色偏时**只改色值、不改代码**。
 */
export function glowForHour(hour: number): GlowPalette {
  const tail: Resource = $r('app.color.color_glow_tail');
  if (hour >= 5 && hour < 11) {
    return new GlowPalette($r('app.color.color_glow_dawn'), tail);
  }
  if (hour >= 11 && hour < 17) {
    return new GlowPalette($r('app.color.color_glow_day'), tail);
  }
  if (hour >= 17 && hour < 21) {
    return new GlowPalette($r('app.color.color_glow_dusk'), tail);
  }
  return new GlowPalette($r('app.color.color_glow_night'), tail);
}
