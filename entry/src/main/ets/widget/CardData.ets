/**
 * 桌面卡片的数据契约 —— **所有派生计算都在这里做完**。
 *
 * ── 为什么必须这样分层（来自卡片实战文档的坑 5）
 * 卡片 UI 跑在系统的卡片框架进程里，它的响应式追踪**不会追踪
 * getter / 辅助方法内部对 @LocalStorageProp 的依赖**。
 * 也就是说，卡片里写
 *     this.macroBar('蛋白', this.protein, this.proteinTarget)
 * 或
 *     get primaryText() { return this.intake > 0 ? '…' : '…' }
 * 这类「读到属性再算」的代码，很可能求值时读不到值，
 * 表现为进度条按 0 渲染、按钮只剩背景色没有文字 —— 而且不报错。
 *
 * 所以规则是：**卡片 UI 零派生**，只负责把收到的字符串/百分比贴到界面上。
 * 凡是要「算一下」的，全在本文件算好，再由 CalorieCardAbility 推给卡片。
 *
 * 这个文件同时被 Ability（产出）和卡片页面（消费）引用，
 * 字段名在这里一处定义 —— 避免两边各写一份字符串而拼错
 *（文档的坑 3：@LocalStorageProp 的 key 大小写不一致 → 永远显示默认值）。
 *
 * 本文件**不依赖 ArkUI，也不依赖 FormKit**：只有纯数据与字符串处理，
 * 这样 Ability 侧引用它不会把 UI 依赖带进卡片服务进程。
 */
import { DailySummary } from '../model/Types';
import { MacroTarget } from '../model/Enums';

/** 三大营养素的配色，与主应用 Theme.ets 保持一致 */
const COLOR_PROTEIN = '#22C55E';
const COLOR_FAT = '#F5C142';
const COLOR_CARB = '#4C8DFF';

/**
 * 卡片的扁平数据结构。
 *
 * 所有字段都是**已经可以直接显示**的值：
 * 数字已取整、百分比已算好并带 % 号、配色已选定。
 * 卡片侧不得再做任何运算。
 */
export class CardData {
  /** 热量环：已摄入 / 预算，以及环的进度百分比（形如 "62%"） */
  intake: number = 0;
  budget: number = 2000;
  kcalRingPct: string = '0%';
  /** 环下方的一行小字，例如「还可以吃 1250」 */
  remainText: string = '';

  /** 三条营养素：克数、目标、进度百分比、配色、显示文案 */
  protein: number = 0;
  proteinTarget: number = 188;
  proteinPct: string = '0%';
  proteinText: string = '0 / 188 g';
  proteinColor: string = COLOR_PROTEIN;

  fat: number = 0;
  fatTarget: number = 56;
  fatPct: string = '0%';
  fatText: string = '0 / 56 g';
  fatColor: string = COLOR_FAT;

  carb: number = 0;
  carbTarget: number = 314;
  carbPct: string = '0%';
  carbText: string = '0 / 314 g';
  carbColor: string = COLOR_CARB;

  /**
   * 今天是否还没有任何记录。
   *
   * 也在这里算好：卡片里用 `this.intake <= 0` 这种判断同样属于派生。
   */
  emptyDay: boolean = true;
  /** 空状态文案 */
  emptyTitle: string = '今天还没记录';
  emptyHint: string = '点下面拍一张';

  /** 兜底预算（读不到档案时用），与 CalorieCardAbility 的 DEFAULT_BUDGET 一致 */
  static readonly DEFAULT_BUDGET: number = 2000;
  /** 兜底预算对应的三大营养素目标，避免各处各写一份 */
  static readonly DEFAULT_PROTEIN_TARGET: number = 188;
  static readonly DEFAULT_FAT_TARGET: number = 56;
  static readonly DEFAULT_CARB_TARGET: number = 314;

  /** 左上角的卡片标题（与桌面「添加卡片」里显示的名字一致） */
  appName: string = '轻卡记';
  /**
   * 右上角的刷新时间，形如 "14:36 更新"。
   *
   * 在后端算好字符串再推过来：卡片侧 new Date() 取时间属于派生，
   * 而且卡片进程的时间格式化行为不可控。
   */
  updatedText: string = '';

  /**
   * 取当前时钟，格式化成 "HH:mm 更新"。
   *
   * 兜底路径（读不到数据）也用它，保证右上角不会是空白 ——
   * 空白会让人以为卡片坏了，有个时间至少说明「这是刚渲染的」。
   */
  static nowText(): string {
    const d: Date = new Date();
    return `${CardData.pad2(d.getHours())}:${CardData.pad2(d.getMinutes())} 更新`;
  }

  private static pad2(n: number): string {
    return n < 10 ? `0${n}` : `${n}`;
  }

  /** 进度百分比：0~100，目标非法时给 0，并夹住上溢，形如 "62%" */
  private static pct(now: number, target: number): string {
    if (target <= 0) {
      return '0%';
    }
    const r: number = now / target;
    const clamped: number = r < 0 ? 0 : (r > 1 ? 1 : r);
    return `${Math.round(clamped * 100)}%`;
  }

  /** "已吃 / 目标 g" 文案 */
  private static gramsText(now: number, target: number): string {
    return `${Math.round(now)} / ${Math.round(target)} g`;
  }

  /**
   * 兜底数据。
   *
   * 卡片在绑定数据到位前会先按 @LocalStorageProp 的声明初值渲染一帧，
   * 所以「初值」与这里必须逐字段一致，否则那一帧的数字和最终值不同，
   * 看起来就是闪一下。
   *
   * 刻意**不把摄入填成全 0**：全 0 时环是空的、三条进度条也是空的，
   * 整张卡片像没加载出来。给足预算与目标后，「还没记录」在观感上
   * 就是「今天刚开始」，而不是「卡片坏了」。
   */
  static fallback(): CardData {
    const d: CardData = new CardData();
    d.intake = 0;
    d.budget = CardData.DEFAULT_BUDGET;
    d.proteinTarget = CardData.DEFAULT_PROTEIN_TARGET;
    d.fatTarget = CardData.DEFAULT_FAT_TARGET;
    d.carbTarget = CardData.DEFAULT_CARB_TARGET;
    CardData.fillDerived(d);
    return d;
  }

  /** 由当日汇总与营养素目标构造完整数据 */
  static from(summary: DailySummary, target: MacroTarget): CardData {
    const d: CardData = new CardData();
    const budget: number = Math.round(summary.budget);
    // 预算读不到（例如还没建档）时退回兜底值，不让环显示成 0/0
    d.budget = budget > 0 ? budget : CardData.DEFAULT_BUDGET;

    d.intake = Math.round(summary.intake);
    d.protein = Math.round(summary.protein);
    d.fat = Math.round(summary.fat);
    d.carb = Math.round(summary.carb);

    const useGiven: boolean = budget > 0;
    d.proteinTarget = useGiven ? target.protein : CardData.DEFAULT_PROTEIN_TARGET;
    d.fatTarget = useGiven ? target.fat : CardData.DEFAULT_FAT_TARGET;
    d.carbTarget = useGiven ? target.carb : CardData.DEFAULT_CARB_TARGET;

    CardData.fillDerived(d);
    return d;
  }

  /**
   * 把「看起来像派生」的字段一次性填好。
   *
   * 兜底与正常两条路径共用，保证不会出现「兜底时忘了算百分比」这类遗漏
   *（那会让卡片在数据到位前显示 0% 的条，到位后突然跳变）。
   */
  private static fillDerived(d: CardData): void {
    d.kcalRingPct = CardData.pct(d.intake, d.budget);
    const remain: number = Math.round(d.budget - d.intake);
    d.remainText = remain >= 0 ? `还可以吃 ${remain}` : `已超出 ${-remain}`;

    d.proteinPct = CardData.pct(d.protein, d.proteinTarget);
    d.proteinText = CardData.gramsText(d.protein, d.proteinTarget);
    d.proteinColor = COLOR_PROTEIN;

    d.fatPct = CardData.pct(d.fat, d.fatTarget);
    d.fatText = CardData.gramsText(d.fat, d.fatTarget);
    d.fatColor = COLOR_FAT;

    d.carbPct = CardData.pct(d.carb, d.carbTarget);
    d.carbText = CardData.gramsText(d.carb, d.carbTarget);
    d.carbColor = COLOR_CARB;

    d.emptyDay = d.intake <= 0;
    d.emptyTitle = '今天还没记录';
    d.emptyHint = '点下面拍一张';

    // 每次构造都盖一次时间戳：卡片显示的就是「这份数据算出来的时刻」
    d.appName = '轻卡记';
    d.updatedText = CardData.nowText();
  }

  /**
   * 转成 formBindingData 用的扁平对象。
   *
   * 键名与卡片页面 @LocalStorageProp 的声明一一对应，
   * 改字段名时两边同时改（不一致不会报错，只会一直显示默认值）。
   */
  toPayload(): Record<string, Object> {
    const p: Record<string, Object> = {};
    p['intake'] = this.intake;
    p['budget'] = this.budget;
    p['kcalRingPct'] = this.kcalRingPct;
    p['remainText'] = this.remainText;

    p['protein'] = this.protein;
    p['proteinTarget'] = this.proteinTarget;
    p['proteinPct'] = this.proteinPct;
    p['proteinText'] = this.proteinText;
    p['proteinColor'] = this.proteinColor;

    p['fat'] = this.fat;
    p['fatTarget'] = this.fatTarget;
    p['fatPct'] = this.fatPct;
    p['fatText'] = this.fatText;
    p['fatColor'] = this.fatColor;

    p['carb'] = this.carb;
    p['carbTarget'] = this.carbTarget;
    p['carbPct'] = this.carbPct;
    p['carbText'] = this.carbText;
    p['carbColor'] = this.carbColor;

    p['emptyDay'] = this.emptyDay;
    p['emptyTitle'] = this.emptyTitle;
    p['emptyHint'] = this.emptyHint;
    p['appName'] = this.appName;
    p['updatedText'] = this.updatedText;
    return p;
  }
}
