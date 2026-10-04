if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface FloatingNav_Params {
    items?: NavItem[];
    activeIndex?: number;
    barWidth?: number;
    onSelect?: (index: number) => void;
    pressing?: boolean;
    pressX?: number;
    hoverIndex?: number;
}
import { COLOR_NAV_IDLE, COLOR_PRIMARY, DUR_FAST, NAV_HEIGHT, NAV_RADIUS } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
/** 一个导航项 */
export class NavItem {
    label: string;
    /** 用字符做图标，避免依赖系统符号资源 */
    glyph: string;
    constructor(label: string, glyph: string) {
        this.label = label;
        this.glyph = glyph;
    }
}
export class FloatingNav extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__items = new SynchedPropertyObjectOneWayPU(params.items, this, "items");
        this.__activeIndex = new SynchedPropertySimpleOneWayPU(params.activeIndex, this, "activeIndex");
        this.__barWidth = new SynchedPropertySimpleOneWayPU(params.barWidth, this, "barWidth");
        this.onSelect = () => {
        };
        this.__pressing = new ObservedPropertySimplePU(false, this, "pressing");
        this.__pressX = new ObservedPropertySimplePU(0, this, "pressX");
        this.__hoverIndex = new ObservedPropertySimplePU(-1, this, "hoverIndex");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: FloatingNav_Params) {
        if (params.items === undefined) {
            this.__items.set([]);
        }
        if (params.activeIndex === undefined) {
            this.__activeIndex.set(0);
        }
        if (params.barWidth === undefined) {
            this.__barWidth.set(0);
        }
        if (params.onSelect !== undefined) {
            this.onSelect = params.onSelect;
        }
        if (params.pressing !== undefined) {
            this.pressing = params.pressing;
        }
        if (params.pressX !== undefined) {
            this.pressX = params.pressX;
        }
        if (params.hoverIndex !== undefined) {
            this.hoverIndex = params.hoverIndex;
        }
    }
    updateStateVars(params: FloatingNav_Params) {
        this.__items.reset(params.items);
        this.__activeIndex.reset(params.activeIndex);
        this.__barWidth.reset(params.barWidth);
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__items.purgeDependencyOnElmtId(rmElmtId);
        this.__activeIndex.purgeDependencyOnElmtId(rmElmtId);
        this.__barWidth.purgeDependencyOnElmtId(rmElmtId);
        this.__pressing.purgeDependencyOnElmtId(rmElmtId);
        this.__pressX.purgeDependencyOnElmtId(rmElmtId);
        this.__hoverIndex.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__items.aboutToBeDeleted();
        this.__activeIndex.aboutToBeDeleted();
        this.__barWidth.aboutToBeDeleted();
        this.__pressing.aboutToBeDeleted();
        this.__pressX.aboutToBeDeleted();
        this.__hoverIndex.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __items: SynchedPropertySimpleOneWayPU<NavItem[]>;
    get items() {
        return this.__items.get();
    }
    set items(newValue: NavItem[]) {
        this.__items.set(newValue);
    }
    /** 当前选中项（已提交的） */
    private __activeIndex: SynchedPropertySimpleOneWayPU<number>;
    get activeIndex() {
        return this.__activeIndex.get();
    }
    set activeIndex(newValue: number) {
        this.__activeIndex.set(newValue);
    }
    /** 导航栏总宽度（vp），由父组件用 onAreaChange 传入 */
    private __barWidth: SynchedPropertySimpleOneWayPU<number>;
    get barWidth() {
        return this.__barWidth.get();
    }
    set barWidth(newValue: number) {
        this.__barWidth.set(newValue);
    }
    private onSelect: (index: number) => void;
    /** 是否正被按住 */
    private __pressing: ObservedPropertySimplePU<boolean>;
    get pressing() {
        return this.__pressing.get();
    }
    set pressing(newValue: boolean) {
        this.__pressing.set(newValue);
    }
    /** 手指按下时相对导航栏左边的 x 坐标，用于换算下标 */
    private __pressX: ObservedPropertySimplePU<number>;
    get pressX() {
        return this.__pressX.get();
    }
    set pressX(newValue: number) {
        this.__pressX.set(newValue);
    }
    /** 手指当前落在第几项；-1 表示没按 */
    private __hoverIndex: ObservedPropertySimplePU<number>;
    get hoverIndex() {
        return this.__hoverIndex.get();
    }
    set hoverIndex(newValue: number) {
        this.__hoverIndex.set(newValue);
    }
    private cellWidth(): number {
        const n: number = this.items.length > 0 ? this.items.length : 1;
        return this.barWidth > 0 ? this.barWidth / n : 0;
    }
    /**
     * 一项的颜色：选中是品牌绿，未选中是中性灰。
     *
     * 图标与文字共用同一个颜色，所以选中态完全由颜色表达，
     * 不需要任何背景块。
     */
    private itemColor(index: number): string {
        return index === this.activeIndex ? COLOR_PRIMARY : COLOR_NAV_IDLE;
    }
    /** 把 x 坐标换算成项下标 */
    private indexAt(x: number): number {
        const w: number = this.cellWidth();
        if (w <= 0) {
            return -1;
        }
        const i: number = Math.floor(x / w);
        return Math.max(0, Math.min(this.items.length - 1, i));
    }
    /**
     * 玻璃底色。
     *
     * 三层叠出「液态玻璃」：
     *   1. 极低透明度的白底（10%）——让底层内容透上来
     *   2. 拉满的背景模糊——把透上来的内容磨成砂面
     *   3. 细白色高光边框——玻璃边缘的折射感
     *
     * 关于模糊强度：backgroundBlurStyle 只能选 BlurStyle 档位，
     * 没有 blurRadius 参数（那是前景 blur() 的入参，见 BackgroundBlurStyleOptions
     * 的字段只有 colorMode / adaptiveColor / scale / blurOptions）。
     * 「拉满」对应的档位是 BACKGROUND_ULTRA_THICK
     * （枚举里没有 ULTRA_THICK，写它会编译不过）。
     */
    glassBackdrop(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.debugLine("entry/src/main/ets/components/FloatingNav.ets(89:5)", "entry");
            Column.width('100%');
            Column.height('100%');
            Column.backgroundBlurStyle(BlurStyle.BACKGROUND_ULTRA_THICK, {
                colorMode: ThemeColorMode.LIGHT,
                adaptiveColor: AdaptiveColor.DEFAULT,
                scale: 1.0
            });
            Column.backgroundColor('#1AFFFFFF');
            Column.hitTestBehavior(HitTestMode.None);
        }, Column);
        Column.pop();
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create({ alignContent: Alignment.Center });
            Stack.debugLine("entry/src/main/ets/components/FloatingNav.ets(103:5)", "entry");
            Stack.width('100%');
            Stack.height(NAV_HEIGHT);
            Stack.clip(true);
            Stack.borderRadius(NAV_RADIUS);
            Stack.border({ width: 1, color: '#99FFFFFF' });
            Stack.onTouch((event: TouchEvent) => {
                const touches: TouchObject[] = event.touches;
                if (touches.length === 0) {
                    return;
                }
                const x: number = touches[0].x;
                if (event.type === TouchType.Down) {
                    this.pressing = true;
                    this.pressX = x;
                    this.hoverIndex = this.indexAt(x);
                }
                else if (event.type === TouchType.Move) {
                    this.pressX = x;
                    this.hoverIndex = this.indexAt(x);
                }
                else if (event.type === TouchType.Up) {
                    const target: number = this.indexAt(x);
                    this.pressing = false;
                    this.hoverIndex = -1;
                    if (target >= 0 && target !== this.activeIndex) {
                        this.onSelect(target);
                    }
                }
                else if (event.type === TouchType.Cancel) {
                    this.pressing = false;
                    this.hoverIndex = -1;
                }
            });
        }, Stack);
        // 玻璃底色：10% 白 + 拉满模糊
        this.glassBackdrop.bind(this)();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            /*
             * 三个入口均匀排布，没有任何选中背景块。
             *
             * 选中态完全靠颜色表达（图标与文字一起变绿），
             * 不再画那个大圆角胶囊——它会占掉大半个格子，
             * 视觉上像是「一个按钮被按住了」，而不是「当前在这一页」。
             *
             * 按下时的反馈也刻意做得很轻（整格轻微缩放 + 压暗），
             * 不再用跟随手指的径向柔光：那同样会被看成一块背景。
             */
            Row.create();
            Row.debugLine("entry/src/main/ets/components/FloatingNav.ets(117:7)", "entry");
            /*
             * 三个入口均匀排布，没有任何选中背景块。
             *
             * 选中态完全靠颜色表达（图标与文字一起变绿），
             * 不再画那个大圆角胶囊——它会占掉大半个格子，
             * 视觉上像是「一个按钮被按住了」，而不是「当前在这一页」。
             *
             * 按下时的反馈也刻意做得很轻（整格轻微缩放 + 压暗），
             * 不再用跟随手指的径向柔光：那同样会被看成一块背景。
             */
            Row.width('100%');
            /*
             * 三个入口均匀排布，没有任何选中背景块。
             *
             * 选中态完全靠颜色表达（图标与文字一起变绿），
             * 不再画那个大圆角胶囊——它会占掉大半个格子，
             * 视觉上像是「一个按钮被按住了」，而不是「当前在这一页」。
             *
             * 按下时的反馈也刻意做得很轻（整格轻微缩放 + 压暗），
             * 不再用跟随手指的径向柔光：那同样会被看成一块背景。
             */
            Row.height(NAV_HEIGHT);
            /*
             * 三个入口均匀排布，没有任何选中背景块。
             *
             * 选中态完全靠颜色表达（图标与文字一起变绿），
             * 不再画那个大圆角胶囊——它会占掉大半个格子，
             * 视觉上像是「一个按钮被按住了」，而不是「当前在这一页」。
             *
             * 按下时的反馈也刻意做得很轻（整格轻微缩放 + 压暗），
             * 不再用跟随手指的径向柔光：那同样会被看成一块背景。
             */
            Row.justifyContent(FlexAlign.SpaceEvenly);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            ForEach.create();
            const forEachItemGenFunction = (_item, index: number) => {
                const item = _item;
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Column.create({ space: 4 });
                    Column.debugLine("entry/src/main/ets/components/FloatingNav.ets(119:11)", "entry");
                    globalThis.Context.animation({ duration: DUR_FAST, curve: Curve.EaseOut });
                    Column.height(NAV_HEIGHT);
                    Column.justifyContent(FlexAlign.Center);
                    Column.alignItems(HorizontalAlign.Center);
                    Column.scale({
                        x: this.pressing && this.hoverIndex === index ? 0.92 : 1,
                        y: this.pressing && this.hoverIndex === index ? 0.92 : 1
                    });
                    globalThis.Context.animation(null);
                }, Column);
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    // 图标固定行高，避免不同字符的行高差异把这一格顶得不居中
                    Text.create(item.glyph);
                    Text.debugLine("entry/src/main/ets/components/FloatingNav.ets(121:13)", "entry");
                    // 图标固定行高，避免不同字符的行高差异把这一格顶得不居中
                    Text.fontSize(21);
                    // 图标固定行高，避免不同字符的行高差异把这一格顶得不居中
                    Text.lineHeight(25);
                    // 图标固定行高，避免不同字符的行高差异把这一格顶得不居中
                    Text.textAlign(TextAlign.Center);
                    // 图标固定行高，避免不同字符的行高差异把这一格顶得不居中
                    Text.fontColor(this.itemColor(index));
                }, Text);
                // 图标固定行高，避免不同字符的行高差异把这一格顶得不居中
                Text.pop();
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Text.create(item.label);
                    Text.debugLine("entry/src/main/ets/components/FloatingNav.ets(127:13)", "entry");
                    Text.fontSize(11);
                    Text.lineHeight(14);
                    Text.textAlign(TextAlign.Center);
                    Text.fontWeight(index === this.activeIndex ? FontWeight.Medium : FontWeight.Normal);
                    Text.fontColor(this.itemColor(index));
                }, Text);
                Text.pop();
                Column.pop();
            };
            this.forEachUpdateFunction(elmtId, this.items, forEachItemGenFunction, (item: NavItem, index: number) => `${index}-${item.label}`, true, true);
        }, ForEach);
        ForEach.pop();
        /*
         * 三个入口均匀排布，没有任何选中背景块。
         *
         * 选中态完全靠颜色表达（图标与文字一起变绿），
         * 不再画那个大圆角胶囊——它会占掉大半个格子，
         * 视觉上像是「一个按钮被按住了」，而不是「当前在这一页」。
         *
         * 按下时的反馈也刻意做得很轻（整格轻微缩放 + 压暗），
         * 不再用跟随手指的径向柔光：那同样会被看成一块背景。
         */
        Row.pop();
        Stack.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
    public __resetStateVarsOnReuse__Internal(params: Object): void {
    }
}
