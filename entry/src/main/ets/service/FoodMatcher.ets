/**
 * 食物表检索。
 *
 * 「先查表、查不到再问 AI」的第一环：把 AI 识别出的食物名或用户输入
 * 匹配到内置食物表，命中就用表里的精确数值，避免 AI 随口报数字。
 */
import { FOOD_DATABASE } from '../model/FoodDatabase';
import { FoodDraft, FoodItem, FoodSource } from '../model/Types';

export class MatchResult {
  item: FoodItem;
  /** 0-1，越高越可信 */
  score: number;

  constructor(item: FoodItem, score: number) {
    this.item = item;
    this.score = score;
  }
}

/** 去掉空格、括号内容与常见修饰词，提高匹配率 */
function normalize(raw: string): string {
  let s: string = raw.trim();
  // 去掉括号及其中内容，如「鸡蛋(全蛋)」→「鸡蛋」
  s = s.replace(/[（(][^）)]*[）)]/g, '');
  // 去掉份量描述
  s = s.replace(/(一份|一小份|一大份|适量|少许|半个|一个|两个|一碗|一杯|一盘)/g, '');
  // 去掉空白
  s = s.replace(/\s+/g, '');
  return s;
}

/** 把名称按分隔符拆成候选词 */
function splitParts(raw: string): string[] {
  return raw.split(/[|｜、,，+＋\/]/).map((p: string) => p.trim()).filter((p: string) => p.length > 0);
}

/**
 * 计算两个字符串的匹配分数（0-1）。
 * 用最长公共子序列长度除以较长串长度，对中文短词够用且无需引入依赖。
 */
function similarity(a: string, b: string): number {
  if (a.length === 0 || b.length === 0) {
    return 0;
  }
  if (a === b) {
    return 1;
  }
  if (a.includes(b) || b.includes(a)) {
    const shorter: number = Math.min(a.length, b.length);
    const longer: number = Math.max(a.length, b.length);
    return 0.7 + 0.3 * (shorter / longer);
  }

  // LCS 动态规划，滚动数组省内存
  const m: number = a.length;
  const n: number = b.length;
  let prev: number[] = new Array<number>(n + 1).fill(0);
  let cur: number[] = new Array<number>(n + 1).fill(0);
  for (let i = 1; i <= m; i++) {
    for (let j = 1; j <= n; j++) {
      if (a.charAt(i - 1) === b.charAt(j - 1)) {
        cur[j] = prev[j - 1] + 1;
      } else {
        cur[j] = Math.max(prev[j], cur[j - 1]);
      }
    }
    const swap: number[] = prev;
    prev = cur;
    cur = swap;
    cur.fill(0);
  }
  return prev[n] / Math.max(m, n);
}

/** 在整张表里找出与 query 最匹配的条目，低于阈值返回 null */
export function findBestMatch(query: string, threshold: number = 0.45): MatchResult | null {
  const q: string = normalize(query);
  if (q.length === 0) {
    return null;
  }

  let best: FoodItem | null = null;
  let bestScore: number = 0;

  for (const item of FOOD_DATABASE) {
    // 候选词：正式名 + 别名拆分
    const candidates: string[] = [item.name].concat(splitParts(item.alias));
    let itemScore: number = 0;
    for (const c of candidates) {
      const cn: string = normalize(c);
      if (cn.length === 0) {
        continue;
      }
      const s: number = similarity(q, cn);
      if (s > itemScore) {
        itemScore = s;
      }
    }
    if (itemScore > bestScore) {
      bestScore = itemScore;
      best = item;
    }
  }

  if (best === null || bestScore < threshold) {
    return null;
  }
  return new MatchResult(best, bestScore);
}

/** 按关键字做子串检索，供「手动搜索食物」列表用 */
export function searchFoods(keyword: string, limit: number = 40): FoodItem[] {
  const q: string = normalize(keyword);
  if (q.length === 0) {
    return FOOD_DATABASE.slice(0, limit);
  }
  const hits: FoodItem[] = [];
  for (const item of FOOD_DATABASE) {
    if (normalize(item.name).includes(q) || normalize(item.alias).includes(q)) {
      hits.push(item);
    }
  }
  return hits.slice(0, limit);
}

/** 按分类取条目 */
export function foodsByCategory(category: string): FoodItem[] {
  return FOOD_DATABASE.filter((item: FoodItem) => item.category === category);
}

/**
 * 从中文份量描述里猜克重。
 *
 * 支持「一碗」「两碗」「半碗」「200克」「3两」这类写法，猜不到就返回 fallback。
 * 注意：这是估算，界面上始终允许用户手动改克重。
 */
export function estimateGrams(text: string, fallback: number): number {
  if (text.length === 0) {
    return fallback;
  }

  // 明确的克重：200克 / 200g / 200G
  const gramMatch: RegExpMatchArray | null = text.match(/(\d+(?:\.\d+)?)\s*(?:克|g|G|ml|ML|毫升)/);
  if (gramMatch !== null) {
    const v: number = Number.parseFloat(gramMatch[1]);
    if (!Number.isNaN(v) && v > 0 && v < 5000) {
      return Math.round(v);
    }
  }

  // 两：1两 = 50 克
  const liangMatch: RegExpMatchArray | null = text.match(/(\d+(?:\.\d+)?)\s*两/);
  if (liangMatch !== null) {
    const v: number = Number.parseFloat(liangMatch[1]);
    if (!Number.isNaN(v) && v > 0) {
      return Math.round(v * 50);
    }
  }

  // 斤：1斤 = 500 克
  const jinMatch: RegExpMatchArray | null = text.match(/(\d+(?:\.\d+)?)\s*斤/);
  if (jinMatch !== null) {
    const v: number = Number.parseFloat(jinMatch[1]);
    if (!Number.isNaN(v) && v > 0 && v < 20) {
      return Math.round(v * 500);
    }
  }

  // 中文数词 + 容器
  const cnNum: Map<string, number> = new Map<string, number>();
  cnNum.set('半', 0.5);
  cnNum.set('一', 1);
  cnNum.set('两', 2);
  cnNum.set('二', 2);
  cnNum.set('三', 3);
  cnNum.set('四', 4);
  cnNum.set('五', 5);
  cnNum.set('六', 6);

  const unitMatch: RegExpMatchArray | null = text.match(/([半一二两三四五六\d]+)\s*(碗|杯|盘|份|个|只|块|片|根|勺|瓶|罐|袋|盒)/);
  if (unitMatch !== null) {
    const numText: string = unitMatch[1];
    const unit: string = unitMatch[2];
    let count: number = Number.parseFloat(numText);
    if (Number.isNaN(count)) {
      const mapped: number | undefined = cnNum.get(numText);
      count = mapped === undefined ? 1 : mapped;
    }
    if (count <= 0 || count > 10) {
      count = 1;
    }

    // 不同容器的基准克重，再乘上食物本身的默认份量做校正
    let unitGrams: number = fallback;
    switch (unit) {
      case '碗':
        unitGrams = fallback < 120 ? 250 : fallback;
        break;
      case '杯':
        unitGrams = 250;
        break;
      case '盘':
      case '份':
        unitGrams = fallback;
        break;
      case '瓶':
      case '罐':
        unitGrams = 330;
        break;
      case '盒':
      case '袋':
        unitGrams = 100;
        break;
      case '勺':
        unitGrams = 15;
        break;
      default:
        unitGrams = fallback;
        break;
    }
    return Math.round(unitGrams * count);
  }

  return fallback;
}

/**
 * 把一个「食物名 + 份量描述」解析成可提交的草稿。
 *
 * 命中食物表时用表内数值按克重折算；未命中返回 null，交由 AI 估算。
 */
export function draftFromDatabase(name: string, amountText: string): FoodDraft | null {
  const m: MatchResult | null = findBestMatch(name);
  if (m === null) {
    return null;
  }
  const item: FoodItem = m.item;
  const grams: number = estimateGrams(amountText, item.defaultGrams);
  const ratio: number = grams / 100;
  const kcal: number = Math.round(item.kcalPer100g * ratio);

  const note: string = amountText.length > 0
    ? `命中食物表「${item.name}」，按 ${grams} 克折算`
    : `命中食物表「${item.name}」，按默认份量 ${grams} 克折算`;

  return new FoodDraft(
    item.name,
    grams,
    kcal,
    round1(item.proteinPer100g * ratio),
    round1(item.fatPer100g * ratio),
    round1(item.carbPer100g * ratio),
    m.score >= 0.9 ? 'high' : (m.score >= 0.6 ? 'medium' : 'low'),
    FoodSource.DATABASE,
    note
  );
}

/** 手动录入时，按食物表条目和克重生成草稿 */
export function draftFromItem(item: FoodItem, grams: number): FoodDraft {
  const ratio: number = grams / 100;
  return new FoodDraft(
    item.name,
    grams,
    Math.round(item.kcalPer100g * ratio),
    round1(item.proteinPer100g * ratio),
    round1(item.fatPer100g * ratio),
    round1(item.carbPer100g * ratio),
    'high',
    FoodSource.DATABASE,
    '来自食物表'
  );
}

function round1(v: number): number {
  return Math.round(v * 10) / 10;
}
