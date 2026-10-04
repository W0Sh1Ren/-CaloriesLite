/**
 * JSON 反序列化辅助。
 *
 * ArkTS 严格模式下没有 any，把 JSON.parse 的结果读成强类型对象需要显式取值。
 * 这里把这类样板代码收敛到一处，其余模块只管调 get* 系列函数。
 */

/** JSON.parse 结果的统一视图 */
export type JsonMap = Record<string, Object>;

/** 把字符串解析成 JsonMap，失败返回 null */
export function parseObject(text: string): JsonMap | null {
  if (text.length === 0) {
    return null;
  }
  try {
    const raw: Object = JSON.parse(text) as Object;
    if (raw === null || raw === undefined) {
      return null;
    }
    return raw as JsonMap;
  } catch (err) {
    return null;
  }
}

/** 把字符串解析成对象数组，失败或非数组返回空数组 */
export function parseArray(text: string): JsonMap[] {
  if (text.length === 0) {
    return [];
  }
  try {
    const raw: Object = JSON.parse(text) as Object;
    if (!Array.isArray(raw)) {
      return [];
    }
    const arr: Object[] = raw as Object[];
    const out: JsonMap[] = [];
    for (const el of arr) {
      if (el !== null && el !== undefined && typeof el === 'object') {
        out.push(el as JsonMap);
      }
    }
    return out;
  } catch (err) {
    return [];
  }
}

/** 读字符串字段，缺失或类型不符时返回默认值 */
export function getStr(map: JsonMap, key: string, defValue: string): string {
  const v: Object | undefined = map[key];
  return typeof v === 'string' ? v : defValue;
}

/** 读数字字段；也接受数字字符串，避免历史数据格式差异导致读不出来 */
export function getNum(map: JsonMap, key: string, defValue: number): number {
  const v: Object | undefined = map[key];
  if (typeof v === 'number') {
    return Number.isNaN(v) ? defValue : v;
  }
  if (typeof v === 'string') {
    const n: number = Number.parseFloat(v);
    return Number.isNaN(n) ? defValue : n;
  }
  return defValue;
}

/** 读布尔字段 */
export function getBool(map: JsonMap, key: string, defValue: boolean): boolean {
  const v: Object | undefined = map[key];
  return typeof v === 'boolean' ? v : defValue;
}

/** 读字符串数组字段 */
export function getStrArray(map: JsonMap, key: string): string[] {
  const v: Object | undefined = map[key];
  if (!Array.isArray(v)) {
    return [];
  }
  const arr: Object[] = v as Object[];
  const out: string[] = [];
  for (const el of arr) {
    if (typeof el === 'string') {
      out.push(el);
    }
  }
  return out;
}

/** 把枚举字符串还原成枚举值，非法值回退到默认 */
export function toEnum<T extends string>(value: string, all: T[], defValue: T): T {
  const candidate: T = value as T;
  return all.includes(candidate) ? candidate : defValue;
}

/** 生成一个够用的唯一 id：时间戳 36 进制 + 随机后缀 */
export function makeId(): string {
  const ts: string = Date.now().toString(36);
  const rnd: string = Math.floor(Math.random() * 1679616).toString(36);
  return `${ts}-${rnd}`;
}
