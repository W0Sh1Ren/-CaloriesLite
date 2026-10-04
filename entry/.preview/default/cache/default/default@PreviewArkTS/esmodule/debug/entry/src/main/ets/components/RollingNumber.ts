if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface RollingNumber_Params {
    value?: number;
    refreshKey?: number;
    fontSize?: number;
    fontWeight?: FontWeight;
    textColor?: string;
    duration?: number;
    decimals?: number;
    progress?: number;
    fromValue?: number;
    settled?: number;
    initialized?: boolean;
}
import { CURVE_COUNT, DUR_SLOW } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
export class RollingNumber extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__value = new SynchedPropertySimpleOneWayPU(params.value, this, "value");
        this.__refreshKey = new SynchedPropertySimpleOneWayPU(params.refreshKey, this, "refreshKey");
        this.__fontSize = new SynchedPropertySimpleOneWayPU(params.fontSize, this, "fontSize");
        this.__fontWeight = new SynchedPropertySimpleOneWayPU(params.fontWeight, this, "fontWeight");
        this.__textColor = new SynchedPropertySimpleOneWayPU(params.textColor, this, "textColor");
        this.__duration = new SynchedPropertySimpleOneWayPU(params.duration, this, "duration");
        this.__decimals = new SynchedPropertySimpleOneWayPU(params.decimals, this, "decimals");
        this.__progress = new ObservedPropertySimplePU(1, this, "progress");
        this.__fromValue = new ObservedPropertySimplePU(0, this, "fromValue");
        this.__settled = new ObservedPropertySimplePU(0, this, "settled");
        this.initialized = false;
        this.setInitiallyProvidedValue(params);
        this.declareWatch("value", this.onValueChange);
        this.declareWatch("refreshKey", this.onValueChange);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: RollingNumber_Params) {
        if (params.value === undefined) {
            this.__value.set(0);
        }
        if (params.refreshKey === undefined) {
            this.__refreshKey.set(0);
        }
        if (params.fontSize === undefined) {
            this.__fontSize.set(48);
        }
        if (params.fontWeight === undefined) {
            this.__fontWeight.set(FontWeight.Bold);
        }
        if (params.textColor === undefined) {
            this.__textColor.set('#1A1A1A');
        }
        if (params.duration === undefined) {
            this.__duration.set(DUR_SLOW);
        }
        if (params.decimals === undefined) {
            this.__decimals.set(0);
        }
        if (params.progress !== undefined) {
            this.progress = params.progress;
        }
        if (params.fromValue !== undefined) {
            this.fromValue = params.fromValue;
        }
        if (params.settled !== undefined) {
            this.settled = params.settled;
        }
        if (params.initialized !== undefined) {
            this.initialized = params.initialized;
        }
    }
    updateStateVars(params: RollingNumber_Params) {
        this.__value.reset(params.value);
        this.__refreshKey.reset(params.refreshKey);
        this.__fontSize.reset(params.fontSize);
        this.__fontWeight.reset(params.fontWeight);
        this.__textColor.reset(params.textColor);
        this.__duration.reset(params.duration);
        this.__decimals.reset(params.decimals);
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__value.purgeDependencyOnElmtId(rmElmtId);
        this.__refreshKey.purgeDependencyOnElmtId(rmElmtId);
        this.__fontSize.purgeDependencyOnElmtId(rmElmtId);
        this.__fontWeight.purgeDependencyOnElmtId(rmElmtId);
        this.__textColor.purgeDependencyOnElmtId(rmElmtId);
        this.__duration.purgeDependencyOnElmtId(rmElmtId);
        this.__decimals.purgeDependencyOnElmtId(rmElmtId);
        this.__progress.purgeDependencyOnElmtId(rmElmtId);
        this.__fromValue.purgeDependencyOnElmtId(rmElmtId);
        this.__settled.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__value.aboutToBeDeleted();
        this.__refreshKey.aboutToBeDeleted();
        this.__fontSize.aboutToBeDeleted();
        this.__fontWeight.aboutToBeDeleted();
        this.__textColor.aboutToBeDeleted();
        this.__duration.aboutToBeDeleted();
        this.__decimals.aboutToBeDeleted();
        this.__progress.aboutToBeDeleted();
        this.__fromValue.aboutToBeDeleted();
        this.__settled.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    /** 目标数值 */
    private __value: SynchedPropertySimpleOneWayPU<number>;
    get value() {
        return this.__value.get();
    }
    set value(newValue: number) {
        this.__value.set(newValue);
    }
    /**
     * 外部刷新键：父组件每次重读数据都换一个新值。
     *
     * 单靠 @Prop 的 @Watch 已经够用，加这一层是因为「只改数据、不改引用」
     * 的场景下 @Watch 也可能收不到通知；刷新键是显式信号，最稳。
     */
    private __refreshKey: SynchedPropertySimpleOneWayPU<number>;
    get refreshKey() {
        return this.__refreshKey.get();
    }
    set refreshKey(newValue: number) {
        this.__refreshKey.set(newValue);
    }
    private __fontSize: SynchedPropertySimpleOneWayPU<number>;
    get fontSize() {
        return this.__fontSize.get();
    }
    set fontSize(newValue: number) {
        this.__fontSize.set(newValue);
    }
    private __fontWeight: SynchedPropertySimpleOneWayPU<FontWeight>;
    get fontWeight() {
        return this.__fontWeight.get();
    }
    set fontWeight(newValue: FontWeight) {
        this.__fontWeight.set(newValue);
    }
    private __textColor: SynchedPropertySimpleOneWayPU<string>;
    get textColor() {
        return this.__textColor.get();
    }
    set textColor(newValue: string) {
        this.__textColor.set(newValue);
    }
    private __duration: SynchedPropertySimpleOneWayPU<number>;
    get duration() {
        return this.__duration.get();
    }
    set duration(newValue: number) {
        this.__duration.set(newValue);
    }
    /** 小数位数。整数用 0（默认），像 BMI 这种要 1 */
    private __decimals: SynchedPropertySimpleOneWayPU<number>;
    get decimals() {
        return this.__decimals.get();
    }
    set decimals(newValue: number) {
        this.__decimals.set(newValue);
    }
    /** 动画进度 0→1 */
    private __progress: ObservedPropertySimplePU<number>;
    get progress() {
        return this.__progress.get();
    }
    set progress(newValue: number) {
        this.__progress.set(newValue);
    }
    /** 本次滚动的起始值 */
    private __fromValue: ObservedPropertySimplePU<number>;
    get fromValue() {
        return this.__fromValue.get();
    }
    set fromValue(newValue: number) {
        this.__fromValue.set(newValue);
    }
    /** 已经滚到的目标值，用来判断是否需要重新起动画 */
    private __settled: ObservedPropertySimplePU<number>;
    get settled() {
        return this.__settled.get();
    }
    set settled(newValue: number) {
        this.__settled.set(newValue);
    }
    /** 首帧不播动画 */
    private initialized: boolean;
    aboutToAppear(): void {
        this.settled = this.value;
        this.fromValue = this.value;
        this.progress = 1;
        this.initialized = true;
    }
    /** value 或 refreshKey 变化时重播滚动动画 */
    onValueChange(): void {
        if (!this.initialized || this.value === this.settled) {
            return;
        }
        // 从「当前显示到哪」接着滚，而不是从上一段动画的起点重来，
        // 这样连续快速变化也不会跳
        this.fromValue = this.fromValue + (this.settled - this.fromValue) * this.progress;
        this.settled = this.value;
        this.progress = 0;
        this.getUIContext().animateTo({
            duration: this.duration,
            curve: CURVE_COUNT
        }, () => {
            this.progress = 1;
        });
    }
    /** 当前这一帧应该显示的值 */
    private display(): number {
        const v: number = this.fromValue + (this.settled - this.fromValue) * this.progress;
        if (this.decimals <= 0) {
            return Math.round(v);
        }
        // 保留指定小数位后再取整成定点数，避免 35.499999 这种浮点噪声
        const f: number = Math.pow(10, this.decimals);
        return Math.round(v * f) / f;
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.decimals <= 0 ? `${this.display()}` : this.display().toFixed(this.decimals));
            Text.debugLine("entry/src/main/ets/components/RollingNumber.ets(81:5)", "entry");
            Text.fontSize(this.fontSize);
            Text.fontWeight(this.fontWeight);
            Text.fontColor(this.textColor);
        }, Text);
        Text.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
    public __resetStateVarsOnReuse__Internal(params: Object): void {
    }
}
