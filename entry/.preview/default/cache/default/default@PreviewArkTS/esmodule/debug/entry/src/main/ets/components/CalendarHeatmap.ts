if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface CalendarHeatmap_Params {
    cells?: DayCell[];
    selectedDay?: string;
    onSelectDay?: (dayKey: string) => void;
}
import { COLOR_CARD, COLOR_DIVIDER, COLOR_OK, COLOR_PRIMARY, COLOR_PRIMARY_SOFT, COLOR_TEXT, COLOR_TEXT_SUB, COLOR_WARN, CARD_SHADOW, RADIUS } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
/** 单个格子的展示数据 */
export class DayCell {
    dayKey: string = '';
    day: number = 0;
    inMonth: boolean = false;
    deficit: number = 0;
    hasRecord: boolean = false;
    isToday: boolean = false;
    isFuture: boolean = false;
    constructor(dayKey: string, day: number, inMonth: boolean, deficit: number, hasRecord: boolean, isToday: boolean, isFuture: boolean) {
        this.dayKey = dayKey;
        this.day = day;
        this.inMonth = inMonth;
        this.deficit = deficit;
        this.hasRecord = hasRecord;
        this.isToday = isToday;
        this.isFuture = isFuture;
    }
}
const WEEK_HEADER: string[] = ['日', '一', '二', '三', '四', '五', '六'];
const ROW_INDEXES: number[] = [0, 1, 2, 3, 4, 5];
const COL_INDEXES: number[] = [0, 1, 2, 3, 4, 5, 6];
/**
 * 一格的高度。
 *
 * 只包住「日号圆 34 + 状态点 5」并留一点呼吸量即可。设太大时
 * 6 行会撑出一大片空白，日历看着松散（之前踩过：设成 46 时
 * 每行实际占到 150px）。
 */
const CELL_HEIGHT: number = 40;
/** 全透明色。写成字符串而不是 Color.Transparent，保证辅助函数返回类型一致 */
const TRANSPARENT: string = '#00000000';
export class CalendarHeatmap extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__cells = new SynchedPropertyObjectOneWayPU(params.cells, this, "cells");
        this.__selectedDay = new SynchedPropertySimpleOneWayPU(params.selectedDay, this, "selectedDay");
        this.onSelectDay = () => {
        };
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: CalendarHeatmap_Params) {
        if (params.cells === undefined) {
            this.__cells.set([]);
        }
        if (params.selectedDay === undefined) {
            this.__selectedDay.set('');
        }
        if (params.onSelectDay !== undefined) {
            this.onSelectDay = params.onSelectDay;
        }
    }
    updateStateVars(params: CalendarHeatmap_Params) {
        this.__cells.reset(params.cells);
        this.__selectedDay.reset(params.selectedDay);
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__cells.purgeDependencyOnElmtId(rmElmtId);
        this.__selectedDay.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__cells.aboutToBeDeleted();
        this.__selectedDay.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    /** 42 个格子，由父组件算好 */
    private __cells: SynchedPropertySimpleOneWayPU<DayCell[]>;
    get cells() {
        return this.__cells.get();
    }
    set cells(newValue: DayCell[]) {
        this.__cells.set(newValue);
    }
    private __selectedDay: SynchedPropertySimpleOneWayPU<string>;
    get selectedDay() {
        return this.__selectedDay.get();
    }
    set selectedDay(newValue: string) {
        this.__selectedDay.set(newValue);
    }
    private onSelectDay: (dayKey: string) => void;
    /** 状态点的颜色：按缺口正负分级 */
    private dotColor(data: DayCell): string {
        if (!data.hasRecord) {
            return COLOR_DIVIDER;
        }
        if (data.deficit < 0) {
            return COLOR_WARN;
        }
        if (data.deficit <= 150) {
            return COLOR_PRIMARY;
        }
        return COLOR_OK;
    }
    /** 按下标取格子，越界返回占位，避免渲染期抛异常 */
    private cellAt(index: number): DayCell {
        if (index < 0 || index >= this.cells.length) {
            return new DayCell('', 0, false, 0, false, false, false);
        }
        return this.cells[index];
    }
    /** 选中态的底色。统一用字符串色值，避免 Color 枚举与 string 混用导致类型不匹配 */
    private cellBg(data: DayCell): string {
        if (!data.inMonth || data.isFuture) {
            return TRANSPARENT;
        }
        if (this.selectedDay === data.dayKey) {
            return COLOR_PRIMARY;
        }
        if (data.isToday) {
            return COLOR_PRIMARY_SOFT;
        }
        return TRANSPARENT;
    }
    /** 选中态的字色 */
    private cellTextColor(data: DayCell): string {
        if (!data.inMonth || data.isFuture) {
            return COLOR_DIVIDER;
        }
        if (this.selectedDay === data.dayKey) {
            return '#FFFFFF';
        }
        return data.isToday ? COLOR_PRIMARY : COLOR_TEXT;
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 2 });
            Column.debugLine("entry/src/main/ets/components/CalendarHeatmap.ets(109:5)", "entry");
            Column.width('100%');
            Column.padding({ left: 8, right: 8, top: 14, bottom: 14 });
            Column.backgroundColor(COLOR_CARD);
            Column.borderRadius(RADIUS);
            Column.shadow(CARD_SHADOW);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 星期表头：与下面的单元格共用同一套等宽栅格，保证对齐
            Row.create();
            Row.debugLine("entry/src/main/ets/components/CalendarHeatmap.ets(111:7)", "entry");
            // 星期表头：与下面的单元格共用同一套等宽栅格，保证对齐
            Row.width('100%');
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            ForEach.create();
            const forEachItemGenFunction = _item => {
                const w = _item;
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Text.create(w);
                    Text.debugLine("entry/src/main/ets/components/CalendarHeatmap.ets(113:11)", "entry");
                    Text.fontSize(11);
                    Text.fontColor(COLOR_TEXT_SUB);
                    Text.textAlign(TextAlign.Center);
                    Text.layoutWeight(1);
                    Text.height(28);
                }, Text);
                Text.pop();
            };
            this.forEachUpdateFunction(elmtId, WEEK_HEADER, forEachItemGenFunction, (w: string) => w, false, false);
        }, ForEach);
        ForEach.pop();
        // 星期表头：与下面的单元格共用同一套等宽栅格，保证对齐
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 6 行 × 7 列。
            // 行高必须显式指定：只给格子设高度、行用默认约束时，
            // 纵向会被拉伸到填满可用空间，导致日历出现大片空白（踩过）。
            ForEach.create();
            const forEachItemGenFunction = _item => {
                const rowIndex = _item;
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Row.create();
                    Row.debugLine("entry/src/main/ets/components/CalendarHeatmap.ets(127:9)", "entry");
                    Row.width('100%');
                    Row.height(CELL_HEIGHT);
                }, Row);
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    ForEach.create();
                    const forEachItemGenFunction = _item => {
                        const colIndex = _item;
                        this.dayCell.bind(this)(this.cellAt(rowIndex * 7 + colIndex));
                    };
                    this.forEachUpdateFunction(elmtId, COL_INDEXES, forEachItemGenFunction, (colIndex: number) => `c${rowIndex}-${colIndex}`, false, false);
                }, ForEach);
                ForEach.pop();
                Row.pop();
            };
            this.forEachUpdateFunction(elmtId, ROW_INDEXES, forEachItemGenFunction, (rowIndex: number) => `r${rowIndex}`, false, false);
        }, ForEach);
        // 6 行 × 7 列。
        // 行高必须显式指定：只给格子设高度、行用默认约束时，
        // 纵向会被拉伸到填满可用空间，导致日历出现大片空白（踩过）。
        ForEach.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 图例
            Row.create({ space: 14 });
            Row.debugLine("entry/src/main/ets/components/CalendarHeatmap.ets(137:7)", "entry");
            // 图例
            Row.width('100%');
            // 图例
            Row.justifyContent(FlexAlign.Center);
            // 图例
            Row.margin({ top: 10 });
        }, Row);
        this.legend.bind(this)(COLOR_OK, '有缺口');
        this.legend.bind(this)(COLOR_PRIMARY, '基本持平');
        this.legend.bind(this)(COLOR_WARN, '超标');
        this.legend.bind(this)(COLOR_DIVIDER, '未记录');
        // 图例
        Row.pop();
        Column.pop();
    }
    dayCell(data: DayCell, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 宽高都显式给：只靠 layoutWeight + 父容器约束时，
            // ArkUI 会把格子沿主轴方向拉伸，日历就会出现大片空白。
            Column.create();
            Column.debugLine("entry/src/main/ets/components/CalendarHeatmap.ets(158:5)", "entry");
            // 宽高都显式给：只靠 layoutWeight + 父容器约束时，
            // ArkUI 会把格子沿主轴方向拉伸，日历就会出现大片空白。
            Column.layoutWeight(1);
            // 宽高都显式给：只靠 layoutWeight + 父容器约束时，
            // ArkUI 会把格子沿主轴方向拉伸，日历就会出现大片空白。
            Column.height(CELL_HEIGHT);
            // 宽高都显式给：只靠 layoutWeight + 父容器约束时，
            // ArkUI 会把格子沿主轴方向拉伸，日历就会出现大片空白。
            Column.justifyContent(FlexAlign.Center);
            // 宽高都显式给：只靠 layoutWeight + 父容器约束时，
            // ArkUI 会把格子沿主轴方向拉伸，日历就会出现大片空白。
            Column.onClick(() => {
                if (data.inMonth && !data.isFuture) {
                    this.onSelectDay(data.dayKey);
                }
            });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (data.inMonth) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Stack.create();
                        Stack.debugLine("entry/src/main/ets/components/CalendarHeatmap.ets(160:9)", "entry");
                        Stack.width(32);
                        Stack.height(32);
                    }, Stack);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        // 选中/今天底色：圆形而非方块，更接近 Apple 的日历
                        Row.create();
                        Row.debugLine("entry/src/main/ets/components/CalendarHeatmap.ets(162:11)", "entry");
                        // 选中/今天底色：圆形而非方块，更接近 Apple 的日历
                        Row.width(32);
                        // 选中/今天底色：圆形而非方块，更接近 Apple 的日历
                        Row.height(32);
                        // 选中/今天底色：圆形而非方块，更接近 Apple 的日历
                        Row.backgroundColor(this.cellBg(data));
                        // 选中/今天底色：圆形而非方块，更接近 Apple 的日历
                        Row.borderRadius(16);
                    }, Row);
                    // 选中/今天底色：圆形而非方块，更接近 Apple 的日历
                    Row.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(`${data.day}`);
                        Text.debugLine("entry/src/main/ets/components/CalendarHeatmap.ets(168:11)", "entry");
                        Text.fontSize(15);
                        Text.fontWeight(this.selectedDay === data.dayKey || data.isToday ? FontWeight.Medium : FontWeight.Normal);
                        Text.fontColor(this.cellTextColor(data));
                    }, Text);
                    Text.pop();
                    Stack.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        // 状态点：有记录才画，没记录留空占位保持行高一致
                        Row.create();
                        Row.debugLine("entry/src/main/ets/components/CalendarHeatmap.ets(177:9)", "entry");
                        // 状态点：有记录才画，没记录留空占位保持行高一致
                        Row.width(5);
                        // 状态点：有记录才画，没记录留空占位保持行高一致
                        Row.height(5);
                        // 状态点：有记录才画，没记录留空占位保持行高一致
                        Row.backgroundColor(this.selectedDay === data.dayKey ? TRANSPARENT : this.dotColor(data));
                        // 状态点：有记录才画，没记录留空占位保持行高一致
                        Row.borderRadius(3);
                        // 状态点：有记录才画，没记录留空占位保持行高一致
                        Row.margin({ top: 2 });
                    }, Row);
                    // 状态点：有记录才画，没记录留空占位保持行高一致
                    Row.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        // 宽高都显式给：只靠 layoutWeight + 父容器约束时，
        // ArkUI 会把格子沿主轴方向拉伸，日历就会出现大片空白。
        Column.pop();
    }
    legend(color: string, label: string, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 5 });
            Row.debugLine("entry/src/main/ets/components/CalendarHeatmap.ets(197:5)", "entry");
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.debugLine("entry/src/main/ets/components/CalendarHeatmap.ets(198:7)", "entry");
            Row.width(6);
            Row.height(6);
            Row.backgroundColor(color);
            Row.borderRadius(3);
        }, Row);
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(label);
            Text.debugLine("entry/src/main/ets/components/CalendarHeatmap.ets(203:7)", "entry");
            Text.fontSize(11);
            Text.fontColor(COLOR_TEXT_SUB);
        }, Text);
        Text.pop();
        Row.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
    public __resetStateVarsOnReuse__Internal(params: Object): void {
    }
}
