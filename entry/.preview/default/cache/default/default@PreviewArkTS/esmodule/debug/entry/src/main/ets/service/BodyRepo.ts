import { Store } from "@normalized:N&&&entry/src/main/ets/common/Store&";
import { getNum, getStr, parseArray } from "@normalized:N&&&entry/src/main/ets/common/JsonUtil&";
import { WeightRecord } from "@normalized:N&&&entry/src/main/ets/model/Types&";
const KEY_WEIGHT = 'weight_records';
export class BodyRepo {
    /** 全部体重记录，按日期升序 */
    static listAll(): WeightRecord[] {
        const raw: string = Store.getString(KEY_WEIGHT, '[]');
        const out: WeightRecord[] = [];
        for (const el of parseArray(raw)) {
            const dayKey: string = getStr(el, 'dayKey', '');
            if (dayKey.length === 0) {
                continue;
            }
            out.push(new WeightRecord(dayKey, getNum(el, 'weightKg', 0), getNum(el, 'timestamp', 0)));
        }
        out.sort((a: WeightRecord, b: WeightRecord) => a.dayKey < b.dayKey ? -1 : (a.dayKey > b.dayKey ? 1 : 0));
        return out;
    }
    private static saveAll(records: WeightRecord[]): void {
        Store.put(KEY_WEIGHT, JSON.stringify(records));
    }
    /** 记录某天体重；同一天覆盖 */
    static upsert(record: WeightRecord): void {
        const list: WeightRecord[] = BodyRepo.listAll();
        const next: WeightRecord[] = [];
        let replaced: boolean = false;
        for (const r of list) {
            if (r.dayKey === record.dayKey) {
                next.push(record);
                replaced = true;
            }
            else {
                next.push(r);
            }
        }
        if (!replaced) {
            next.push(record);
        }
        next.sort((a: WeightRecord, b: WeightRecord) => a.dayKey < b.dayKey ? -1 : (a.dayKey > b.dayKey ? 1 : 0));
        BodyRepo.saveAll(next);
    }
    static remove(dayKey: string): void {
        BodyRepo.saveAll(BodyRepo.listAll().filter((r: WeightRecord) => r.dayKey !== dayKey));
    }
    /** 取最近一条体重记录，没有则返回 null */
    static latest(): WeightRecord | null {
        const all: WeightRecord[] = BodyRepo.listAll();
        if (all.length === 0) {
            return null;
        }
        return all[all.length - 1];
    }
    /** 取指定日期区间的记录，含两端 */
    static range(fromDay: string, toDay: string): WeightRecord[] {
        return BodyRepo.listAll().filter((r: WeightRecord) => r.dayKey >= fromDay && r.dayKey <= toDay);
    }
    /**
     * 计算体重变化。
     * 返回 [相较上一条的变化, 相较最早一条的变化]。
     */
    static deltas(): number[] {
        const all: WeightRecord[] = BodyRepo.listAll();
        if (all.length < 2) {
            return [0, all.length === 1 ? 0 : 0];
        }
        const last: WeightRecord = all[all.length - 1];
        const prev: WeightRecord = all[all.length - 2];
        const first: WeightRecord = all[0];
        return [
            Math.round((last.weightKg - prev.weightKg) * 10) / 10,
            Math.round((last.weightKg - first.weightKg) * 10) / 10
        ];
    }
    /** 取最近的记录，用于图表展示（最多 n 条） */
    static recent(n: number): WeightRecord[] {
        const all: WeightRecord[] = BodyRepo.listAll();
        if (all.length <= n) {
            return all;
        }
        return all.slice(all.length - n);
    }
}
