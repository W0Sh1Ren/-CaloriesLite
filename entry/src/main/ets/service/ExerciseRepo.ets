/**
 * 运动消耗仓库。
 *
 * 与饮食记录同构：一天一个键 + 一个日期索引，便于「今天消耗了多少」和日历视图。
 */
import { Store } from '../common/Store';
import { getNum, getStr, JsonMap, parseArray } from '../common/JsonUtil';
import { ExerciseRecord } from '../model/Types';

const KEY_INDEX = 'exercise_day_index';
const PREFIX_DAY = 'exercise_day_';

export class ExerciseRepo {

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

  private static indexWrite(days: string[]): void {
    const wrapped: JsonMap[] = days.map((d: string) => {
      const o: JsonMap = {};
      o['v'] = d;
      return o;
    });
    Store.put(KEY_INDEX, JSON.stringify(wrapped));
  }

  /** 有运动记录的所有日期，从新到旧 */
  static listDays(): string[] {
    const days: string[] = ExerciseRepo.indexRead();
    days.sort((a: string, b: string) => a < b ? 1 : (a > b ? -1 : 0));
    return days;
  }

  /** 读某天的运动记录 */
  static loadDay(dayKey: string): ExerciseRecord[] {
    const raw: string = Store.getString(PREFIX_DAY + dayKey, '[]');
    const out: ExerciseRecord[] = [];
    for (const el of parseArray(raw)) {
      out.push(new ExerciseRecord(
        getStr(el, 'id', ''),
        getStr(el, 'dayKey', dayKey),
        getNum(el, 'timestamp', 0),
        getStr(el, 'name', '运动'),
        getNum(el, 'kcal', 0),
        getNum(el, 'minutes', 0),
        getStr(el, 'origin', 'manual')
      ));
    }
    out.sort((a: ExerciseRecord, b: ExerciseRecord) => b.timestamp - a.timestamp);
    return out;
  }

  private static saveDay(dayKey: string, records: ExerciseRecord[]): void {
    Store.put(PREFIX_DAY + dayKey, JSON.stringify(records));
    const days: string[] = ExerciseRepo.indexRead().filter((d: string) => d !== dayKey);
    if (records.length > 0) {
      days.push(dayKey);
    }
    ExerciseRepo.indexWrite(days);
  }

  static add(record: ExerciseRecord): void {
    const list: ExerciseRecord[] = ExerciseRepo.loadDay(record.dayKey);
    list.push(record);
    ExerciseRepo.saveDay(record.dayKey, list);
  }

  static remove(dayKey: string, id: string): void {
    const kept: ExerciseRecord[] = ExerciseRepo.loadDay(dayKey).filter((r: ExerciseRecord) => r.id !== id);
    ExerciseRepo.saveDay(dayKey, kept);
  }

  /** 某天运动消耗合计（千卡） */
  static kcalOfDay(dayKey: string): number {
    let sum: number = 0;
    for (const r of ExerciseRepo.loadDay(dayKey)) {
      sum += r.kcal;
    }
    return Math.round(sum);
  }

  /** 指定区间的每日消耗合计 */
  static kcalByDay(days: string[]): Map<string, number> {
    const out: Map<string, number> = new Map<string, number>();
    for (const d of days) {
      out.set(d, ExerciseRepo.kcalOfDay(d));
    }
    return out;
  }

  /**
   * 供健康数据同步使用：按「日期 + 来源 + 名称」去重写入。
   * 避免每次同步都把同一批运动重复累加。
   */
  static mergeFromHealth(records: ExerciseRecord[]): number {
    let added: number = 0;
    const byDay: Map<string, ExerciseRecord[]> = new Map<string, ExerciseRecord[]>();
    for (const r of records) {
      const list: ExerciseRecord[] | undefined = byDay.get(r.dayKey);
      if (list === undefined) {
        byDay.set(r.dayKey, [r]);
      } else {
        list.push(r);
      }
    }

    byDay.forEach((incoming: ExerciseRecord[], day: string) => {
      const existing: ExerciseRecord[] = ExerciseRepo.loadDay(day);
      const keys: Set<string> = new Set<string>();
      for (const e of existing) {
        keys.add(`${e.origin}|${e.name}|${e.timestamp}`);
      }
      for (const r of incoming) {
        const key: string = `${r.origin}|${r.name}|${r.timestamp}`;
        if (!keys.has(key)) {
          existing.push(r);
          keys.add(key);
          added++;
        }
      }
      ExerciseRepo.saveDay(day, existing);
    });
    return added;
  }
}
