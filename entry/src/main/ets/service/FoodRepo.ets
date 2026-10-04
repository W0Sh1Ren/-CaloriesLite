/**
 * 饮食记录仓库。
 *
 * 存储结构：一天一个键（food_day_YYYY-MM-DD），值是该天记录的 JSON 数组。
 * 另有一个索引键记住哪些天有数据，这样日历视图不必扫描全部键。
 */
import { Store } from '../common/Store';
import { getNum, getStr, getStrArray, JsonMap, makeId, parseArray, parseObject, toEnum } from '../common/JsonUtil';
import { FoodRecord, FoodSource, MealType } from '../model/Types';
import { MEAL_ORDER } from '../model/Enums';

const KEY_INDEX = 'food_day_index';
const PREFIX_DAY = 'food_day_';

const ALL_MEALS: MealType[] = [MealType.BREAKFAST, MealType.LUNCH, MealType.DINNER, MealType.SNACK];
const ALL_SOURCES: FoodSource[] = [FoodSource.DATABASE, FoodSource.AI, FoodSource.MANUAL];

export class FoodRepo {

  /** 读索引里的日期列表 */
  private static indexRead(): string[] {
    const raw: string = Store.getString(KEY_INDEX, '[]');
    const days: string[] = [];
    for (const el of parseArray(raw)) {
      const s: string = getStr(el, 'v', '');
      if (s.length > 0) {
        days.push(s);
      }
    }
    return days;
  }

  /** 写回索引 */
  private static indexWrite(days: string[]): void {
    const wrapped: JsonMap[] = days.map((d: string) => {
      const o: JsonMap = {};
      o['v'] = d;
      return o;
    });
    Store.put(KEY_INDEX, JSON.stringify(wrapped));
  }

  /** 取有记录的所有日期，按从新到旧排序 */
  static listDays(): string[] {
    const days: string[] = FoodRepo.indexRead();
    if (days.length === 0) {
      return FoodRepo.scanAllDays();
    }
    days.sort((a: string, b: string) => a < b ? 1 : (a > b ? -1 : 0));
    return days;
  }

  /** 兜底扫描：索引缺失时无从枚举键，返回空数组，界面上表现为「暂无记录」 */
  private static scanAllDays(): string[] {
    return [];
  }

  /** 某个日期是否已在索引里 */
  private static indexHas(day: string): boolean {
    return FoodRepo.indexRead().includes(day);
  }

  /** 把某天加入索引 */
  private static indexAdd(day: string): void {
    if (FoodRepo.indexHas(day)) {
      return;
    }
    const days: string[] = FoodRepo.indexRead();
    days.push(day);
    FoodRepo.indexWrite(days);
  }

  /** 某天没有记录时把它移出索引，保持日历干净 */
  private static indexSync(day: string, count: number): void {
    if (count > 0) {
      FoodRepo.indexAdd(day);
      return;
    }
    const days: string[] = FoodRepo.indexRead().filter((d: string) => d !== day);
    FoodRepo.indexWrite(days);
  }

  /** 读某天的全部记录，按时间正序 */
  static loadDay(dayKey: string): FoodRecord[] {
    const raw: string = Store.getString(PREFIX_DAY + dayKey, '[]');
    const out: FoodRecord[] = [];

    // 兼容两种历史写法：直接是数组，或 { records: [...] }
    let items: JsonMap[] = [];
    const direct: JsonMap[] = parseArray(raw);
    if (direct.length > 0) {
      items = direct;
    } else {
      const wrapped: JsonMap | null = parseObject(raw);
      if (wrapped !== null) {
        const inner: Object | undefined = wrapped['records'];
        if (Array.isArray(inner)) {
          const arr: Object[] = inner as Object[];
          for (const el of arr) {
            if (el !== null && el !== undefined && typeof el === 'object') {
              items.push(el as JsonMap);
            }
          }
        }
      }
    }

    for (const el of items) {
      out.push(FoodRepo.fromMap(el, dayKey));
    }
    out.sort((a: FoodRecord, b: FoodRecord) => a.timestamp - b.timestamp);
    return out;
  }

  /** 把 JSON 对象还原成 FoodRecord */
  private static fromMap(map: JsonMap, fallbackDay: string): FoodRecord {
    const r: FoodRecord = new FoodRecord(
      getStr(map, 'id', makeId()),
      getStr(map, 'dayKey', fallbackDay),
      getNum(map, 'timestamp', Date.now()),
      toEnum<MealType>(getStr(map, 'mealType', MealType.LUNCH), ALL_MEALS, MealType.LUNCH),
      getStr(map, 'name', '未命名食物'),
      getNum(map, 'grams', 0),
      getNum(map, 'kcal', 0),
      getNum(map, 'protein', 0),
      getNum(map, 'fat', 0),
      getNum(map, 'carb', 0),
      toEnum<FoodSource>(getStr(map, 'source', FoodSource.MANUAL), ALL_SOURCES, FoodSource.MANUAL),
      getStr(map, 'imageUri', ''),
      getStr(map, 'note', '')
    );

    // imageUris 是后加的字段。老记录没有，构造函数已用 imageUri 初始化过
    // 单元素列表；这里只在确实存了数组时覆盖它。
    const stored: string[] = getStrArray(map, 'imageUris');
    if (stored.length > 0) {
      r.imageUris = stored;
      // 保持两个字段一致，避免下游读到不一致的值
      r.imageUri = stored[0];
    }
    return r;
  }

  /** 覆写某天的全部记录 */
  static saveDay(dayKey: string, records: FoodRecord[]): void {
    Store.put(PREFIX_DAY + dayKey, JSON.stringify(records));
    FoodRepo.indexSync(dayKey, records.length);
  }

  /** 新增一条记录 */
  static add(record: FoodRecord): void {
    const day: string = record.dayKey;
    const list: FoodRecord[] = FoodRepo.loadDay(day);
    list.push(record);
    FoodRepo.saveDay(day, list);
  }

  /** 批量新增（一次拍照识别出多道菜） */
  static addMany(records: FoodRecord[]): void {
    if (records.length === 0) {
      return;
    }
    // 可能跨天（极少见），按天分组写回
    const byDay: Map<string, FoodRecord[]> = new Map<string, FoodRecord[]>();
    for (const r of records) {
      const list: FoodRecord[] | undefined = byDay.get(r.dayKey);
      if (list === undefined) {
        byDay.set(r.dayKey, [r]);
      } else {
        list.push(r);
      }
    }
    byDay.forEach((incoming: FoodRecord[], day: string) => {
      const list: FoodRecord[] = FoodRepo.loadDay(day);
      for (const r of incoming) {
        list.push(r);
      }
      FoodRepo.saveDay(day, list);
    });
  }

  /** 删除一条记录 */
  static remove(dayKey: string, id: string): void {
    const list: FoodRecord[] = FoodRepo.loadDay(dayKey);
    const kept: FoodRecord[] = list.filter((r: FoodRecord) => r.id !== id);
    FoodRepo.saveDay(dayKey, kept);
  }

  /** 更新一条记录（按 id 覆盖） */
  static update(record: FoodRecord): void {
    const list: FoodRecord[] = FoodRepo.loadDay(record.dayKey);
    const next: FoodRecord[] = [];
    let replaced: boolean = false;
    for (const r of list) {
      if (r.id === record.id) {
        next.push(record);
        replaced = true;
      } else {
        next.push(r);
      }
    }
    if (!replaced) {
      next.push(record);
    }
    FoodRepo.saveDay(record.dayKey, next);
  }

  /** 清空某天的记录 */
  static clearDay(dayKey: string): void {
    Store.remove(PREFIX_DAY + dayKey);
    FoodRepo.indexSync(dayKey, 0);
  }

  /** 取指定日期区间（含两端）每天的总摄入，用于日历热力与趋势 */
  static intakeByDay(days: string[]): Map<string, number> {
    const out: Map<string, number> = new Map<string, number>();
    for (const d of days) {
      let sum: number = 0;
      for (const r of FoodRepo.loadDay(d)) {
        sum += r.kcal;
      }
      out.set(d, Math.round(sum));
    }
    return out;
  }

  /** 按餐次给记录分组，界面按早/午/晚/加餐渲染 */
  static groupByMeal(records: FoodRecord[]): Map<MealType, FoodRecord[]> {
    const out: Map<MealType, FoodRecord[]> = new Map<MealType, FoodRecord[]>();
    for (const m of MEAL_ORDER) {
      out.set(m, []);
    }
    for (const r of records) {
      const list: FoodRecord[] | undefined = out.get(r.mealType);
      if (list === undefined) {
        out.set(r.mealType, [r]);
      } else {
        list.push(r);
      }
    }
    return out;
  }
}
