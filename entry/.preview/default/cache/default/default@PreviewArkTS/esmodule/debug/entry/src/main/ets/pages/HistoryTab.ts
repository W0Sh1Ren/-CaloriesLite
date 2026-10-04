if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface HistoryTab_Params {
    dayKey?: string;
    refreshTick?: number;
    viewYear?: number;
    viewMonth0?: number;
    selectedDay?: string;
    cells?: DayCell[];
    detail?: DailySummary;
    detailRecords?: FoodRecord[];
    weights?: WeightRecord[];
    exercises?: ExerciseRecord[];
    weightInput?: string;
    bottomInset?: number;
}
import promptAction from "@ohos:promptAction";
import router from "@ohos:router";
import hilog from "@ohos:hilog";
import { DayCell, CalendarHeatmap } from "@normalized:N&&&entry/src/main/ets/components/CalendarHeatmap&";
import { WeightChart } from "@normalized:N&&&entry/src/main/ets/components/WeightChart&";
import { RollingNumber } from "@normalized:N&&&entry/src/main/ets/components/RollingNumber&";
import { WeightRecord, ExerciseRecord, DailySummary } from "@normalized:N&&&entry/src/main/ets/model/Types&";
import type { MealType, FoodRecord } from "@normalized:N&&&entry/src/main/ets/model/Types&";
import { MEAL_ORDER, mealTypeLabel } from "@normalized:N&&&entry/src/main/ets/model/Enums&";
import { buildMonthGrid, friendlyDate, fromDayKey, todayKey } from "@normalized:N&&&entry/src/main/ets/common/DateUtil&";
import { makeId } from "@normalized:N&&&entry/src/main/ets/common/JsonUtil&";
import { AppState } from "@normalized:N&&&entry/src/main/ets/common/AppState&";
import { DailyService } from "@normalized:N&&&entry/src/main/ets/service/DailyService&";
import { FoodRepo } from "@normalized:N&&&entry/src/main/ets/service/FoodRepo&";
import { BodyRepo } from "@normalized:N&&&entry/src/main/ets/service/BodyRepo&";
import { ExerciseRepo } from "@normalized:N&&&entry/src/main/ets/service/ExerciseRepo&";
import { calcExerciseKcal, MET_TABLE } from "@normalized:N&&&entry/src/main/ets/service/CalorieCalc&";
import type { MetItem } from "@normalized:N&&&entry/src/main/ets/service/CalorieCalc&";
import { CARD_SHADOW, COLOR_BG, COLOR_CARD, COLOR_DIVIDER, COLOR_OK, COLOR_PRIMARY, COLOR_PRIMARY_SOFT, COLOR_TEXT, COLOR_TEXT_SUB, COLOR_WARN, DUR_SLOW, NAV_RESERVE, PAGE_PAD, RADIUS } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
const DOMAIN = 0x0000;
export class HistoryTab extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__dayKey = new SynchedPropertySimpleOneWayPU(params.dayKey, this, "dayKey");
        this.__refreshTick = new SynchedPropertySimpleOneWayPU(params.refreshTick, this, "refreshTick");
        this.__viewYear = new ObservedPropertySimplePU(0, this, "viewYear");
        this.__viewMonth0 = new ObservedPropertySimplePU(0, this, "viewMonth0");
        this.__selectedDay = new ObservedPropertySimplePU('', this, "selectedDay");
        this.__cells = new ObservedPropertyObjectPU([], this, "cells");
        this.__detail = new ObservedPropertyObjectPU(new DailySummary('', 0, 0, 0, 0, 0, 0, 0), this, "detail");
        this.__detailRecords = new ObservedPropertyObjectPU([], this, "detailRecords");
        this.__weights = new ObservedPropertyObjectPU([], this, "weights");
        this.__exercises = new ObservedPropertyObjectPU([], this, "exercises");
        this.__weightInput = new ObservedPropertySimplePU('', this, "weightInput");
        this.__bottomInset = new ObservedPropertySimplePU(0, this, "bottomInset");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: HistoryTab_Params) {
        if (params.dayKey === undefined) {
            this.__dayKey.set(todayKey());
        }
        if (params.refreshTick === undefined) {
            this.__refreshTick.set(0);
        }
        if (params.viewYear !== undefined) {
            this.viewYear = params.viewYear;
        }
        if (params.viewMonth0 !== undefined) {
            this.viewMonth0 = params.viewMonth0;
        }
        if (params.selectedDay !== undefined) {
            this.selectedDay = params.selectedDay;
        }
        if (params.cells !== undefined) {
            this.cells = params.cells;
        }
        if (params.detail !== undefined) {
            this.detail = params.detail;
        }
        if (params.detailRecords !== undefined) {
            this.detailRecords = params.detailRecords;
        }
        if (params.weights !== undefined) {
            this.weights = params.weights;
        }
        if (params.exercises !== undefined) {
            this.exercises = params.exercises;
        }
        if (params.weightInput !== undefined) {
            this.weightInput = params.weightInput;
        }
        if (params.bottomInset !== undefined) {
            this.bottomInset = params.bottomInset;
        }
    }
    updateStateVars(params: HistoryTab_Params) {
        this.__dayKey.reset(params.dayKey);
        this.__refreshTick.reset(params.refreshTick);
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__dayKey.purgeDependencyOnElmtId(rmElmtId);
        this.__refreshTick.purgeDependencyOnElmtId(rmElmtId);
        this.__viewYear.purgeDependencyOnElmtId(rmElmtId);
        this.__viewMonth0.purgeDependencyOnElmtId(rmElmtId);
        this.__selectedDay.purgeDependencyOnElmtId(rmElmtId);
        this.__cells.purgeDependencyOnElmtId(rmElmtId);
        this.__detail.purgeDependencyOnElmtId(rmElmtId);
        this.__detailRecords.purgeDependencyOnElmtId(rmElmtId);
        this.__weights.purgeDependencyOnElmtId(rmElmtId);
        this.__exercises.purgeDependencyOnElmtId(rmElmtId);
        this.__weightInput.purgeDependencyOnElmtId(rmElmtId);
        this.__bottomInset.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__dayKey.aboutToBeDeleted();
        this.__refreshTick.aboutToBeDeleted();
        this.__viewYear.aboutToBeDeleted();
        this.__viewMonth0.aboutToBeDeleted();
        this.__selectedDay.aboutToBeDeleted();
        this.__cells.aboutToBeDeleted();
        this.__detail.aboutToBeDeleted();
        this.__detailRecords.aboutToBeDeleted();
        this.__weights.aboutToBeDeleted();
        this.__exercises.aboutToBeDeleted();
        this.__weightInput.aboutToBeDeleted();
        this.__bottomInset.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    /** 主页面当前选中的日期 */
    private __dayKey: SynchedPropertySimpleOneWayPU<string>;
    get dayKey() {
        return this.__dayKey.get();
    }
    set dayKey(newValue: string) {
        this.__dayKey.set(newValue);
    }
    /** 主页面自增的刷新信号 */
    private __refreshTick: SynchedPropertySimpleOneWayPU<number>;
    get refreshTick() {
        return this.__refreshTick.get();
    }
    set refreshTick(newValue: number) {
        this.__refreshTick.set(newValue);
    }
    /** 月历当前显示的月份 */
    private __viewYear: ObservedPropertySimplePU<number>;
    get viewYear() {
        return this.__viewYear.get();
    }
    set viewYear(newValue: number) {
        this.__viewYear.set(newValue);
    }
    private __viewMonth0: ObservedPropertySimplePU<number>;
    get viewMonth0() {
        return this.__viewMonth0.get();
    }
    set viewMonth0(newValue: number) {
        this.__viewMonth0.set(newValue);
    }
    private __selectedDay: ObservedPropertySimplePU<string>;
    get selectedDay() {
        return this.__selectedDay.get();
    }
    set selectedDay(newValue: string) {
        this.__selectedDay.set(newValue);
    }
    private __cells: ObservedPropertyObjectPU<DayCell[]>;
    get cells() {
        return this.__cells.get();
    }
    set cells(newValue: DayCell[]) {
        this.__cells.set(newValue);
    }
    private __detail: ObservedPropertyObjectPU<DailySummary>;
    get detail() {
        return this.__detail.get();
    }
    set detail(newValue: DailySummary) {
        this.__detail.set(newValue);
    }
    private __detailRecords: ObservedPropertyObjectPU<FoodRecord[]>;
    get detailRecords() {
        return this.__detailRecords.get();
    }
    set detailRecords(newValue: FoodRecord[]) {
        this.__detailRecords.set(newValue);
    }
    private __weights: ObservedPropertyObjectPU<WeightRecord[]>;
    get weights() {
        return this.__weights.get();
    }
    set weights(newValue: WeightRecord[]) {
        this.__weights.set(newValue);
    }
    private __exercises: ObservedPropertyObjectPU<ExerciseRecord[]>;
    get exercises() {
        return this.__exercises.get();
    }
    set exercises(newValue: ExerciseRecord[]) {
        this.__exercises.set(newValue);
    }
    private __weightInput: ObservedPropertySimplePU<string>;
    get weightInput() {
        return this.__weightInput.get();
    }
    set weightInput(newValue: string) {
        this.__weightInput.set(newValue);
    }
    /** 底部安全区高度，由 EntryAbility 实测后写入 AppState */
    private __bottomInset: ObservedPropertySimplePU<number>;
    get bottomInset() {
        return this.__bottomInset.get();
    }
    set bottomInset(newValue: number) {
        this.__bottomInset.set(newValue);
    }
    aboutToAppear(): void {
        const now = new Date();
        this.viewYear = now.getFullYear();
        this.viewMonth0 = now.getMonth();
        this.selectedDay = this.dayKey;
        this.bottomInset = AppState.bottomInset;
        this.rebuild();
    }
    /** 主页面翻日期或恢复前台时同步过来 */
    onDidUpdate(): void {
        this.bottomInset = AppState.bottomInset;
        if (this.selectedDay !== this.dayKey && this.dayKey.length > 0) {
            this.selectedDay = this.dayKey;
            const d = new Date(fromDayKey(this.dayKey));
            this.viewYear = d.getFullYear();
            this.viewMonth0 = d.getMonth();
        }
        this.rebuild();
    }
    /** 重算月历格子与当日明细 */
    private rebuild(): void {
        this.cells = this.buildCells();
        this.detail = DailyService.summaryOf(this.selectedDay);
        this.detailRecords = FoodRepo.loadDay(this.selectedDay);
        this.weights = BodyRepo.recent(60);
        this.exercises = ExerciseRepo.loadDay(this.selectedDay);
    }
    private buildCells(): DayCell[] {
        const raw = buildMonthGrid(this.viewYear, this.viewMonth0);
        const today: string = todayKey();
        const todayTs: number = fromDayKey(today);
        const out: DayCell[] = [];
        for (const c of raw) {
            if (!c.inMonth) {
                out.push(new DayCell('', 0, false, 0, false, false, false));
                continue;
            }
            const s: DailySummary = DailyService.summaryOf(c.dayKey);
            out.push(new DayCell(c.dayKey, c.day, true, s.deficit, s.recordCount > 0, c.dayKey === today, fromDayKey(c.dayKey) > todayTs));
        }
        return out;
    }
    /** 换月 */
    private shiftMonth(delta: number): void {
        let y: number = this.viewYear;
        let m: number = this.viewMonth0 + delta;
        if (m < 0) {
            m = 11;
            y--;
        }
        else if (m > 11) {
            m = 0;
            y++;
        }
        this.viewYear = y;
        this.viewMonth0 = m;
        this.cells = this.buildCells();
    }
    /** 保存体重：同一天覆盖 */
    private saveWeight(): void {
        const v: number = Number.parseFloat(this.weightInput);
        if (Number.isNaN(v) || v < 20 || v > 400) {
            promptAction.showToast({ message: '请输入 20-400 之间的体重（公斤）' });
            return;
        }
        BodyRepo.upsert(new WeightRecord(this.selectedDay, Math.round(v * 10) / 10, Date.now()));
        this.weightInput = '';
        // 换新数组而不是原地改：@Prop 只比较引用，
        // 引用不变时子组件不会重建，Canvas 也就不会重绘
        this.weights = BodyRepo.recent(60).slice();
        // 体重会影响预算（TDEE 按体重算），推给全局让首页一起更新
        AppState.mirrorToday(DailyService.summaryOf(this.selectedDay));
        AppState.notifyDataChanged();
        promptAction.showToast({ message: '已记录体重' });
    }
    /** 弹窗选择运动项目与时长 */
    private async pickExercise(): Promise<void> {
        const buttons: promptAction.Button[] = [];
        // 弹窗按钮上限有限，只放最常用的几项 + 取消
        const quick: MetItem[] = MET_TABLE.slice(0, 6);
        for (const m of quick) {
            buttons.push({ text: m.name, color: COLOR_TEXT });
        }
        buttons.push({ text: '取消', color: COLOR_TEXT_SUB });
        try {
            const res = await promptAction.showDialog({
                title: '选择运动项目',
                message: '点击后按 30 分钟估算消耗，可再修改',
                buttons: buttons
            });
            if (res.index < 0 || res.index >= quick.length) {
                return;
            }
            const item: MetItem = quick[res.index];
            this.addExercise(item, 30);
        }
        catch (err) {
            hilog.error(DOMAIN, 'CalorieLite', 'pickExercise failed: %{public}s', JSON.stringify(err));
        }
    }
    /** 按时长写入运动记录 */
    private addExercise(item: MetItem, minutes: number): void {
        const weight: number = DailyService.latestWeight();
        const kcal: number = calcExerciseKcal(item.met, weight, minutes);
        ExerciseRepo.add(new ExerciseRecord(makeId(), this.selectedDay, Date.now(), item.name, kcal, minutes, 'manual'));
        this.exercises = ExerciseRepo.loadDay(this.selectedDay);
        this.detail = DailyService.summaryOf(this.selectedDay);
        this.cells = this.buildCells();
        promptAction.showToast({ message: `已记录 ${item.name}，消耗约 ${kcal} 千卡` });
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Scroll.create();
            Scroll.debugLine("entry/src/main/ets/pages/HistoryTab.ets(168:5)", "entry");
            Scroll.width('100%');
            Scroll.height('100%');
            Scroll.backgroundColor(COLOR_BG);
            Scroll.scrollBar(BarState.Off);
            Scroll.align(Alignment.Top);
        }, Scroll);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 14 });
            Column.debugLine("entry/src/main/ets/pages/HistoryTab.ets(169:7)", "entry");
            Column.width('100%');
            Column.padding({ left: PAGE_PAD, right: PAGE_PAD, top: 4 });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // ------------------------------------------------ 月份切换
            // Apple 风格：大标题 + 右侧一对圆形步进按钮，不再把标题夹在两键之间
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/HistoryTab.ets(172:9)", "entry");
            // ------------------------------------------------ 月份切换
            // Apple 风格：大标题 + 右侧一对圆形步进按钮，不再把标题夹在两键之间
            Row.width('100%');
            // ------------------------------------------------ 月份切换
            // Apple 风格：大标题 + 右侧一对圆形步进按钮，不再把标题夹在两键之间
            Row.padding({ left: 4, right: 4, top: 6 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(`${this.viewYear}年${this.viewMonth0 + 1}月`);
            Text.debugLine("entry/src/main/ets/pages/HistoryTab.ets(173:11)", "entry");
            Text.fontSize(26);
            Text.fontWeight(FontWeight.Bold);
            Text.fontColor(COLOR_TEXT);
            Text.layoutWeight(1);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithChild({ type: ButtonType.Circle });
            Button.debugLine("entry/src/main/ets/pages/HistoryTab.ets(179:11)", "entry");
            Button.width(36);
            Button.height(36);
            Button.backgroundColor(COLOR_CARD);
            Button.shadow(CARD_SHADOW);
            Button.onClick(() => {
                this.shiftMonth(-1);
            });
        }, Button);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('‹');
            Text.debugLine("entry/src/main/ets/pages/HistoryTab.ets(180:13)", "entry");
            Text.fontSize(20);
            Text.fontColor(COLOR_TEXT);
        }, Text);
        Text.pop();
        Button.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithChild({ type: ButtonType.Circle });
            Button.debugLine("entry/src/main/ets/pages/HistoryTab.ets(189:11)", "entry");
            Button.width(36);
            Button.height(36);
            Button.margin({ left: 8 });
            Button.backgroundColor(COLOR_CARD);
            Button.shadow(CARD_SHADOW);
            Button.onClick(() => {
                this.shiftMonth(1);
            });
        }, Button);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('›');
            Text.debugLine("entry/src/main/ets/pages/HistoryTab.ets(190:13)", "entry");
            Text.fontSize(20);
            Text.fontColor(COLOR_TEXT);
        }, Text);
        Text.pop();
        Button.pop();
        // ------------------------------------------------ 月份切换
        // Apple 风格：大标题 + 右侧一对圆形步进按钮，不再把标题夹在两键之间
        Row.pop();
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new 
                    // ------------------------------------------------ 月历
                    // 点击有记录的日期直接进当日详情页（那里能看照片和完整营养明细）
                    CalendarHeatmap(this, {
                        cells: this.cells,
                        selectedDay: this.selectedDay,
                        onSelectDay: (day: string) => {
                            this.selectedDay = day;
                            this.rebuild();
                            this.openDayDetail(day);
                        }
                    }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/HistoryTab.ets", line: 205, col: 9 });
                    ViewPU.create(componentCall);
                    let paramsLambda = () => {
                        return {
                            cells: this.cells,
                            selectedDay: this.selectedDay,
                            onSelectDay: (day: string) => {
                                this.selectedDay = day;
                                this.rebuild();
                                this.openDayDetail(day);
                            }
                        };
                    };
                    componentCall.paramsGenerator_ = paramsLambda;
                }
                else {
                    this.updateStateVarsOfChildByElmtId(elmtId, {
                        cells: this.cells,
                        selectedDay: this.selectedDay
                    });
                }
            }, { name: "CalendarHeatmap" });
        }
        // ------------------------------------------------ 当日结算
        this.dayDetailCard.bind(this)();
        // ------------------------------------------------ 体重
        this.weightCard.bind(this)();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 底部占位：悬浮导航栏浮在内容之上，没有这段留白的话
            // 体重输入框和按钮会被压在导航栏下面点不到。
            // 用实测的 bottomInset（手势条高度）再加导航栏自身高度和一点余量。
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/HistoryTab.ets(224:9)", "entry");
            // 底部占位：悬浮导航栏浮在内容之上，没有这段留白的话
            // 体重输入框和按钮会被压在导航栏下面点不到。
            // 用实测的 bottomInset（手势条高度）再加导航栏自身高度和一点余量。
            Row.height(this.bottomInset + NAV_RESERVE + 12);
        }, Row);
        // 底部占位：悬浮导航栏浮在内容之上，没有这段留白的话
        // 体重输入框和按钮会被压在导航栏下面点不到。
        // 用实测的 bottomInset（手势条高度）再加导航栏自身高度和一点余量。
        Row.pop();
        Column.pop();
        Scroll.pop();
    }
    dayDetailCard(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 10 });
            Column.debugLine("entry/src/main/ets/pages/HistoryTab.ets(238:5)", "entry");
            Column.width('100%');
            Column.padding(16);
            Column.backgroundColor(COLOR_CARD);
            Column.borderRadius(RADIUS);
            Column.shadow(CARD_SHADOW);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/HistoryTab.ets(239:7)", "entry");
            Row.width('100%');
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(friendlyDate(this.selectedDay));
            Text.debugLine("entry/src/main/ets/pages/HistoryTab.ets(240:9)", "entry");
            Text.fontSize(15);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(COLOR_TEXT);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
            Blank.debugLine("entry/src/main/ets/pages/HistoryTab.ets(245:9)", "entry");
        }, Blank);
        Blank.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 缺口做成强调徽标：这是这一天最该一眼看到的信息。
            // 数字走滚动动效：图标与文字都在变，数字直接跳会很突兀。
            Row.create({ space: 2 });
            Row.debugLine("entry/src/main/ets/pages/HistoryTab.ets(249:9)", "entry");
            // 缺口做成强调徽标：这是这一天最该一眼看到的信息。
            // 数字走滚动动效：图标与文字都在变，数字直接跳会很突兀。
            Row.padding({ left: 10, right: 10, top: 4, bottom: 4 });
            // 缺口做成强调徽标：这是这一天最该一眼看到的信息。
            // 数字走滚动动效：图标与文字都在变，数字直接跳会很突兀。
            Row.backgroundColor(this.detail.deficit < 0 ? '#1AE5533D' : '#1A2FA36B');
            // 缺口做成强调徽标：这是这一天最该一眼看到的信息。
            // 数字走滚动动效：图标与文字都在变，数字直接跳会很突兀。
            Row.borderRadius(10);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.detail.deficit < 0 ? '超出' : '缺口');
            Text.debugLine("entry/src/main/ets/pages/HistoryTab.ets(250:11)", "entry");
            Text.fontSize(14);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(this.detail.deficit < 0 ? COLOR_WARN : COLOR_OK);
        }, Text);
        Text.pop();
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new RollingNumber(this, {
                        value: Math.abs(this.detail.deficit),
                        fontSize: 14,
                        fontWeight: FontWeight.Medium,
                        textColor: this.detail.deficit < 0 ? COLOR_WARN : COLOR_OK,
                        duration: DUR_SLOW
                    }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/HistoryTab.ets", line: 254, col: 11 });
                    ViewPU.create(componentCall);
                    let paramsLambda = () => {
                        return {
                            value: Math.abs(this.detail.deficit),
                            fontSize: 14,
                            fontWeight: FontWeight.Medium,
                            textColor: this.detail.deficit < 0 ? COLOR_WARN : COLOR_OK,
                            duration: DUR_SLOW
                        };
                    };
                    componentCall.paramsGenerator_ = paramsLambda;
                }
                else {
                    this.updateStateVarsOfChildByElmtId(elmtId, {
                        value: Math.abs(this.detail.deficit),
                        fontSize: 14,
                        fontWeight: FontWeight.Medium,
                        textColor: this.detail.deficit < 0 ? COLOR_WARN : COLOR_OK,
                        duration: DUR_SLOW
                    });
                }
            }, { name: "RollingNumber" });
        }
        // 缺口做成强调徽标：这是这一天最该一眼看到的信息。
        // 数字走滚动动效：图标与文字都在变，数字直接跳会很突兀。
        Row.pop();
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 三项指标：之间加竖分隔线，比纯留白更容易读
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/HistoryTab.ets(269:7)", "entry");
            // 三项指标：之间加竖分隔线，比纯留白更容易读
            Row.width('100%');
            // 三项指标：之间加竖分隔线，比纯留白更容易读
            Row.justifyContent(FlexAlign.SpaceEvenly);
        }, Row);
        this.miniStat.bind(this)('摄入', () => this.detail.intake);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Divider.create();
            Divider.debugLine("entry/src/main/ets/pages/HistoryTab.ets(271:9)", "entry");
            Divider.vertical(true);
            Divider.height(26);
            Divider.color(COLOR_DIVIDER);
        }, Divider);
        this.miniStat.bind(this)('预算', () => this.detail.budget);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Divider.create();
            Divider.debugLine("entry/src/main/ets/pages/HistoryTab.ets(273:9)", "entry");
            Divider.vertical(true);
            Divider.height(26);
            Divider.color(COLOR_DIVIDER);
        }, Divider);
        this.miniStat.bind(this)('运动', () => this.detail.exerciseKcal);
        // 三项指标：之间加竖分隔线，比纯留白更容易读
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.detailRecords.length === 0) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Row.create({ space: 8 });
                        Row.debugLine("entry/src/main/ets/pages/HistoryTab.ets(280:9)", "entry");
                        Row.width('100%');
                        Row.padding({ top: 2 });
                    }, Row);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('这天没有饮食记录');
                        Text.debugLine("entry/src/main/ets/pages/HistoryTab.ets(281:11)", "entry");
                        Text.fontSize(13);
                        Text.fontColor(COLOR_TEXT_SUB);
                        Text.layoutWeight(1);
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        // 没有记录时把补记入口放在这里，指向更明确
                        Button.createWithChild({ type: ButtonType.Capsule });
                        Button.debugLine("entry/src/main/ets/pages/HistoryTab.ets(287:11)", "entry");
                        // 没有记录时把补记入口放在这里，指向更明确
                        Button.height(30);
                        // 没有记录时把补记入口放在这里，指向更明确
                        Button.backgroundColor(COLOR_PRIMARY_SOFT);
                        // 没有记录时把补记入口放在这里，指向更明确
                        Button.onClick(() => {
                            this.goManualAdd();
                        });
                    }, Button);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('+ 补记一笔');
                        Text.debugLine("entry/src/main/ets/pages/HistoryTab.ets(288:13)", "entry");
                        Text.fontSize(12);
                        Text.fontColor(COLOR_PRIMARY);
                    }, Text);
                    Text.pop();
                    // 没有记录时把补记入口放在这里，指向更明确
                    Button.pop();
                    Row.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Divider.create();
                        Divider.debugLine("entry/src/main/ets/pages/HistoryTab.ets(299:9)", "entry");
                        Divider.color(COLOR_DIVIDER);
                    }, Divider);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        ForEach.create();
                        const forEachItemGenFunction = _item => {
                            const meal = _item;
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                If.create();
                                if (DailyService.recordsOf(ObservedObject.GetRawObject(this.detailRecords), meal).length > 0) {
                                    this.ifElseBranchUpdateFunction(0, () => {
                                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                                            Column.create({ space: 6 });
                                            Column.debugLine("entry/src/main/ets/pages/HistoryTab.ets(303:13)", "entry");
                                            Column.width('100%');
                                            Column.alignItems(HorizontalAlign.Start);
                                        }, Column);
                                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                                            Text.create(mealTypeLabel(meal));
                                            Text.debugLine("entry/src/main/ets/pages/HistoryTab.ets(304:15)", "entry");
                                            Text.fontSize(12);
                                            Text.fontColor(COLOR_TEXT_SUB);
                                            Text.width('100%');
                                        }, Text);
                                        Text.pop();
                                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                                            ForEach.create();
                                            const forEachItemGenFunction = _item => {
                                                const r = _item;
                                                this.observeComponentCreation2((elmtId, isInitialRender) => {
                                                    Row.create({ space: 8 });
                                                    Row.debugLine("entry/src/main/ets/pages/HistoryTab.ets(310:17)", "entry");
                                                    Row.width('100%');
                                                }, Row);
                                                this.observeComponentCreation2((elmtId, isInitialRender) => {
                                                    Text.create(r.name);
                                                    Text.debugLine("entry/src/main/ets/pages/HistoryTab.ets(311:19)", "entry");
                                                    Text.fontSize(14);
                                                    Text.fontColor(COLOR_TEXT);
                                                    Text.layoutWeight(1);
                                                    Text.maxLines(1);
                                                    Text.textOverflow({ overflow: TextOverflow.Ellipsis });
                                                }, Text);
                                                Text.pop();
                                                this.observeComponentCreation2((elmtId, isInitialRender) => {
                                                    Text.create(`${r.grams}g`);
                                                    Text.debugLine("entry/src/main/ets/pages/HistoryTab.ets(318:19)", "entry");
                                                    Text.fontSize(12);
                                                    Text.fontColor(COLOR_TEXT_SUB);
                                                }, Text);
                                                Text.pop();
                                                this.observeComponentCreation2((elmtId, isInitialRender) => {
                                                    Text.create(`${r.kcal}`);
                                                    Text.debugLine("entry/src/main/ets/pages/HistoryTab.ets(322:19)", "entry");
                                                    Text.fontSize(14);
                                                    Text.fontWeight(FontWeight.Medium);
                                                    Text.fontColor(COLOR_TEXT);
                                                    Text.width(42);
                                                    Text.textAlign(TextAlign.End);
                                                }, Text);
                                                Text.pop();
                                                this.observeComponentCreation2((elmtId, isInitialRender) => {
                                                    Text.create('千卡');
                                                    Text.debugLine("entry/src/main/ets/pages/HistoryTab.ets(329:19)", "entry");
                                                    Text.fontSize(11);
                                                    Text.fontColor(COLOR_TEXT_SUB);
                                                }, Text);
                                                Text.pop();
                                                Row.pop();
                                            };
                                            this.forEachUpdateFunction(elmtId, DailyService.recordsOf(ObservedObject.GetRawObject(this.detailRecords), meal), forEachItemGenFunction, (r: FoodRecord) => r.id, false, false);
                                        }, ForEach);
                                        ForEach.pop();
                                        Column.pop();
                                    });
                                }
                                else {
                                    this.ifElseBranchUpdateFunction(1, () => {
                                    });
                                }
                            }, If);
                            If.pop();
                        };
                        this.forEachUpdateFunction(elmtId, MEAL_ORDER, forEachItemGenFunction, (meal: MealType) => `m-${meal}`, false, false);
                    }, ForEach);
                    ForEach.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        // 有记录时补记入口放到底部，不打断阅读
                        Row.create();
                        Row.debugLine("entry/src/main/ets/pages/HistoryTab.ets(342:9)", "entry");
                        // 有记录时补记入口放到底部，不打断阅读
                        Row.width('100%');
                        // 有记录时补记入口放到底部，不打断阅读
                        Row.justifyContent(FlexAlign.End);
                    }, Row);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Button.createWithChild({ type: ButtonType.Capsule });
                        Button.debugLine("entry/src/main/ets/pages/HistoryTab.ets(343:11)", "entry");
                        Button.height(30);
                        Button.backgroundColor(COLOR_PRIMARY_SOFT);
                        Button.onClick(() => {
                            this.goManualAdd();
                        });
                    }, Button);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('+ 补记');
                        Text.debugLine("entry/src/main/ets/pages/HistoryTab.ets(344:13)", "entry");
                        Text.fontSize(12);
                        Text.fontColor(COLOR_PRIMARY);
                    }, Text);
                    Text.pop();
                    Button.pop();
                    // 有记录时补记入口放到底部，不打断阅读
                    Row.pop();
                });
            }
        }, If);
        If.pop();
        Column.pop();
    }
    /** 跳转手动补记页 */
    private goManualAdd(): void {
        try {
            router.pushUrl({ url: 'pages/ManualAdd' });
        }
        catch (err) {
            hilog.error(DOMAIN, 'CalorieLite', 'goManualAdd failed');
        }
    }
    /** 进入某一天的饮食详情页 */
    private openDayDetail(day: string): void {
        try {
            router.pushUrl({
                url: 'pages/DayDetail',
                params: { dayKey: day }
            });
        }
        catch (err) {
            hilog.error(DOMAIN, 'CalorieLite', 'openDayDetail failed');
        }
    }
    /**
     * 一项指标，数字带滚动动效。
     *
     * value 用取值函数而不是直接传值：@Builder 的参数在容器构建时求值一次，
     * 之后状态变化不会重新求值，传值会表现为「切换日期后数字不动」。
     */
    miniStat(label: string, value: () => number, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 2 });
            Column.debugLine("entry/src/main/ets/pages/HistoryTab.ets(391:5)", "entry");
            Column.layoutWeight(1);
        }, Column);
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new RollingNumber(this, {
                        value: value(),
                        fontSize: 18,
                        fontWeight: FontWeight.Medium,
                        textColor: COLOR_TEXT,
                        duration: DUR_SLOW
                    }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/HistoryTab.ets", line: 392, col: 7 });
                    ViewPU.create(componentCall);
                    let paramsLambda = () => {
                        return {
                            value: value(),
                            fontSize: 18,
                            fontWeight: FontWeight.Medium,
                            textColor: COLOR_TEXT,
                            duration: DUR_SLOW
                        };
                    };
                    componentCall.paramsGenerator_ = paramsLambda;
                }
                else {
                    this.updateStateVarsOfChildByElmtId(elmtId, {
                        value: value(),
                        fontSize: 18,
                        fontWeight: FontWeight.Medium,
                        textColor: COLOR_TEXT,
                        duration: DUR_SLOW
                    });
                }
            }, { name: "RollingNumber" });
        }
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(label);
            Text.debugLine("entry/src/main/ets/pages/HistoryTab.ets(399:7)", "entry");
            Text.fontSize(11);
            Text.fontColor(COLOR_TEXT_SUB);
        }, Text);
        Text.pop();
        Column.pop();
    }
    /**
     * 体重趋势 + 输入。
     *
     * 间距压到 10：这两块本来就属于同一件事，之前 12 的间距加上卡片外边距
     * 让页面显得松散。
     */
    weightCard(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 10 });
            Column.debugLine("entry/src/main/ets/pages/HistoryTab.ets(414:5)", "entry");
            Column.width('100%');
            Column.padding(16);
            Column.backgroundColor(COLOR_CARD);
            Column.borderRadius(RADIUS);
            Column.shadow(CARD_SHADOW);
        }, Column);
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new WeightChart(this, { records: this.weights }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/HistoryTab.ets", line: 415, col: 7 });
                    ViewPU.create(componentCall);
                    let paramsLambda = () => {
                        return {
                            records: this.weights
                        };
                    };
                    componentCall.paramsGenerator_ = paramsLambda;
                }
                else {
                    this.updateStateVarsOfChildByElmtId(elmtId, {
                        records: this.weights
                    });
                }
            }, { name: "WeightChart" });
        }
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 10 });
            Row.debugLine("entry/src/main/ets/pages/HistoryTab.ets(417:7)", "entry");
            Row.width('100%');
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            TextInput.create({ text: this.weightInput, placeholder: '输入体重（公斤）' });
            TextInput.debugLine("entry/src/main/ets/pages/HistoryTab.ets(418:9)", "entry");
            TextInput.type(InputType.NUMBER_DECIMAL);
            TextInput.height(42);
            TextInput.layoutWeight(1);
            TextInput.backgroundColor(COLOR_BG);
            TextInput.borderRadius(10);
            TextInput.onChange((v: string) => {
                this.weightInput = v;
            });
        }, TextInput);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithChild({ type: ButtonType.Capsule });
            Button.debugLine("entry/src/main/ets/pages/HistoryTab.ets(428:9)", "entry");
            Button.height(42);
            Button.backgroundColor(COLOR_PRIMARY);
            Button.onClick(() => {
                this.saveWeight();
            });
        }, Button);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('记录');
            Text.debugLine("entry/src/main/ets/pages/HistoryTab.ets(429:11)", "entry");
            Text.fontSize(14);
            Text.fontColor(Color.White);
        }, Text);
        Text.pop();
        Button.pop();
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(`记录到 ${this.selectedDay}`);
            Text.debugLine("entry/src/main/ets/pages/HistoryTab.ets(439:7)", "entry");
            Text.fontSize(11);
            Text.fontColor(COLOR_TEXT_SUB);
            Text.width('100%');
        }, Text);
        Text.pop();
        Column.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
    public __resetStateVarsOnReuse__Internal(params: Object): void {
    }
}
