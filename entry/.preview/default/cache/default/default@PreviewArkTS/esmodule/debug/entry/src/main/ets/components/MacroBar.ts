if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface MacroBar_Params {
    protein?: number;
    fat?: number;
    carb?: number;
    carbTarget?: number;
    proteinTarget?: number;
    fatTarget?: number;
    frame?: number;
    tickers?: MacroTicker[];
}
import { CARD_SHADOW, COLOR_CARB, COLOR_CARD, COLOR_DIVIDER, COLOR_FAT, COLOR_PROTEIN, COLOR_TEXT, COLOR_TEXT_SUB, DUR_SLOW, RADIUS } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
/** 单项数据 */
class MacroItem {
    label: string;
    grams: number;
    target: number;
    color: string;
    constructor(label: string, grams: number, target: number, color: string) {
        this.label = label;
        this.grams = grams;
        this.target = target;
        this.color = color;
    }
    /** 完成度百分比，封顶 100 以免条形溢出容器 */
    percent(): number {
        if (this.target <= 0) {
            return 0;
        }
        const p: number = this.grams / this.target * 100;
        return Math.max(0, Math.min(100, p));
    }
}
/** 每帧同时驱动数字与条形 */
class MacroTicker {
    /** 当前显示的克数 */
    shownGrams: number = 0;
    /** 当前显示的百分比 */
    shownPct: number = 0;
    private timer: number = -1;
    private fromG: number = 0;
    private toG: number = 0;
    private fromP: number = 0;
    private toP: number = 0;
    private startedAt: number = 0;
    private duration: number = 420;
    stop(): void {
        if (this.timer !== -1) {
            clearInterval(this.timer);
            this.timer = -1;
        }
    }
    /** 停掉动画并立即落到目标值 */
    snap(grams: number, pct: number): void {
        this.stop();
        this.shownGrams = grams;
        this.shownPct = pct;
    }
    /**
     * 平滑推进到目标。
     *
     * @param apply 每帧回调，让调用方把值写进 @State 触发重建
     */
    to(grams: number, pct: number, apply: () => void, duration: number = 420): void {
        if (Math.abs(grams - this.shownGrams) < 0.05 && Math.abs(pct - this.shownPct) < 0.05) {
            this.snap(grams, pct);
            apply();
            return;
        }
        this.stop();
        this.fromG = this.shownGrams;
        this.toG = grams;
        this.fromP = this.shownPct;
        this.toP = pct;
        this.startedAt = Date.now();
        this.duration = duration;
        this.timer = setInterval(() => {
            const t: number = this.duration <= 0 ? 1 : Math.min(1, (Date.now() - this.startedAt) / this.duration);
            // easeOutCubic：起步快、收尾缓，与应用其它动效节奏一致
            const eased: number = 1 - Math.pow(1 - t, 3);
            this.shownGrams = this.fromG + (this.toG - this.fromG) * eased;
            this.shownPct = this.fromP + (this.toP - this.fromP) * eased;
            apply();
            if (t >= 1) {
                this.snap(grams, pct);
                apply();
            }
        }, 16);
    }
}
export class MacroBar extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__protein = new SynchedPropertySimpleOneWayPU(params.protein, this, "protein");
        this.__fat = new SynchedPropertySimpleOneWayPU(params.fat, this, "fat");
        this.__carb = new SynchedPropertySimpleOneWayPU(params.carb, this, "carb");
        this.__carbTarget = new SynchedPropertySimpleOneWayPU(params.carbTarget, this, "carbTarget");
        this.__proteinTarget = new SynchedPropertySimpleOneWayPU(params.proteinTarget, this, "proteinTarget");
        this.__fatTarget = new SynchedPropertySimpleOneWayPU(params.fatTarget, this, "fatTarget");
        this.__frame = new ObservedPropertySimplePU(0, this, "frame");
        this.tickers = [new MacroTicker(), new MacroTicker(), new MacroTicker()];
        this.setInitiallyProvidedValue(params);
        this.declareWatch("protein", this.onDataChange);
        this.declareWatch("fat", this.onDataChange);
        this.declareWatch("carb", this.onDataChange);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: MacroBar_Params) {
        if (params.protein === undefined) {
            this.__protein.set(0);
        }
        if (params.fat === undefined) {
            this.__fat.set(0);
        }
        if (params.carb === undefined) {
            this.__carb.set(0);
        }
        if (params.carbTarget === undefined) {
            this.__carbTarget.set(0);
        }
        if (params.proteinTarget === undefined) {
            this.__proteinTarget.set(0);
        }
        if (params.fatTarget === undefined) {
            this.__fatTarget.set(0);
        }
        if (params.frame !== undefined) {
            this.frame = params.frame;
        }
        if (params.tickers !== undefined) {
            this.tickers = params.tickers;
        }
    }
    updateStateVars(params: MacroBar_Params) {
        this.__protein.reset(params.protein);
        this.__fat.reset(params.fat);
        this.__carb.reset(params.carb);
        this.__carbTarget.reset(params.carbTarget);
        this.__proteinTarget.reset(params.proteinTarget);
        this.__fatTarget.reset(params.fatTarget);
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__protein.purgeDependencyOnElmtId(rmElmtId);
        this.__fat.purgeDependencyOnElmtId(rmElmtId);
        this.__carb.purgeDependencyOnElmtId(rmElmtId);
        this.__carbTarget.purgeDependencyOnElmtId(rmElmtId);
        this.__proteinTarget.purgeDependencyOnElmtId(rmElmtId);
        this.__fatTarget.purgeDependencyOnElmtId(rmElmtId);
        this.__frame.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__protein.aboutToBeDeleted();
        this.__fat.aboutToBeDeleted();
        this.__carb.aboutToBeDeleted();
        this.__carbTarget.aboutToBeDeleted();
        this.__proteinTarget.aboutToBeDeleted();
        this.__fatTarget.aboutToBeDeleted();
        this.__frame.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    // 加 @Watch 是为了在数据变化时推动动画。
    // 注意监测的是「克数」而不是算出来的百分比：两者同步变化，
    // 但克数是入参本身，@Watch 一定能收到。
    private __protein: SynchedPropertySimpleOneWayPU<number>;
    get protein() {
        return this.__protein.get();
    }
    set protein(newValue: number) {
        this.__protein.set(newValue);
    }
    private __fat: SynchedPropertySimpleOneWayPU<number>;
    get fat() {
        return this.__fat.get();
    }
    set fat(newValue: number) {
        this.__fat.set(newValue);
    }
    private __carb: SynchedPropertySimpleOneWayPU<number>;
    get carb() {
        return this.__carb.get();
    }
    set carb(newValue: number) {
        this.__carb.set(newValue);
    }
    /** 三大营养素的推荐克数，由调用方按当日预算算好后传入 */
    private __carbTarget: SynchedPropertySimpleOneWayPU<number>;
    get carbTarget() {
        return this.__carbTarget.get();
    }
    set carbTarget(newValue: number) {
        this.__carbTarget.set(newValue);
    }
    private __proteinTarget: SynchedPropertySimpleOneWayPU<number>;
    get proteinTarget() {
        return this.__proteinTarget.get();
    }
    set proteinTarget(newValue: number) {
        this.__proteinTarget.set(newValue);
    }
    private __fatTarget: SynchedPropertySimpleOneWayPU<number>;
    get fatTarget() {
        return this.__fatTarget.get();
    }
    set fatTarget(newValue: number) {
        this.__fatTarget.set(newValue);
    }
    /**
     * 每帧递增的版本号。
     *
     * @State 数组本身在动画期间一直被改，但为了让「数字」也跟着重建，
     * 这里额外用一个计数器：build 里读它，就能保证整块内容每帧重算一次。
     */
    private __frame: ObservedPropertySimplePU<number>;
    get frame() {
        return this.__frame.get();
    }
    set frame(newValue: number) {
        this.__frame.set(newValue);
    }
    private tickers: MacroTicker[];
    aboutToAppear(): void {
        // 首帧直接落位，避免一进页面三根条从 0 长出来
        this.snapAll();
    }
    aboutToDisappear(): void {
        // 定时器必须在销毁时停掉，否则回调会打到已销毁的实例上
        for (const t of this.tickers) {
            t.stop();
        }
    }
    /** 数据变化：把数字与条一起平滑推到新值 */
    onDataChange(): void {
        const list: MacroItem[] = this.items();
        for (let i = 0; i < list.length; i++) {
            const item: MacroItem = list[i];
            this.tickers[i].to(item.grams, item.percent(), () => {
                this.frame++;
            }, DUR_SLOW);
        }
    }
    /** 不做动画，直接落位 */
    private snapAll(): void {
        const list: MacroItem[] = this.items();
        for (let i = 0; i < list.length; i++) {
            this.tickers[i].snap(list[i].grams, list[i].percent());
        }
    }
    private items(): MacroItem[] {
        return [
            new MacroItem('碳水', this.carb, this.carbTarget, COLOR_CARB),
            new MacroItem('蛋白质', this.protein, this.proteinTarget, COLOR_PROTEIN),
            new MacroItem('脂肪', this.fat, this.fatTarget, COLOR_FAT)
        ];
    }
    /** 第 i 项当前应显示的克数（保留一位小数） */
    private gramsAt(i: number): number {
        const v: number = i < this.tickers.length ? this.tickers[i].shownGrams : 0;
        return Math.round(v * 10) / 10;
    }
    /** 第 i 项当前应显示的条形宽度百分比 */
    private pctAt(i: number): number {
        return i < this.tickers.length ? this.tickers[i].shownPct : 0;
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 12 });
            Column.debugLine("entry/src/main/ets/components/MacroBar.ets(182:5)", "entry");
            Column.width('100%');
            Column.padding(16);
            Column.backgroundColor(COLOR_CARD);
            Column.borderRadius(RADIUS);
            Column.shadow(CARD_SHADOW);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            ForEach.create();
            const forEachItemGenFunction = (_item, index: number) => {
                const item = _item;
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Column.create({ space: 5 });
                    Column.debugLine("entry/src/main/ets/components/MacroBar.ets(184:9)", "entry");
                    Column.width('100%');
                    Column.alignItems(HorizontalAlign.Start);
                }, Column);
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Row.create();
                    Row.debugLine("entry/src/main/ets/components/MacroBar.ets(185:11)", "entry");
                    Row.width('100%');
                }, Row);
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Text.create(item.label);
                    Text.debugLine("entry/src/main/ets/components/MacroBar.ets(186:13)", "entry");
                    Text.fontSize(13);
                    Text.fontColor(COLOR_TEXT_SUB);
                }, Text);
                Text.pop();
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Blank.create();
                    Blank.debugLine("entry/src/main/ets/components/MacroBar.ets(189:13)", "entry");
                }, Blank);
                Blank.pop();
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    // 摄入 / 推荐。摄入值走动画器，所以会跟着条一起连续变化
                    Text.create(`${this.gramsAt(index)} / ${item.target} g`);
                    Text.debugLine("entry/src/main/ets/components/MacroBar.ets(191:13)", "entry");
                    // 摄入 / 推荐。摄入值走动画器，所以会跟着条一起连续变化
                    Text.fontSize(12);
                    // 摄入 / 推荐。摄入值走动画器，所以会跟着条一起连续变化
                    Text.fontColor(COLOR_TEXT);
                }, Text);
                // 摄入 / 推荐。摄入值走动画器，所以会跟着条一起连续变化
                Text.pop();
                Row.pop();
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    /*
                     * 条形：外层浅灰底，内层按完成度着色。
                     *
                     * 宽度交给外层 Row 撑满，Stack 只负责把两层条子叠在一起。
                     * 注意这里绝不能在 Stack 上写 layoutWeight：
                     * Stack 的父级是 Column（纵向），layoutWeight 会被解释成
                     * **纵向**扩张，把每一项都拉到整张卡片那么高
                     * （实测过：卡片被撑满屏、条形漂到屏幕中间）。
                     */
                    Row.create();
                    Row.debugLine("entry/src/main/ets/components/MacroBar.ets(206:11)", "entry");
                    /*
                     * 条形：外层浅灰底，内层按完成度着色。
                     *
                     * 宽度交给外层 Row 撑满，Stack 只负责把两层条子叠在一起。
                     * 注意这里绝不能在 Stack 上写 layoutWeight：
                     * Stack 的父级是 Column（纵向），layoutWeight 会被解释成
                     * **纵向**扩张，把每一项都拉到整张卡片那么高
                     * （实测过：卡片被撑满屏、条形漂到屏幕中间）。
                     */
                    Row.width('100%');
                    /*
                     * 条形：外层浅灰底，内层按完成度着色。
                     *
                     * 宽度交给外层 Row 撑满，Stack 只负责把两层条子叠在一起。
                     * 注意这里绝不能在 Stack 上写 layoutWeight：
                     * Stack 的父级是 Column（纵向），layoutWeight 会被解释成
                     * **纵向**扩张，把每一项都拉到整张卡片那么高
                     * （实测过：卡片被撑满屏、条形漂到屏幕中间）。
                     */
                    Row.height(8);
                }, Row);
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Stack.create({ alignContent: Alignment.Start });
                    Stack.debugLine("entry/src/main/ets/components/MacroBar.ets(207:13)", "entry");
                    Stack.width('100%');
                    Stack.height(8);
                }, Stack);
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Row.create();
                    Row.debugLine("entry/src/main/ets/components/MacroBar.ets(208:15)", "entry");
                    Row.width('100%');
                    Row.height(8);
                    Row.backgroundColor(COLOR_DIVIDER);
                    Row.borderRadius(4);
                }, Row);
                Row.pop();
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Row.create();
                    Row.debugLine("entry/src/main/ets/components/MacroBar.ets(214:15)", "entry");
                    Row.width(`${this.pctAt(index)}%`);
                    Row.height(8);
                    Row.backgroundColor(item.color);
                    Row.borderRadius(4);
                }, Row);
                Row.pop();
                Stack.pop();
                /*
                 * 条形：外层浅灰底，内层按完成度着色。
                 *
                 * 宽度交给外层 Row 撑满，Stack 只负责把两层条子叠在一起。
                 * 注意这里绝不能在 Stack 上写 layoutWeight：
                 * Stack 的父级是 Column（纵向），layoutWeight 会被解释成
                 * **纵向**扩张，把每一项都拉到整张卡片那么高
                 * （实测过：卡片被撑满屏、条形漂到屏幕中间）。
                 */
                Row.pop();
                Column.pop();
            };
            this.forEachUpdateFunction(elmtId, this.items(), forEachItemGenFunction, (item: MacroItem, index: number) => `${index}-${this.frame}-${item.label}`, true, true);
        }, ForEach);
        ForEach.pop();
        Column.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
    public __resetStateVarsOnReuse__Internal(params: Object): void {
    }
}
