/**
 * 日期工具。
 *
 * 全应用统一用 dayKey（YYYY-MM-DD 本地时区）作为「一天」的主键，
 * 避免跨时区/夏令时导致的记录错位。
 */

function pad2(n: number): string {
  return n < 10 ? `0${n}` : `${n}`;
}

/** 把时间戳转成本地时区的 YYYY-MM-DD */
export function toDayKey(timestamp: number): string {
  const d = new Date(timestamp);
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
}

/** 今天的 dayKey */
export function todayKey(): string {
  return toDayKey(Date.now());
}

/** 把 YYYY-MM-DD 解析回当天 00:00 的时间戳 */
export function fromDayKey(dayKey: string): number {
  const parts: string[] = dayKey.split('-');
  if (parts.length !== 3) {
    return Date.now();
  }
  const y: number = Number.parseInt(parts[0], 10);
  const m: number = Number.parseInt(parts[1], 10);
  const d: number = Number.parseInt(parts[2], 10);
  if (Number.isNaN(y) || Number.isNaN(m) || Number.isNaN(d)) {
    return Date.now();
  }
  return new Date(y, m - 1, d, 0, 0, 0, 0).getTime();
}

/** 在 dayKey 上加减天数，返回新的 dayKey */
export function shiftDay(dayKey: string, deltaDays: number): string {
  const base: number = fromDayKey(dayKey);
  const d = new Date(base);
  d.setDate(d.getDate() + deltaDays);
  return toDayKey(d.getTime());
}

/** 判断是否是今天 */
export function isToday(dayKey: string): boolean {
  return dayKey === todayKey();
}

const WEEKDAY_CN: string[] = ['日', '一', '二', '三', '四', '五', '六'];

/** 返回「10月8日 周三」这样的友好文案 */
export function friendlyDate(dayKey: string): string {
  const d = new Date(fromDayKey(dayKey));
  return `${d.getMonth() + 1}月${d.getDate()}日 周${WEEKDAY_CN[d.getDay()]}`;
}

/** 返回「2026年10月」这样的月份标题 */
export function monthTitle(year: number, month0: number): string {
  return `${year}年${month0 + 1}月`;
}

export class MonthCell {
  /** 该格对应的 dayKey；补白格为空字符串 */
  dayKey: string = '';
  /** 日号，补白格为 0 */
  day: number = 0;
  /** 是否是当月内的有效格子 */
  inMonth: boolean = false;

  constructor(dayKey: string, day: number, inMonth: boolean) {
    this.dayKey = dayKey;
    this.day = day;
    this.inMonth = inMonth;
  }
}

/**
 * 生成某个月的日历格子（周日起始，6 行 × 7 列 = 42 格）。
 * 补白格用空 dayKey 占位，保证网格永远整齐。
 */
export function buildMonthGrid(year: number, month0: number): MonthCell[] {
  const first = new Date(year, month0, 1);
  const firstWeekday: number = first.getDay();
  const daysInMonth = new Date(year, month0 + 1, 0).getDate();

  const cells: MonthCell[] = [];
  for (let i = 0; i < firstWeekday; i++) {
    cells.push(new MonthCell('', 0, false));
  }
  for (let d = 1; d <= daysInMonth; d++) {
    const key = `${year}-${pad2(month0 + 1)}-${pad2(d)}`;
    cells.push(new MonthCell(key, d, true));
  }
  while (cells.length < 42) {
    cells.push(new MonthCell('', 0, false));
  }
  return cells;
}

/** 取时间戳对应的小时数（0-23） */
export function hourOf(timestamp: number): number {
  return new Date(timestamp).getHours();
}

/** 取时间戳对应的 HH:mm */
export function timeLabel(timestamp: number): string {
  const d = new Date(timestamp);
  return `${pad2(d.getHours())}:${pad2(d.getMinutes())}`;
}

/** 判断 dayKey 是否合法（YYYY-MM-DD 且日期真实存在） */
export function isValidDayKey(dayKey: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(dayKey)) {
    return false;
  }
  const d = new Date(fromDayKey(dayKey));
  return toDayKey(d.getTime()) === dayKey;
}
