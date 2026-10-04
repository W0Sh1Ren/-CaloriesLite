if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface CalorieRing_Params {
    intake?: number;
    budget?: number;
    exerciseKcal?: number;
    deficit?: number;
    refreshKey?: number;
    diameter?: number;
    settings?: RenderingContextSettings;
    ctx?: CanvasRenderingContext2D;
    canvasReady?: boolean;
    animRatio?: number;
    animTimer?: number;
}
import { CARD_SHADOW, COLOR_CARD, COLOR_OK, COLOR_PRIMARY, COLOR_PRIMARY_SOFT, COLOR_TEXT, COLOR_TEXT_SUB, COLOR_WARN, DUR_SLOW, GAP, RADIUS } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
import { RollingNumber } from "@normalized:N&&&entry/src/main/ets/components/RollingNumber&";
export class CalorieRing extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__intake = new SynchedPropertySimpleOneWayPU(params.intake, this, "intake");
        this.__budget = new SynchedPropertySimpleOneWayPU(params.budget, this, "budget");
        this.__exerciseKcal = new SynchedPropertySimpleOneWayPU(params.exerciseKcal, this, "exerciseKcal");
        this.__deficit = new SynchedPropertySimpleOneWayPU(params.deficit, this, "deficit");
        this.__refreshKey = new SynchedPropertySimpleOneWayPU(params.refreshKey, this, "refreshKey");
        this.__diameter = new SynchedPropertySimpleOneWayPU(params.diameter, this, "diameter");
        this.settings = new RenderingContextSettings(true);
        this.ctx = new CanvasRenderingContext2D(this.settings);
        this.canvasReady = false;
        this.__animRatio = new ObservedPropertySimplePU(0, this, "animRatio");
        this.animTimer = -1;
        this.setInitiallyProvidedValue(params);
        this.declareWatch("intake", this.onDataChange);
        this.declareWatch("budget", this.onDataChange);
        this.declareWatch("exerciseKcal", this.onDataChange);
        this.declareWatch("deficit", this.onDataChange);
        this.declareWatch("refreshKey", this.onDataChange);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: CalorieRing_Params) {
        if (params.intake === undefined) {
            this.__intake.set(0);
        }
        if (params.budget === undefined) {
            this.__budget.set(0);
        }
        if (params.exerciseKcal === undefined) {
            this.__exerciseKcal.set(0);
        }
        if (params.deficit === undefined) {
            this.__deficit.set(0);
        }
        if (params.refreshKey === undefined) {
            this.__refreshKey.set(0);
        }
        if (params.diameter === undefined) {
            this.__diameter.set(210);
        }
        if (params.settings !== undefined) {
            this.settings = params.settings;
        }
        if (params.ctx !== undefined) {
            this.ctx = params.ctx;
        }
        if (params.canvasReady !== undefined) {
            this.canvasReady = params.canvasReady;
        }
        if (params.animRatio !== undefined) {
            this.animRatio = params.animRatio;
        }
        if (params.animTimer !== undefined) {
            this.animTimer = params.animTimer;
        }
    }
    updateStateVars(params: CalorieRing_Params) {
        this.__intake.reset(params.intake);
        this.__budget.reset(params.budget);
        this.__exerciseKcal.reset(params.exerciseKcal);
        this.__deficit.reset(params.deficit);
        this.__refreshKey.reset(params.refreshKey);
        this.__diameter.reset(params.diameter);
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__intake.purgeDependencyOnElmtId(rmElmtId);
        this.__budget.purgeDependencyOnElmtId(rmElmtId);
        this.__exerciseKcal.purgeDependencyOnElmtId(rmElmtId);
        this.__deficit.purgeDependencyOnElmtId(rmElmtId);
        this.__refreshKey.purgeDependencyOnElmtId(rmElmtId);
        this.__diameter.purgeDependencyOnElmtId(rmElmtId);
        this.__animRatio.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__intake.aboutToBeDeleted();
        this.__budget.aboutToBeDeleted();
        this.__exerciseKcal.aboutToBeDeleted();
        this.__deficit.aboutToBeDeleted();
        this.__refreshKey.aboutToBeDeleted();
        this.__diameter.aboutToBeDeleted();
        this.__animRatio.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    // ---- 当日数据，全部基本类型 ----
    private __intake: SynchedPropertySimpleOneWayPU<number>;
    get intake() {
        return this.__intake.get();
    }
    set intake(newValue: number) {
        this.__intake.set(newValue);
    }
    private __budget: SynchedPropertySimpleOneWayPU<number>;
    get budget() {
        return this.__budget.get();
    }
    set budget(newValue: number) {
        this.__budget.set(newValue);
    }
    private __exerciseKcal: SynchedPropertySimpleOneWayPU<number>;
    get exerciseKcal() {
        return this.__exerciseKcal.get();
    }
    set exerciseKcal(newValue: number) {
        this.__exerciseKcal.set(newValue);
    }
    private __deficit: SynchedPropertySimpleOneWayPU<number>;
    get deficit() {
        return this.__deficit.get();
    }
    set deficit(newValue: number) {
        this.__deficit.set(newValue);
    }
    /**
     * 外部刷新键：父组件每次重读数据都换一个新值。
     *
     * 数字本身变化时 @Watch 已经会触发；加这一层是为了覆盖
     * 「两个日期数值恰好相同」或「只换引用不改数值」的场景。
     */
    private __refreshKey: SynchedPropertySimpleOneWayPU<number>;
    get refreshKey() {
        return this.__refreshKey.get();
    }
    set refreshKey(newValue: number) {
        this.__refreshKey.set(newValue);
    }
    /** 环外径（vp） */
    private __diameter: SynchedPropertySimpleOneWayPU<number>;
    get diameter() {
        return this.__diameter.get();
    }
    set diameter(newValue: number) {
        this.__diameter.set(newValue);
    }
    private settings: RenderingContextSettings;
    private ctx: CanvasRenderingContext2D;
    /** Canvas 是否已完成布局。未就绪时 ctx.width/height 是 0，画不出别的 */
    private canvasReady: boolean;
    /**
     * 弧线的显示比例（0-1）。这个 @State 是动画的驱动源：
     * 每帧写入它会让组件重建，同时下面手动调 draw() 重绘 Canvas。
     */
    private __animRatio: ObservedPropertySimplePU<number>;
    get animRatio() {
        return this.__animRatio.get();
    }
    set animRatio(newValue: number) {
        this.__animRatio.set(newValue);
    }
    /** 逐帧动画的定时器句柄，-1 表示没在跑 */
    private animTimer: number;
    aboutToAppear(): void {
        this.animRatio = this.ratio();
    }
    aboutToDisappear(): void {
        // 定时器必须在销毁时停掉，否则回调会打到已销毁的实例上
        this.stopAnim();
    }
    private stopAnim(): void {
        if (this.animTimer !== -1) {
            clearInterval(this.animTimer);
            this.animTimer = -1;
        }
    }
    /**
     * 数据变化时把弧线平滑推到新比例。
     *
     * 为什么自己跑定时器而不用 animateTo：
     * Canvas 里的圆弧是一次性画上去的路径，不在属性动画的插值通道里；
     * 而在 build 里调 draw() 又不允许（build 不能有副作用）。
     * 所以只能每帧同时做两件事：写 @State（触发重建）+ 调 draw()（重绘画布）。
     */
    onDataChange(): void {
        const target: number = this.ratio();
        if (!this.canvasReady) {
            this.animRatio = target;
            return;
        }
        if (Math.abs(target - this.animRatio) < 0.0001) {
            // 比例没变也要重绘一次，保证颜色（超标变红）能更新
            this.draw();
            return;
        }
        this.stopAnim();
        const from: number = this.animRatio;
        const startedAt: number = Date.now();
        const duration: number = DUR_SLOW;
        this.animTimer = setInterval(() => {
            const t: number = Math.min(1, (Date.now() - startedAt) / duration);
            // easeOutCubic：起步快、收尾缓，与应用其它动效节奏一致
            const eased: number = 1 - Math.pow(1 - t, 3);
            this.animRatio = from + (target - from) * eased;
            // 写 @State 会触发重建，但 Canvas 需要显式重画
            this.draw();
            if (t >= 1) {
                this.stopAnim();
            }
        }, 16);
    }
    /** 已摄入占「预算 + 运动」的比例（0-1），超出按 1 画满 */
    private ratio(): number {
        const capacity: number = this.budget + this.exerciseKcal;
        if (capacity <= 0) {
            return 0;
        }
        const r: number = this.intake / capacity;
        return Math.min(1, Math.max(0, r));
    }
    /** 超标时进度弧变红 */
    private arcColor(): string {
        return this.deficit < 0 ? COLOR_WARN : COLOR_PRIMARY;
    }
    /** 按当前数据重绘 */
    private draw(): void {
        const ctx = this.ctx;
        const w: number = ctx.width;
        const h: number = ctx.height;
        ctx.clearRect(0, 0, w, h);
        if (w <= 0 || h <= 0) {
            return;
        }
        const stroke: number = 14;
        const radius: number = Math.min(w, h) / 2 - stroke / 2;
        const cx: number = w / 2;
        const cy: number = h / 2;
        // 底环：整圈浅色
        ctx.beginPath();
        ctx.strokeStyle = COLOR_PRIMARY_SOFT;
        ctx.lineWidth = stroke;
        ctx.lineCap = 'round';
        ctx.arc(cx, cy, radius, 0, Math.PI * 2);
        ctx.stroke();
        // 进度弧：从 12 点方向顺时针。用动画比例而不是目标比例，弧线才会连续增长
        const r: number = this.animRatio;
        if (r > 0) {
            const start: number = -Math.PI / 2;
            const end: number = start + Math.PI * 2 * r;
            ctx.beginPath();
            ctx.strokeStyle = this.arcColor();
            ctx.lineWidth = stroke;
            ctx.lineCap = 'round';
            ctx.arc(cx, cy, radius, start, end);
            ctx.stroke();
        }
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: GAP });
            Column.debugLine("entry/src/main/ets/components/CalorieRing.ets(153:5)", "entry");
            Column.width('100%');
            Column.padding(20);
            Column.backgroundColor(COLOR_CARD);
            Column.borderRadius(RADIUS);
            Column.shadow(CARD_SHADOW);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create();
            Stack.debugLine("entry/src/main/ets/components/CalorieRing.ets(154:7)", "entry");
            Stack.width(this.diameter);
            Stack.height(this.diameter);
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 自绘圆环
            Canvas.create(this.ctx);
            Canvas.debugLine("entry/src/main/ets/components/CalorieRing.ets(156:9)", "entry");
            // 自绘圆环
            Canvas.width(this.diameter);
            // 自绘圆环
            Canvas.height(this.diameter);
            // 自绘圆环
            Canvas.onReady(() => {
                // onReady 时才能拿到真实绘制尺寸
                this.canvasReady = true;
                // 首个值直接落位，避免页面一打开弧线从 0 长出来
                this.animRatio = this.ratio();
                this.draw();
            });
        }, Canvas);
        // 自绘圆环
        Canvas.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 环心数字
            Column.create({ space: 2 });
            Column.debugLine("entry/src/main/ets/components/CalorieRing.ets(167:9)", "entry");
            // 环心数字
            Column.alignItems(HorizontalAlign.Center);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.deficit < 0 ? '超出' : '热量缺口');
            Text.debugLine("entry/src/main/ets/components/CalorieRing.ets(168:11)", "entry");
            Text.fontSize(13);
            Text.fontColor(COLOR_TEXT_SUB);
        }, Text);
        Text.pop();
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new 
                    // 数值变化时滚上去，而不是瞬间跳变
                    RollingNumber(this, {
                        value: Math.abs(this.deficit),
                        refreshKey: this.refreshKey,
                        fontSize: 48,
                        fontWeight: FontWeight.Bold,
                        textColor: this.deficit < 0 ? COLOR_WARN : COLOR_TEXT,
                        duration: DUR_SLOW
                    }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/components/CalorieRing.ets", line: 173, col: 11 });
                    ViewPU.create(componentCall);
                    let paramsLambda = () => {
                        return {
                            value: Math.abs(this.deficit),
                            refreshKey: this.refreshKey,
                            fontSize: 48,
                            fontWeight: FontWeight.Bold,
                            textColor: this.deficit < 0 ? COLOR_WARN : COLOR_TEXT,
                            duration: DUR_SLOW
                        };
                    };
                    componentCall.paramsGenerator_ = paramsLambda;
                }
                else {
                    this.updateStateVarsOfChildByElmtId(elmtId, {
                        value: Math.abs(this.deficit),
                        refreshKey: this.refreshKey,
                        fontSize: 48,
                        fontWeight: FontWeight.Bold,
                        textColor: this.deficit < 0 ? COLOR_WARN : COLOR_TEXT,
                        duration: DUR_SLOW
                    });
                }
            }, { name: "RollingNumber" });
        }
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('千卡');
            Text.debugLine("entry/src/main/ets/components/CalorieRing.ets(182:11)", "entry");
            Text.fontSize(13);
            Text.fontColor(COLOR_TEXT_SUB);
        }, Text);
        Text.pop();
        // 环心数字
        Column.pop();
        Stack.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            /*
             * 预算与摄入明细。
             *
             * 三个数字直接内联，不走 @Builder 参数：
             * @Builder 的入参只在容器构建时求值一次，之后数据变了不会重新求值，
             * 表现就是「切换日期后这三项一直显示当天那一组」（实测踩过两次）。
             */
            Row.create();
            Row.debugLine("entry/src/main/ets/components/CalorieRing.ets(198:7)", "entry");
            /*
             * 预算与摄入明细。
             *
             * 三个数字直接内联，不走 @Builder 参数：
             * @Builder 的入参只在容器构建时求值一次，之后数据变了不会重新求值，
             * 表现就是「切换日期后这三项一直显示当天那一组」（实测踩过两次）。
             */
            Row.width('100%');
            /*
             * 预算与摄入明细。
             *
             * 三个数字直接内联，不走 @Builder 参数：
             * @Builder 的入参只在容器构建时求值一次，之后数据变了不会重新求值，
             * 表现就是「切换日期后这三项一直显示当天那一组」（实测踩过两次）。
             */
            Row.justifyContent(FlexAlign.SpaceEvenly);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 4 });
            Column.debugLine("entry/src/main/ets/components/CalorieRing.ets(199:9)", "entry");
        }, Column);
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new RollingNumber(this, {
                        value: this.intake,
                        refreshKey: this.refreshKey,
                        fontSize: 20,
                        fontWeight: FontWeight.Medium,
                        textColor: COLOR_PRIMARY,
                        duration: DUR_SLOW
                    }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/components/CalorieRing.ets", line: 200, col: 11 });
                    ViewPU.create(componentCall);
                    let paramsLambda = () => {
                        return {
                            value: this.intake,
                            refreshKey: this.refreshKey,
                            fontSize: 20,
                            fontWeight: FontWeight.Medium,
                            textColor: COLOR_PRIMARY,
                            duration: DUR_SLOW
                        };
                    };
                    componentCall.paramsGenerator_ = paramsLambda;
                }
                else {
                    this.updateStateVarsOfChildByElmtId(elmtId, {
                        value: this.intake,
                        refreshKey: this.refreshKey,
                        fontSize: 20,
                        fontWeight: FontWeight.Medium,
                        textColor: COLOR_PRIMARY,
                        duration: DUR_SLOW
                    });
                }
            }, { name: "RollingNumber" });
        }
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('已摄入');
            Text.debugLine("entry/src/main/ets/components/CalorieRing.ets(208:11)", "entry");
            Text.fontSize(12);
            Text.fontColor(COLOR_TEXT_SUB);
        }, Text);
        Text.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Divider.create();
            Divider.debugLine("entry/src/main/ets/components/CalorieRing.ets(212:9)", "entry");
            Divider.vertical(true);
            Divider.height(28);
            Divider.color(COLOR_PRIMARY_SOFT);
        }, Divider);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 4 });
            Column.debugLine("entry/src/main/ets/components/CalorieRing.ets(214:9)", "entry");
        }, Column);
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new RollingNumber(this, {
                        value: this.budget,
                        refreshKey: this.refreshKey,
                        fontSize: 20,
                        fontWeight: FontWeight.Medium,
                        textColor: COLOR_TEXT,
                        duration: DUR_SLOW
                    }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/components/CalorieRing.ets", line: 215, col: 11 });
                    ViewPU.create(componentCall);
                    let paramsLambda = () => {
                        return {
                            value: this.budget,
                            refreshKey: this.refreshKey,
                            fontSize: 20,
                            fontWeight: FontWeight.Medium,
                            textColor: COLOR_TEXT,
                            duration: DUR_SLOW
                        };
                    };
                    componentCall.paramsGenerator_ = paramsLambda;
                }
                else {
                    this.updateStateVarsOfChildByElmtId(elmtId, {
                        value: this.budget,
                        refreshKey: this.refreshKey,
                        fontSize: 20,
                        fontWeight: FontWeight.Medium,
                        textColor: COLOR_TEXT,
                        duration: DUR_SLOW
                    });
                }
            }, { name: "RollingNumber" });
        }
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('基础预算');
            Text.debugLine("entry/src/main/ets/components/CalorieRing.ets(223:11)", "entry");
            Text.fontSize(12);
            Text.fontColor(COLOR_TEXT_SUB);
        }, Text);
        Text.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Divider.create();
            Divider.debugLine("entry/src/main/ets/components/CalorieRing.ets(227:9)", "entry");
            Divider.vertical(true);
            Divider.height(28);
            Divider.color(COLOR_PRIMARY_SOFT);
        }, Divider);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 4 });
            Column.debugLine("entry/src/main/ets/components/CalorieRing.ets(229:9)", "entry");
        }, Column);
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new RollingNumber(this, {
                        value: this.exerciseKcal,
                        refreshKey: this.refreshKey,
                        fontSize: 20,
                        fontWeight: FontWeight.Medium,
                        textColor: COLOR_OK,
                        duration: DUR_SLOW
                    }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/components/CalorieRing.ets", line: 230, col: 11 });
                    ViewPU.create(componentCall);
                    let paramsLambda = () => {
                        return {
                            value: this.exerciseKcal,
                            refreshKey: this.refreshKey,
                            fontSize: 20,
                            fontWeight: FontWeight.Medium,
                            textColor: COLOR_OK,
                            duration: DUR_SLOW
                        };
                    };
                    componentCall.paramsGenerator_ = paramsLambda;
                }
                else {
                    this.updateStateVarsOfChildByElmtId(elmtId, {
                        value: this.exerciseKcal,
                        refreshKey: this.refreshKey,
                        fontSize: 20,
                        fontWeight: FontWeight.Medium,
                        textColor: COLOR_OK,
                        duration: DUR_SLOW
                    });
                }
            }, { name: "RollingNumber" });
        }
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('运动消耗');
            Text.debugLine("entry/src/main/ets/components/CalorieRing.ets(238:11)", "entry");
            Text.fontSize(12);
            Text.fontColor(COLOR_TEXT_SUB);
        }, Text);
        Text.pop();
        Column.pop();
        /*
         * 预算与摄入明细。
         *
         * 三个数字直接内联，不走 @Builder 参数：
         * @Builder 的入参只在容器构建时求值一次，之后数据变了不会重新求值，
         * 表现就是「切换日期后这三项一直显示当天那一组」（实测踩过两次）。
         */
        Row.pop();
        Column.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
    public __resetStateVarsOnReuse__Internal(params: Object): void {
    }
}
