if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface Index_Params {
    dayKey?: string;
    data?: HomeData;
    activeTab?: number;
    refreshTick?: number;
    isReloading?: boolean;
    glow?: GlowPalette;
    navWidth?: number;
    topInset?: number;
    bottomInset?: number;
    expandedMeals?: MealType[];
    navDir?: number;
    viewAnimKey?: number;
    dataVersion?: number;
    imageTaskDone?: boolean;
}
import router from "@ohos:router";
import promptAction from "@ohos:promptAction";
import type common from "@ohos:app.ability.common";
import type { BusinessError } from "@ohos:base";
import hilog from "@ohos:hilog";
import type { MealType, FoodRecord, ExerciseRecord } from '../model/Types';
import { MEAL_ORDER, mealTypeLabel, macroTargetFor } from "@normalized:N&&&entry/src/main/ets/model/Enums&";
import { friendlyDate, todayKey, shiftDay, hourOf } from "@normalized:N&&&entry/src/main/ets/common/DateUtil&";
import { DailyService, HomeData } from "@normalized:N&&&entry/src/main/ets/service/DailyService&";
import { FoodRepo } from "@normalized:N&&&entry/src/main/ets/service/FoodRepo&";
import { ImageService } from "@normalized:N&&&entry/src/main/ets/service/ImageService&";
import { AppState } from "@normalized:N&&&entry/src/main/ets/common/AppState&";
import { COLOR_BG, COLOR_CARD, COLOR_DIVIDER, COLOR_PRIMARY, COLOR_PRIMARY_SOFT, COLOR_TEXT, COLOR_TEXT_SUB, CARD_SHADOW, DUR_NORMAL, DUR_VIEW_SWITCH, GAP, NAV_MARGIN, NAV_RESERVE, PAGE_PAD, RADIUS, glowForHour } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
import type { GlowPalette } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
import { CalorieRing } from "@normalized:N&&&entry/src/main/ets/components/CalorieRing&";
import { MacroBar } from "@normalized:N&&&entry/src/main/ets/components/MacroBar&";
import { RecordRow } from "@normalized:N&&&entry/src/main/ets/components/RecordRow&";
import { FloatingNav, NavItem } from "@normalized:N&&&entry/src/main/ets/components/FloatingNav&";
import { HistoryTab } from "@normalized:N&&&entry/src/main/ets/pages/HistoryTab&";
import { ProfileTab } from "@normalized:N&&&entry/src/main/ets/pages/ProfileTab&";
const DOMAIN = 0x0000;
/** 三个导航项 */
const NAV_ITEMS: NavItem[] = [
    new NavItem('首页', '◉'),
    new NavItem('记录', '▤'),
    new NavItem('我的', '☰')
];
class Index extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__dayKey = new ObservedPropertySimplePU(todayKey(), this, "dayKey");
        this.__data = new ObservedPropertyObjectPU(new HomeData(), this, "data");
        this.__activeTab = new ObservedPropertySimplePU(0, this, "activeTab");
        this.__refreshTick = new ObservedPropertySimplePU(0, this, "refreshTick");
        this.isReloading = false;
        this.__glow = new ObservedPropertyObjectPU(glowForHour(hourOf(Date.now())), this, "glow");
        this.__navWidth = new ObservedPropertySimplePU(0, this, "navWidth");
        this.__topInset = new ObservedPropertySimplePU(0, this, "topInset");
        this.__bottomInset = new ObservedPropertySimplePU(0, this, "bottomInset");
        this.__expandedMeals = new ObservedPropertyObjectPU([], this, "expandedMeals");
        this.__navDir = new ObservedPropertySimplePU(1, this, "navDir");
        this.__viewAnimKey = new ObservedPropertySimplePU(0, this, "viewAnimKey");
        this.__dataVersion = new ObservedPropertySimplePU(0, this, "dataVersion");
        this.imageTaskDone = false;
        this.setInitiallyProvidedValue(params);
        this.declareWatch("refreshTick", this.onRefreshTick);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: Index_Params) {
        if (params.dayKey !== undefined) {
            this.dayKey = params.dayKey;
        }
        if (params.data !== undefined) {
            this.data = params.data;
        }
        if (params.activeTab !== undefined) {
            this.activeTab = params.activeTab;
        }
        if (params.refreshTick !== undefined) {
            this.refreshTick = params.refreshTick;
        }
        if (params.isReloading !== undefined) {
            this.isReloading = params.isReloading;
        }
        if (params.glow !== undefined) {
            this.glow = params.glow;
        }
        if (params.navWidth !== undefined) {
            this.navWidth = params.navWidth;
        }
        if (params.topInset !== undefined) {
            this.topInset = params.topInset;
        }
        if (params.bottomInset !== undefined) {
            this.bottomInset = params.bottomInset;
        }
        if (params.expandedMeals !== undefined) {
            this.expandedMeals = params.expandedMeals;
        }
        if (params.navDir !== undefined) {
            this.navDir = params.navDir;
        }
        if (params.viewAnimKey !== undefined) {
            this.viewAnimKey = params.viewAnimKey;
        }
        if (params.dataVersion !== undefined) {
            this.dataVersion = params.dataVersion;
        }
        if (params.imageTaskDone !== undefined) {
            this.imageTaskDone = params.imageTaskDone;
        }
    }
    updateStateVars(params: Index_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__dayKey.purgeDependencyOnElmtId(rmElmtId);
        this.__data.purgeDependencyOnElmtId(rmElmtId);
        this.__activeTab.purgeDependencyOnElmtId(rmElmtId);
        this.__refreshTick.purgeDependencyOnElmtId(rmElmtId);
        this.__glow.purgeDependencyOnElmtId(rmElmtId);
        this.__navWidth.purgeDependencyOnElmtId(rmElmtId);
        this.__topInset.purgeDependencyOnElmtId(rmElmtId);
        this.__bottomInset.purgeDependencyOnElmtId(rmElmtId);
        this.__expandedMeals.purgeDependencyOnElmtId(rmElmtId);
        this.__navDir.purgeDependencyOnElmtId(rmElmtId);
        this.__viewAnimKey.purgeDependencyOnElmtId(rmElmtId);
        this.__dataVersion.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__dayKey.aboutToBeDeleted();
        this.__data.aboutToBeDeleted();
        this.__activeTab.aboutToBeDeleted();
        this.__refreshTick.aboutToBeDeleted();
        this.__glow.aboutToBeDeleted();
        this.__navWidth.aboutToBeDeleted();
        this.__topInset.aboutToBeDeleted();
        this.__bottomInset.aboutToBeDeleted();
        this.__expandedMeals.aboutToBeDeleted();
        this.__navDir.aboutToBeDeleted();
        this.__viewAnimKey.aboutToBeDeleted();
        this.__dataVersion.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __dayKey: ObservedPropertySimplePU<string>;
    get dayKey() {
        return this.__dayKey.get();
    }
    set dayKey(newValue: string) {
        this.__dayKey.set(newValue);
    }
    private __data: ObservedPropertyObjectPU<HomeData>;
    get data() {
        return this.__data.get();
    }
    set data(newValue: HomeData) {
        this.__data.set(newValue);
    }
    /** 当前视图下标。名字不能叫 tabIndex：ArkUI 的 CustomComponent 已有同名属性 */
    private __activeTab: ObservedPropertySimplePU<number>;
    get activeTab() {
        return this.__activeTab.get();
    }
    set activeTab(newValue: number) {
        this.__activeTab.set(newValue);
    }
    /** 每次从子页面返回自增，驱动子视图重新读数据 */
    /**
     * 数据刷新计数器。
     *
     * 加 @Watch 是有意为之：increment 时直接把数据重读一遍。
     * 只靠 onPageShow 不够稳——从相机/结果页 router.back() 回来时，
     * 生命周期回调的触发时机取决于页面栈实现，实测出现过
     * 「识别完回到首页，热量和营养素还是旧值，退出重进才更新」。
     * 走 @Watch 就是把「刷新」和「生命周期」解耦，只要计数器变了就一定重读。
     */
    /**
     * 子组件刷新信号：+1 只用于驱动 ProfileTab / HistoryTab 重新读取配置。
     *
     * 幂等，绝对不能在 reload() 内部自增！
     * reload() 一旦写这个变量就会触发 @Watch('onRefreshTick')
     * → reload() → 再写 → 无限递归，实测 60 多层后 RangeError: Stack overflow。
     * 它的唯一合法写入点是 onPageShow() 与 switchTo()（用户主动触发的路径）。
     */
    private __refreshTick: ObservedPropertySimplePU<number>;
    get refreshTick() {
        return this.__refreshTick.get();
    }
    set refreshTick(newValue: number) {
        this.__refreshTick.set(newValue);
    }
    /** 重入守卫：兜住任何意外的自我触发，避免再次爆栈 */
    private isReloading: boolean;
    /** 顶部柔光配色，按当前时段取 */
    private __glow: ObservedPropertyObjectPU<GlowPalette>;
    get glow() {
        return this.__glow.get();
    }
    set glow(newValue: GlowPalette) {
        this.__glow.set(newValue);
    }
    /** 悬浮导航栏实测宽度，用于算高亮胶囊位置 */
    private __navWidth: ObservedPropertySimplePU<number>;
    get navWidth() {
        return this.__navWidth.get();
    }
    set navWidth(newValue: number) {
        this.__navWidth.set(newValue);
    }
    /** 顶部安全区（状态栏）高度，全屏布局后需要自行避让 */
    private __topInset: ObservedPropertySimplePU<number>;
    get topInset() {
        return this.__topInset.get();
    }
    set topInset(newValue: number) {
        this.__topInset.set(newValue);
    }
    /** 底部安全区（手势条）高度，导航栏必须抬到它之上才能点到 */
    private __bottomInset: ObservedPropertySimplePU<number>;
    get bottomInset() {
        return this.__bottomInset.get();
    }
    set bottomInset(newValue: number) {
        this.__bottomInset.set(newValue);
    }
    /** 已展开明细的餐次。默认为空即全部收起 */
    private __expandedMeals: ObservedPropertyObjectPU<MealType[]>;
    get expandedMeals() {
        return this.__expandedMeals.get();
    }
    set expandedMeals(newValue: MealType[]) {
        this.__expandedMeals.set(newValue);
    }
    /** 本次切换的方向：1 向右切、-1 向左切，决定入场从哪一侧滑入 */
    private __navDir: ObservedPropertySimplePU<number>;
    get navDir() {
        return this.__navDir.get();
    }
    set navDir(newValue: number) {
        this.__navDir.set(newValue);
    }
    /** 视图入场动画的重放键：每次切换自增，迫使动画重新播放 */
    private __viewAnimKey: ObservedPropertySimplePU<number>;
    get viewAnimKey() {
        return this.__viewAnimKey.get();
    }
    set viewAnimKey(newValue: number) {
        this.__viewAnimKey.set(newValue);
    }
    /**
     * 数据版本号：每次重读当日数据就自增，传给环等自绘组件做强制重绘。
     *
     * 为什么不只依赖子组件的 onDidUpdate / @Watch：
     * 自绘（Canvas）组件在「父组件只换了数据对象」时收不到重绘通知，
     * 会出现数字变了、弧线还是旧比例。显式版本号是最确定的信号。
     */
    private __dataVersion: ObservedPropertySimplePU<number>;
    get dataVersion() {
        return this.__dataVersion.get();
    }
    set dataVersion(newValue: number) {
        this.__dataVersion.set(newValue);
    }
    aboutToAppear(): void {
        this.syncInsets();
        // 注册为「当日数据变更」的接收方：别的页面写入记录后会直接回调这里，
        // 不需要等页面生命周期，这正是「必须退出重进才更新」的解法
        AppState.setDataListener(() => {
            this.dayKey = todayKey();
            this.reload();
        });
        this.reload();
    }
    aboutToDisappear(): void {
        AppState.clearDataListener();
    }
    /** 从子页面返回或回到前台时刷新。
     *
     * refreshTick 必须自增：ProfileTab / HistoryTab 靠它触发 onDidUpdate 重新读配置，
     * 否则从 AI 配置页保存后返回，「我的」页仍会显示未配置。 */
    onPageShow(): void {
        this.glow = glowForHour(hourOf(Date.now()));
        // 安全区是窗口异步量出来的，首次渲染时可能还是 0，回到前台再取一次
        this.syncInsets();
        if (AppState.needRefreshHome) {
            AppState.needRefreshHome = false;
            this.dayKey = todayKey();
            this.switchTo(0);
        }
        // 这里只自增信号、不直接调 reload()：onRefreshTick 会重读数据。
        // 两条路都写会重读两遍，而且容易忘了 reload 里不能再动 refreshTick。
        this.refreshTick++;
    }
    // 注意：这里不要改用 @StorageLink('dataStamp')。
    // 该装饰器在绑定那一刻就要求 AppStorage 里已存在同名键，
    // 而键只在首次写入时创建，冷启动会直接崩（实测进程启动即退出）。
    // 刷新走 AppState.setDataListener 注册的静态回调，见 aboutToAppear。
    /**
     * refreshTick 变化时重读当日数据。
     *
     * 这条链路本身是安全的：reload() 不再回写 refreshTick，
     * 环被打断了。isReloading 只是额外兜一层，
     * 万一以后有人在 reload() 里又写了 refreshTick，也只会被挡掉而不会爆栈。
     */
    onRefreshTick(): void {
        this.reload();
    }
    /** 把 EntryAbility 量好的安全区尺寸取到本地状态，驱动布局重算 */
    private syncInsets(): void {
        this.topInset = AppState.topInset;
        this.bottomInset = AppState.bottomInset;
    }
    /** 按当前下标渲染视图，并播放从切换方向滑入的入场动画 */
    contentView(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.debugLine("entry/src/main/ets/pages/Index.ets(154:5)", "entry");
            Column.width('100%');
            Column.height('100%');
            Column.transition(TransitionEffect.asymmetric(TransitionEffect.OPACITY
                .combine(TransitionEffect.translate({ x: this.navDir >= 0 ? 56 : -56 }))
                .animation({ duration: DUR_VIEW_SWITCH, curve: Curve.FastOutSlowIn }), TransitionEffect.OPACITY
                .animation({ duration: 120, curve: Curve.EaseIn })));
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.activeTab === 0) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.todayView.bind(this)();
                });
            }
            else if (this.activeTab === 1) {
                this.ifElseBranchUpdateFunction(1, () => {
                    {
                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                            if (isInitialRender) {
                                let componentCall = new HistoryTab(this, { dayKey: this.dayKey, refreshTick: this.refreshTick }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Index.ets", line: 158, col: 9 });
                                ViewPU.create(componentCall);
                                let paramsLambda = () => {
                                    return {
                                        dayKey: this.dayKey,
                                        refreshTick: this.refreshTick
                                    };
                                };
                                componentCall.paramsGenerator_ = paramsLambda;
                            }
                            else {
                                this.updateStateVarsOfChildByElmtId(elmtId, {
                                    dayKey: this.dayKey, refreshTick: this.refreshTick
                                });
                            }
                        }, { name: "HistoryTab" });
                    }
                });
            }
            else {
                this.ifElseBranchUpdateFunction(2, () => {
                    {
                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                            if (isInitialRender) {
                                let componentCall = new ProfileTab(this, { refreshTick: this.refreshTick }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Index.ets", line: 160, col: 9 });
                                ViewPU.create(componentCall);
                                let paramsLambda = () => {
                                    return {
                                        refreshTick: this.refreshTick
                                    };
                                };
                                componentCall.paramsGenerator_ = paramsLambda;
                            }
                            else {
                                this.updateStateVarsOfChildByElmtId(elmtId, {
                                    refreshTick: this.refreshTick
                                });
                            }
                        }, { name: "ProfileTab" });
                    }
                });
            }
        }, If);
        If.pop();
        Column.pop();
    }
    /**
     * 把记录里的图片从缓存转存到持久目录。
     *
     * 相机与相册给的 uri 都在临时目录，缓存也可能被系统回收，
     * 直接落库的话过几天图片就丢了。这里在读取记录时顺手转存一份，
     * 并把记录里的 uri 换成持久路径。
     *
     * 注意必须用 update 而不是 addMany：addMany 是纯追加、不按 id 去重，
     * 用它会把当天每条记录都复制一遍。
     */
    /**
     * 图片转存与去重（每次加载只跑一次）。
     *
     * 相机与相册给的 uri 都在临时目录，缓存也可能被系统回收，
     * 直接落库的话过几天图片就丢了，所以要转存到 filesDir。
     *
     * 两个关键点：
     *   1. 整批共用一个 memo（persistAll）。同一餐的多道菜共享同一组照片，
     *      逐条转存会把一张图复制 N 份——实测 2 张照片被复制成 20 个文件，
     *      详情页里图片就会一直重复滚动。
     *   2. 落盘必须用 update 而不是 addMany：后者纯追加、不按 id 去重，
     *      会把当天记录整体复制一遍。
     */
    private persistImages(): void {
        // 先做一次全量收敛：合并内容相同的重复文件并删掉孤立的
        ImageService.dedupeImages(this.data.records, this.uiContext(), (r: FoodRecord) => {
            FoodRepo.update(r);
        });
        for (const r of this.data.records) {
            const list: string[] = r.gallery();
            if (list.length === 0) {
                continue;
            }
            let needs: boolean = false;
            for (const u of list) {
                if (!u.includes('/food_images/')) {
                    needs = true;
                    break;
                }
            }
            if (!needs) {
                continue;
            }
            const saved: string[] = ImageService.persistAll(list, this.uiContext());
            r.imageUris = saved;
            r.imageUri = saved[0];
            FoodRepo.update(r);
            hilog.info(DOMAIN, 'CalorieLite', 'persisted %{public}d image(s) for %{public}s', saved.length, r.id);
        }
    }
    private uiContext(): common.UIAbilityContext {
        return this.getUIContext().getHostContext() as common.UIAbilityContext;
    }
    /** 图片维护是否已跑过，避免重复转存 */
    private imageTaskDone: boolean;
    /**
     * 重读当日数据。
     *
     * 两个硬性约束，改这个函数前务必先看懂：
     *   1. 绝对不要在这里写 this.refreshTick！它是 @Watch('onRefreshTick')
     *      的触发源，而 onRefreshTick 又会调回本函数，
     *      于是 reload → tick++ → watch → reload → … 无限递归，
     *      60 多层后直接 RangeError: Stack overflow（已实测）。
     *      子组件的刷新信号只在 onPageShow / switchTo 里 +1。
     *   2. 不要在这里同步调用需要 UIContext 的操作（如取沙箱路径），
     *      aboutToAppear 阶段组件尚未挂载，getUIContext 会失败。
     *      图片相关的维护交给 scheduleImageMaintenance 延后执行。
     */
    private reload(): void {
        // 重入守卫：任何意外触发的嵌套调用直接返回，避免栈被撑爆
        if (this.isReloading) {
            return;
        }
        this.isReloading = true;
        try {
            this.data = DailyService.homeData(this.dayKey);
            AppState.mirrorToday(this.data.summary);
            // 自增版本号，驱动环等自绘组件重绘
            this.dataVersion++;
            this.scheduleImageMaintenance();
        }
        catch (err) {
            const e: Error = err as Error;
            hilog.error(DOMAIN, 'CalorieLite', 'reload failed: %{public}s', e.message);
        }
        finally {
            this.isReloading = false;
        }
    }
    /** 布局完成后再做图片转存/去重，避免在构建期取 UIContext */
    private scheduleImageMaintenance(): void {
        if (this.imageTaskDone) {
            return;
        }
        setTimeout(() => {
            if (this.imageTaskDone) {
                return;
            }
            this.imageTaskDone = true;
            this.persistImages();
        }, 300);
    }
    /** 切换视图：改下标并刷新数据 */
    private switchTo(index: number): void {
        if (index === this.activeTab) {
            // 已经在这一页：仍然刷新一次，避免「点了没反应但数据其实变了」的情况
            if (index === 0) {
                this.dayKey = todayKey();
                this.refreshTick++;
            }
            return;
        }
        // 「我的」页可能刚改过档案，清掉脏标记；
        // 实际重算由下面 index === 0 分支的自增信号统一触发
        if (AppState.profileDirty) {
            AppState.profileDirty = false;
        }
        this.navDir = index > this.activeTab ? 1 : -1;
        this.activeTab = index;
        // 重放入场动画
        this.viewAnimKey++;
        // 回到首页时按当天重读，保证刚记录的餐次立刻出现
        if (index === 0) {
            this.dayKey = todayKey();
            this.refreshTick++;
        }
    }
    private mealKcal(records: FoodRecord[]): number {
        let sum: number = 0;
        for (const r of records) {
            sum += r.kcal;
        }
        return Math.round(sum);
    }
    /** 删除一条记录，删前确认 */
    private async confirmDelete(record: FoodRecord): Promise<void> {
        try {
            const result = await promptAction.showDialog({
                title: '删除记录',
                message: `确定删除「${record.name}」吗？`,
                buttons: [
                    { text: '取消', color: COLOR_TEXT_SUB },
                    { text: '删除', color: '#E5533D' }
                ]
            });
            if (result.index === 1) {
                FoodRepo.remove(record.dayKey, record.id);
                this.reload();
                this.refreshTick++;
            }
        }
        catch (err) {
            hilog.error(DOMAIN, 'CalorieLite', 'delete dialog failed: %{public}s', JSON.stringify(err));
        }
    }
    private shiftDate(delta: number): void {
        const next: string = shiftDay(this.dayKey, delta);
        if (next > todayKey()) {
            return;
        }
        this.dayKey = next;
        this.reload();
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create({ alignContent: Alignment.TopStart });
            Stack.debugLine("entry/src/main/ets/pages/Index.ets(348:5)", "entry");
            Stack.width('100%');
            Stack.height('100%');
            Stack.expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM]);
            Stack.backgroundColor(COLOR_BG);
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // ---------------------------------------------------- 1. 柔光背景
            // 铺满整屏（含状态栏区域），这才是「沉浸」的前提
            Column.create();
            Column.debugLine("entry/src/main/ets/pages/Index.ets(351:7)", "entry");
            // ---------------------------------------------------- 1. 柔光背景
            // 铺满整屏（含状态栏区域），这才是「沉浸」的前提
            Column.width('100%');
            // ---------------------------------------------------- 1. 柔光背景
            // 铺满整屏（含状态栏区域），这才是「沉浸」的前提
            Column.height('100%');
            // ---------------------------------------------------- 1. 柔光背景
            // 铺满整屏（含状态栏区域），这才是「沉浸」的前提
            Column.linearGradient({
                angle: 180,
                colors: [[this.glow.from, 0.0], [this.glow.to, 0.42], [COLOR_BG, 1.0]]
            });
        }, Column);
        // ---------------------------------------------------- 1. 柔光背景
        // 铺满整屏（含状态栏区域），这才是「沉浸」的前提
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // ---------------------------------------------------- 2. 内容层
            // 只渲染当前视图，靠入场动画完成切换。
            //
            // 之前试过让三个视图常驻 Stack、用 opacity 切换，结果未激活视图
            // 虽然透明但仍参与命中测试，把下面的按钮点击全吃掉了
            // （实测拍照按钮和餐次折叠都点不动）。条件渲染没有这个问题。
            Column.create();
            Column.debugLine("entry/src/main/ets/pages/Index.ets(365:7)", "entry");
            // ---------------------------------------------------- 2. 内容层
            // 只渲染当前视图，靠入场动画完成切换。
            //
            // 之前试过让三个视图常驻 Stack、用 opacity 切换，结果未激活视图
            // 虽然透明但仍参与命中测试，把下面的按钮点击全吃掉了
            // （实测拍照按钮和餐次折叠都点不动）。条件渲染没有这个问题。
            Column.width('100%');
            // ---------------------------------------------------- 2. 内容层
            // 只渲染当前视图，靠入场动画完成切换。
            //
            // 之前试过让三个视图常驻 Stack、用 opacity 切换，结果未激活视图
            // 虽然透明但仍参与命中测试，把下面的按钮点击全吃掉了
            // （实测拍照按钮和餐次折叠都点不动）。条件渲染没有这个问题。
            Column.height('100%');
            // ---------------------------------------------------- 2. 内容层
            // 只渲染当前视图，靠入场动画完成切换。
            //
            // 之前试过让三个视图常驻 Stack、用 opacity 切换，结果未激活视图
            // 虽然透明但仍参与命中测试，把下面的按钮点击全吃掉了
            // （实测拍照按钮和餐次折叠都点不动）。条件渲染没有这个问题。
            Column.padding({ top: this.topInset });
            // ---------------------------------------------------- 2. 内容层
            // 只渲染当前视图，靠入场动画完成切换。
            //
            // 之前试过让三个视图常驻 Stack、用 opacity 切换，结果未激活视图
            // 虽然透明但仍参与命中测试，把下面的按钮点击全吃掉了
            // （实测拍照按钮和餐次折叠都点不动）。条件渲染没有这个问题。
            Column.clip(true);
        }, Column);
        this.contentView.bind(this)();
        // ---------------------------------------------------- 2. 内容层
        // 只渲染当前视图，靠入场动画完成切换。
        //
        // 之前试过让三个视图常驻 Stack、用 opacity 切换，结果未激活视图
        // 虽然透明但仍参与命中测试，把下面的按钮点击全吃掉了
        // （实测拍照按钮和餐次折叠都点不动）。条件渲染没有这个问题。
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // ---------------------------------------------------- 3. 悬浮导航栏
            // 关键：bottom 里必须加上 bottomInset。
            // 底部手势条区域会吃掉点击，导航栏压在上面就会「点了没反应」。
            Column.create();
            Column.debugLine("entry/src/main/ets/pages/Index.ets(376:7)", "entry");
            // ---------------------------------------------------- 3. 悬浮导航栏
            // 关键：bottom 里必须加上 bottomInset。
            // 底部手势条区域会吃掉点击，导航栏压在上面就会「点了没反应」。
            Column.width('100%');
            // ---------------------------------------------------- 3. 悬浮导航栏
            // 关键：bottom 里必须加上 bottomInset。
            // 底部手势条区域会吃掉点击，导航栏压在上面就会「点了没反应」。
            Column.height('100%');
            // ---------------------------------------------------- 3. 悬浮导航栏
            // 关键：bottom 里必须加上 bottomInset。
            // 底部手势条区域会吃掉点击，导航栏压在上面就会「点了没反应」。
            Column.padding({ left: NAV_MARGIN, right: NAV_MARGIN, bottom: this.bottomInset + NAV_MARGIN + 18 });
            // ---------------------------------------------------- 3. 悬浮导航栏
            // 关键：bottom 里必须加上 bottomInset。
            // 底部手势条区域会吃掉点击，导航栏压在上面就会「点了没反应」。
            Column.justifyContent(FlexAlign.End);
            // ---------------------------------------------------- 3. 悬浮导航栏
            // 关键：bottom 里必须加上 bottomInset。
            // 底部手势条区域会吃掉点击，导航栏压在上面就会「点了没反应」。
            Column.hitTestBehavior(HitTestMode.None);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            __Common__.create();
            __Common__.onAreaChange((oldValue: Area, newValue: Area) => {
                this.navWidth = Number.parseFloat(`${newValue.width}`);
            });
        }, __Common__);
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new FloatingNav(this, {
                        items: NAV_ITEMS,
                        activeIndex: this.activeTab,
                        barWidth: this.navWidth,
                        onSelect: (index: number) => {
                            this.switchTo(index);
                        }
                    }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Index.ets", line: 377, col: 9 });
                    ViewPU.create(componentCall);
                    let paramsLambda = () => {
                        return {
                            items: NAV_ITEMS,
                            activeIndex: this.activeTab,
                            barWidth: this.navWidth,
                            onSelect: (index: number) => {
                                this.switchTo(index);
                            }
                        };
                    };
                    componentCall.paramsGenerator_ = paramsLambda;
                }
                else {
                    this.updateStateVarsOfChildByElmtId(elmtId, {
                        items: NAV_ITEMS,
                        activeIndex: this.activeTab,
                        barWidth: this.navWidth
                    });
                }
            }, { name: "FloatingNav" });
        }
        __Common__.pop();
        // ---------------------------------------------------- 3. 悬浮导航栏
        // 关键：bottom 里必须加上 bottomInset。
        // 底部手势条区域会吃掉点击，导航栏压在上面就会「点了没反应」。
        Column.pop();
        Stack.pop();
    }
    // ================================================== 首页
    todayView(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.debugLine("entry/src/main/ets/pages/Index.ets(409:5)", "entry");
            Column.width('100%');
            Column.height('100%');
        }, Column);
        this.dateBar.bind(this)();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Scroll.create();
            Scroll.debugLine("entry/src/main/ets/pages/Index.ets(412:7)", "entry");
            Scroll.layoutWeight(1);
            Scroll.scrollBar(BarState.Off);
            Scroll.align(Alignment.Top);
        }, Scroll);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: GAP });
            Column.debugLine("entry/src/main/ets/pages/Index.ets(413:9)", "entry");
            Column.width('100%');
            Column.padding({ left: PAGE_PAD, right: PAGE_PAD, top: 4 });
        }, Column);
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new CalorieRing(this, {
                        intake: this.data.summary.intake,
                        budget: this.data.summary.budget,
                        exerciseKcal: this.data.summary.exerciseKcal,
                        deficit: this.data.summary.deficit,
                        refreshKey: this.dataVersion
                    }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Index.ets", line: 414, col: 11 });
                    ViewPU.create(componentCall);
                    let paramsLambda = () => {
                        return {
                            intake: this.data.summary.intake,
                            budget: this.data.summary.budget,
                            exerciseKcal: this.data.summary.exerciseKcal,
                            deficit: this.data.summary.deficit,
                            refreshKey: this.dataVersion
                        };
                    };
                    componentCall.paramsGenerator_ = paramsLambda;
                }
                else {
                    this.updateStateVarsOfChildByElmtId(elmtId, {
                        intake: this.data.summary.intake,
                        budget: this.data.summary.budget,
                        exerciseKcal: this.data.summary.exerciseKcal,
                        deficit: this.data.summary.deficit,
                        refreshKey: this.dataVersion
                    });
                }
            }, { name: "CalorieRing" });
        }
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 结算评语
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/Index.ets(423:11)", "entry");
            // 结算评语
            Row.width('100%');
            // 结算评语
            Row.padding({ left: 4, right: 4 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(DailyService.verdict(this.data.summary));
            Text.debugLine("entry/src/main/ets/pages/Index.ets(424:13)", "entry");
            Text.fontSize(13);
            Text.fontColor(COLOR_TEXT_SUB);
            Text.layoutWeight(1);
        }, Text);
        Text.pop();
        // 结算评语
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 14 });
            Row.debugLine("entry/src/main/ets/pages/Index.ets(432:11)", "entry");
            Row.width('100%');
            Row.padding({ left: 4, right: 4 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.data.streak > 0) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.chip.bind(this)('连续达标', () => this.data.streak, '天');
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.data.summary.exerciseKcal > 0) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.chip.bind(this)('运动 +', () => this.data.summary.exerciseKcal, '');
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        Row.pop();
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new 
                    // 营养素卡片常显：没有记录时也要能看到推荐量，
                    // 否则用户不知道今天该吃多少
                    MacroBar(this, {
                        protein: this.data.summary.protein,
                        fat: this.data.summary.fat,
                        carb: this.data.summary.carb,
                        // 推荐克数按当日实际预算推算，不写死数字：
                        // 写死会在换人/换目标后与顶部预算自相矛盾
                        carbTarget: macroTargetFor(this.data.summary.budget).carb,
                        proteinTarget: macroTargetFor(this.data.summary.budget).protein,
                        fatTarget: macroTargetFor(this.data.summary.budget).fat
                    }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Index.ets", line: 445, col: 11 });
                    ViewPU.create(componentCall);
                    let paramsLambda = () => {
                        return {
                            protein: this.data.summary.protein,
                            fat: this.data.summary.fat,
                            carb: this.data.summary.carb,
                            // 推荐克数按当日实际预算推算，不写死数字：
                            // 写死会在换人/换目标后与顶部预算自相矛盾
                            carbTarget: macroTargetFor(this.data.summary.budget).carb,
                            proteinTarget: macroTargetFor(this.data.summary.budget).protein,
                            fatTarget: macroTargetFor(this.data.summary.budget).fat
                        };
                    };
                    componentCall.paramsGenerator_ = paramsLambda;
                }
                else {
                    this.updateStateVarsOfChildByElmtId(elmtId, {
                        protein: this.data.summary.protein,
                        fat: this.data.summary.fat,
                        carb: this.data.summary.carb,
                        // 推荐克数按当日实际预算推算，不写死数字：
                        // 写死会在换人/换目标后与顶部预算自相矛盾
                        carbTarget: macroTargetFor(this.data.summary.budget).carb,
                        proteinTarget: macroTargetFor(this.data.summary.budget).protein,
                        fatTarget: macroTargetFor(this.data.summary.budget).fat
                    });
                }
            }, { name: "MacroBar" });
        }
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            ForEach.create();
            const forEachItemGenFunction = _item => {
                const meal = _item;
                this.mealSection.bind(this)(meal);
            };
            this.forEachUpdateFunction(elmtId, MEAL_ORDER, forEachItemGenFunction, (meal: MealType) => `${meal}-${this.data.summary.recordCount}`, false, false);
        }, ForEach);
        ForEach.pop();
        this.exerciseSection.bind(this)();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 给悬浮导航栏留出空间
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/Index.ets(463:11)", "entry");
            // 给悬浮导航栏留出空间
            Row.height(NAV_RESERVE);
        }, Row);
        // 给悬浮导航栏留出空间
        Row.pop();
        Column.pop();
        Scroll.pop();
        // 底部主操作只剩拍照识别
        this.cameraBar.bind(this)();
        Column.pop();
    }
    /** 日期切换条 */
    dateBar(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/Index.ets(482:5)", "entry");
            Row.width('100%');
            Row.padding({ left: PAGE_PAD, right: PAGE_PAD, top: 10, bottom: 10 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithChild({ type: ButtonType.Circle });
            Button.debugLine("entry/src/main/ets/pages/Index.ets(483:7)", "entry");
            Button.width(36);
            Button.height(36);
            Button.backgroundColor(COLOR_CARD);
            Button.shadow(CARD_SHADOW);
            Button.onClick(() => {
                this.shiftDate(-1);
            });
        }, Button);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('‹');
            Text.debugLine("entry/src/main/ets/pages/Index.ets(484:9)", "entry");
            Text.fontSize(20);
            Text.fontColor(COLOR_TEXT);
        }, Text);
        Text.pop();
        Button.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 2 });
            Column.debugLine("entry/src/main/ets/pages/Index.ets(494:7)", "entry");
            Column.layoutWeight(1);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.dayKey === todayKey() ? '今天' : friendlyDate(this.dayKey));
            Text.debugLine("entry/src/main/ets/pages/Index.ets(495:9)", "entry");
            Text.fontSize(17);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(COLOR_TEXT);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 副标题只在「今天」时补一个日期；看历史日期时标题本身就是日期，
            // 再重复一次没有信息量
            Text.create(this.dayKey === todayKey() ? friendlyDate(this.dayKey) : '查看历史');
            Text.debugLine("entry/src/main/ets/pages/Index.ets(501:9)", "entry");
            // 副标题只在「今天」时补一个日期；看历史日期时标题本身就是日期，
            // 再重复一次没有信息量
            Text.fontSize(12);
            // 副标题只在「今天」时补一个日期；看历史日期时标题本身就是日期，
            // 再重复一次没有信息量
            Text.fontColor(COLOR_TEXT_SUB);
        }, Text);
        // 副标题只在「今天」时补一个日期；看历史日期时标题本身就是日期，
        // 再重复一次没有信息量
        Text.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithChild({ type: ButtonType.Circle });
            Button.debugLine("entry/src/main/ets/pages/Index.ets(507:7)", "entry");
            Button.width(36);
            Button.height(36);
            Button.backgroundColor(COLOR_CARD);
            Button.shadow(CARD_SHADOW);
            Button.enabled(this.dayKey !== todayKey());
            Button.opacity(this.dayKey === todayKey() ? 0.5 : 1);
            Button.onClick(() => {
                this.shiftDate(1);
            });
        }, Button);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('›');
            Text.debugLine("entry/src/main/ets/pages/Index.ets(508:9)", "entry");
            Text.fontSize(20);
            Text.fontColor(this.dayKey === todayKey() ? COLOR_DIVIDER : COLOR_TEXT);
        }, Text);
        Text.pop();
        Button.pop();
        Row.pop();
    }
    /**
     * 一个小标签：前缀文字 + 会滚动的数字 + 单位。
     *
     * 数字必须走 RollingNumber 且由这里内联渲染：
     * 之前整个标签是 this.chip(`连续达标 ${n} 天}`) 这样传字符串，
     * @Builder 的参数只求值一次，数字变了标签也不会更新；
     * 而且纯 Text 是瞬间跳变，没有滚动感。
     */
    chip(label: string, value: () => number, unit: string, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 2 });
            Row.debugLine("entry/src/main/ets/pages/Index.ets(536:5)", "entry");
            Row.alignItems(VerticalAlign.Center);
            Row.padding({ left: 10, right: 10, top: 5, bottom: 5 });
            Row.backgroundColor(COLOR_PRIMARY_SOFT);
            Row.borderRadius(12);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(label);
            Text.debugLine("entry/src/main/ets/pages/Index.ets(537:7)", "entry");
            Text.fontSize(12);
            Text.fontColor(COLOR_PRIMARY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(unit);
            Text.debugLine("entry/src/main/ets/pages/Index.ets(547:7)", "entry");
            Text.fontSize(12);
            Text.fontColor(COLOR_PRIMARY);
        }, Text);
        Text.pop();
        Row.pop();
    }
    /** 展开/收起某一餐 */
    private toggleMeal(meal: MealType): void {
        const next: MealType[] = [];
        let removed: boolean = false;
        for (const m of this.expandedMeals) {
            if (m === meal) {
                removed = true;
            }
            else {
                next.push(m);
            }
        }
        if (!removed) {
            next.push(meal);
        }
        this.expandedMeals = next;
    }
    private isExpanded(meal: MealType): boolean {
        return this.expandedMeals.includes(meal);
    }
    /**
     * 一餐的分组。
     *
     * 默认收起，只显示餐次名与合计热量；点标题才展开逐条明细。
     * 刚记完一餐时列表会一下子变很长，收起是更好的默认状态。
     */
    mealSection(meal: MealType, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 8 });
            Column.debugLine("entry/src/main/ets/pages/Index.ets(586:5)", "entry");
            Column.width('100%');
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 标题行：整行可点，右侧箭头随展开状态旋转
            Row.create({ space: 6 });
            Row.debugLine("entry/src/main/ets/pages/Index.ets(588:7)", "entry");
            // 标题行：整行可点，右侧箭头随展开状态旋转
            Row.width('100%');
            // 标题行：整行可点，右侧箭头随展开状态旋转
            Row.padding({ left: 4, right: 4, top: 4, bottom: 4 });
            // 标题行：整行可点，右侧箭头随展开状态旋转
            Row.onClick(() => {
                this.toggleMeal(meal);
            });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(mealTypeLabel(meal));
            Text.debugLine("entry/src/main/ets/pages/Index.ets(589:9)", "entry");
            Text.fontSize(15);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(COLOR_TEXT);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
            Blank.debugLine("entry/src/main/ets/pages/Index.ets(594:9)", "entry");
        }, Blank);
        Blank.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.mealKcal(DailyService.recordsOf(this.data.records, meal)) > 0
                ? `${this.mealKcal(DailyService.recordsOf(this.data.records, meal))} 千卡`
                : '');
            Text.debugLine("entry/src/main/ets/pages/Index.ets(596:9)", "entry");
            Text.fontSize(13);
            Text.fontColor(COLOR_TEXT_SUB);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('⌄');
            Text.debugLine("entry/src/main/ets/pages/Index.ets(602:9)", "entry");
            globalThis.Context.animation({ duration: DUR_NORMAL, curve: Curve.EaseInOut });
            Text.fontSize(14);
            Text.fontColor(COLOR_TEXT_SUB);
            Text.rotate({ angle: this.isExpanded(meal) ? 180 : 0 });
            globalThis.Context.animation(null);
        }, Text);
        Text.pop();
        // 标题行：整行可点，右侧箭头随展开状态旋转
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.isExpanded(meal)) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create({ space: 8 });
                        Column.debugLine("entry/src/main/ets/pages/Index.ets(615:9)", "entry");
                        Column.width('100%');
                        Column.transition(TransitionEffect.OPACITY
                            .combine(TransitionEffect.scale({ x: 1, y: 0.94, centerY: '0%' }))
                            .animation({ duration: DUR_NORMAL, curve: Curve.EaseOut }));
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        If.create();
                        if (DailyService.recordsOf(this.data.records, meal).length === 0) {
                            this.ifElseBranchUpdateFunction(0, () => {
                                this.observeComponentCreation2((elmtId, isInitialRender) => {
                                    Row.create();
                                    Row.debugLine("entry/src/main/ets/pages/Index.ets(617:13)", "entry");
                                    Row.width('100%');
                                    Row.padding(14);
                                    Row.backgroundColor(COLOR_CARD);
                                    Row.borderRadius(RADIUS);
                                    Row.shadow(CARD_SHADOW);
                                }, Row);
                                this.observeComponentCreation2((elmtId, isInitialRender) => {
                                    Text.create('还没有记录');
                                    Text.debugLine("entry/src/main/ets/pages/Index.ets(618:15)", "entry");
                                    Text.fontSize(13);
                                    Text.fontColor(COLOR_TEXT_SUB);
                                }, Text);
                                Text.pop();
                                Row.pop();
                            });
                        }
                        else {
                            this.ifElseBranchUpdateFunction(1, () => {
                                this.observeComponentCreation2((elmtId, isInitialRender) => {
                                    ForEach.create();
                                    const forEachItemGenFunction = _item => {
                                        const record = _item;
                                        {
                                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                                if (isInitialRender) {
                                                    let componentCall = new RecordRow(this, {
                                                        record: record,
                                                        onDelete: (id: string) => {
                                                            const target: FoodRecord | undefined = this.data.records.find((r: FoodRecord) => r.id === id);
                                                            if (target !== undefined) {
                                                                this.confirmDelete(target);
                                                            }
                                                        }
                                                    }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Index.ets", line: 629, col: 15 });
                                                    ViewPU.create(componentCall);
                                                    let paramsLambda = () => {
                                                        return {
                                                            record: record,
                                                            onDelete: (id: string) => {
                                                                const target: FoodRecord | undefined = this.data.records.find((r: FoodRecord) => r.id === id);
                                                                if (target !== undefined) {
                                                                    this.confirmDelete(target);
                                                                }
                                                            }
                                                        };
                                                    };
                                                    componentCall.paramsGenerator_ = paramsLambda;
                                                }
                                                else {
                                                    this.updateStateVarsOfChildByElmtId(elmtId, {
                                                        record: record
                                                    });
                                                }
                                            }, { name: "RecordRow" });
                                        }
                                    };
                                    this.forEachUpdateFunction(elmtId, DailyService.recordsOf(this.data.records, meal), forEachItemGenFunction, (record: FoodRecord) => record.id, false, false);
                                }, ForEach);
                                ForEach.pop();
                            });
                        }
                    }, If);
                    If.pop();
                    Column.pop();
                });
            }
            else if (DailyService.recordsOf(this.data.records, meal).length > 0) {
                this.ifElseBranchUpdateFunction(1, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        // 收起态给一行摘要，避免完全看不到吃了什么
                        Row.create();
                        Row.debugLine("entry/src/main/ets/pages/Index.ets(649:9)", "entry");
                        // 收起态给一行摘要，避免完全看不到吃了什么
                        Row.width('100%');
                        // 收起态给一行摘要，避免完全看不到吃了什么
                        Row.padding({ left: 4, right: 4, bottom: 2 });
                    }, Row);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(this.mealSummary(meal));
                        Text.debugLine("entry/src/main/ets/pages/Index.ets(650:11)", "entry");
                        Text.fontSize(12);
                        Text.fontColor(COLOR_TEXT_SUB);
                        Text.maxLines(1);
                        Text.textOverflow({ overflow: TextOverflow.Ellipsis });
                    }, Text);
                    Text.pop();
                    // 收起态给一行摘要，避免完全看不到吃了什么
                    Row.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(2, () => {
                });
            }
        }, If);
        If.pop();
        Column.pop();
    }
    /** 收起态的一行摘要，例如「白米饭、番茄炒蛋」 */
    private mealSummary(meal: MealType): string {
        const list: FoodRecord[] = DailyService.recordsOf(this.data.records, meal);
        const names: string[] = [];
        for (const r of list) {
            names.push(r.name);
            if (names.length >= 4) {
                break;
            }
        }
        return names.length < list.length ? `${names.join('、')} 等 ${list.length} 项` : names.join('、');
    }
    exerciseSection(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 8 });
            Column.debugLine("entry/src/main/ets/pages/Index.ets(678:5)", "entry");
            Column.width('100%');
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/Index.ets(679:7)", "entry");
            Row.width('100%');
            Row.padding({ left: 4, right: 4 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('运动消耗');
            Text.debugLine("entry/src/main/ets/pages/Index.ets(680:9)", "entry");
            Text.fontSize(15);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(COLOR_TEXT);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
            Blank.debugLine("entry/src/main/ets/pages/Index.ets(684:9)", "entry");
        }, Blank);
        Blank.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.data.summary.exerciseKcal > 0) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(`${this.data.summary.exerciseKcal} 千卡`);
                        Text.debugLine("entry/src/main/ets/pages/Index.ets(686:11)", "entry");
                        Text.fontSize(13);
                        Text.fontColor(COLOR_TEXT_SUB);
                    }, Text);
                    Text.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.data.exercises.length === 0) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Row.create();
                        Row.debugLine("entry/src/main/ets/pages/Index.ets(695:9)", "entry");
                        Row.width('100%');
                        Row.padding(14);
                        Row.backgroundColor(COLOR_CARD);
                        Row.borderRadius(RADIUS);
                        Row.shadow(CARD_SHADOW);
                    }, Row);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('没有运动记录');
                        Text.debugLine("entry/src/main/ets/pages/Index.ets(696:11)", "entry");
                        Text.fontSize(13);
                        Text.fontColor(COLOR_TEXT_SUB);
                    }, Text);
                    Text.pop();
                    Row.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        ForEach.create();
                        const forEachItemGenFunction = _item => {
                            const item = _item;
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Row.create({ space: 10 });
                                Row.debugLine("entry/src/main/ets/pages/Index.ets(707:11)", "entry");
                                Row.width('100%');
                                Row.padding(14);
                                Row.backgroundColor(COLOR_CARD);
                                Row.borderRadius(RADIUS);
                                Row.shadow(CARD_SHADOW);
                            }, Row);
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Column.create({ space: 3 });
                                Column.debugLine("entry/src/main/ets/pages/Index.ets(708:13)", "entry");
                                Column.alignItems(HorizontalAlign.Start);
                                Column.layoutWeight(1);
                            }, Column);
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Text.create(item.name);
                                Text.debugLine("entry/src/main/ets/pages/Index.ets(709:15)", "entry");
                                Text.fontSize(15);
                                Text.fontColor(COLOR_TEXT);
                            }, Text);
                            Text.pop();
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Text.create(item.minutes > 0 ? `${item.minutes} 分钟` : '未记录时长');
                                Text.debugLine("entry/src/main/ets/pages/Index.ets(712:15)", "entry");
                                Text.fontSize(12);
                                Text.fontColor(COLOR_TEXT_SUB);
                            }, Text);
                            Text.pop();
                            Column.pop();
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Text.create(`${item.kcal} 千卡`);
                                Text.debugLine("entry/src/main/ets/pages/Index.ets(719:13)", "entry");
                                Text.fontSize(15);
                                Text.fontColor(COLOR_TEXT);
                            }, Text);
                            Text.pop();
                            Row.pop();
                        };
                        this.forEachUpdateFunction(elmtId, this.data.exercises, forEachItemGenFunction, (item: ExerciseRecord) => item.id, false, false);
                    }, ForEach);
                    ForEach.pop();
                });
            }
        }, If);
        If.pop();
        Column.pop();
    }
    /** 底部唯一的操作入口：拍照识别 */
    cameraBar(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/Index.ets(737:5)", "entry");
            Row.width('100%');
            Row.padding({ left: PAGE_PAD, right: PAGE_PAD, top: 8, bottom: NAV_RESERVE + 12 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithChild({ type: ButtonType.Capsule });
            Button.debugLine("entry/src/main/ets/pages/Index.ets(738:7)", "entry");
            Button.width('100%');
            Button.height(50);
            Button.backgroundColor(COLOR_PRIMARY);
            Button.shadow(CARD_SHADOW);
            Button.onClick(() => {
                try {
                    router.pushUrl({ url: 'pages/Camera' });
                }
                catch (err) {
                    const e: BusinessError = err as BusinessError;
                    hilog.error(DOMAIN, 'CalorieLite', 'goCamera failed: %{public}s', e.message);
                }
            });
        }, Button);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('拍照识别热量');
            Text.debugLine("entry/src/main/ets/pages/Index.ets(739:9)", "entry");
            Text.fontSize(16);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(Color.White);
        }, Text);
        Text.pop();
        Button.pop();
        Row.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
    public __resetStateVarsOnReuse__Internal(params: Object): void {
    }
    static getEntryName(): string {
        return "Index";
    }
}
registerNamedRoute(() => new Index(undefined, {}), "", { bundleName: "Calories.Lite.Test", moduleName: "entry", pagePath: "pages/Index", pageFullPath: "entry/src/main/ets/pages/Index", integratedHsp: "false", moduleType: "followWithHap" });
