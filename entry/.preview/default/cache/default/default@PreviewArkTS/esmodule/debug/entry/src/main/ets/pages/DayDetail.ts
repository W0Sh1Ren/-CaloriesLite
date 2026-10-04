if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface DayDetail_Params {
    dayKey?: string;
    summary?: DailySummary;
    records?: FoodRecord[];
    persisted?: boolean;
}
import router from "@ohos:router";
import type common from "@ohos:app.ability.common";
import hilog from "@ohos:hilog";
import { DailySummary } from "@normalized:N&&&entry/src/main/ets/model/Types&";
import type { MealType, FoodRecord } from "@normalized:N&&&entry/src/main/ets/model/Types&";
import { MEAL_ORDER, mealTypeLabel, macroTargetFor } from "@normalized:N&&&entry/src/main/ets/model/Enums&";
import { friendlyDate, todayKey, timeLabel } from "@normalized:N&&&entry/src/main/ets/common/DateUtil&";
import { DailyService } from "@normalized:N&&&entry/src/main/ets/service/DailyService&";
import { FoodRepo } from "@normalized:N&&&entry/src/main/ets/service/FoodRepo&";
import { ImageService } from "@normalized:N&&&entry/src/main/ets/service/ImageService&";
import { MacroBar } from "@normalized:N&&&entry/src/main/ets/components/MacroBar&";
import { MealGallery } from "@normalized:N&&&entry/src/main/ets/components/MealGallery&";
import { CARD_SHADOW, COLOR_BG, COLOR_CARD, COLOR_DIVIDER, COLOR_OK, COLOR_PRIMARY, COLOR_TEXT, COLOR_TEXT_SUB, COLOR_WARN, GAP, PAGE_PAD, RADIUS } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
const DOMAIN = 0x0000;
/** 餐次预览框高度 */
const FRAME_HEIGHT: number = 190;
class DayDetail extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__dayKey = new ObservedPropertySimplePU(todayKey(), this, "dayKey");
        this.__summary = new ObservedPropertyObjectPU(new DailySummary('', 0, 0, 0, 0, 0, 0, 0), this, "summary");
        this.__records = new ObservedPropertyObjectPU([], this, "records");
        this.__persisted = new ObservedPropertySimplePU(false, this, "persisted");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: DayDetail_Params) {
        if (params.dayKey !== undefined) {
            this.dayKey = params.dayKey;
        }
        if (params.summary !== undefined) {
            this.summary = params.summary;
        }
        if (params.records !== undefined) {
            this.records = params.records;
        }
        if (params.persisted !== undefined) {
            this.persisted = params.persisted;
        }
    }
    updateStateVars(params: DayDetail_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__dayKey.purgeDependencyOnElmtId(rmElmtId);
        this.__summary.purgeDependencyOnElmtId(rmElmtId);
        this.__records.purgeDependencyOnElmtId(rmElmtId);
        this.__persisted.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__dayKey.aboutToBeDeleted();
        this.__summary.aboutToBeDeleted();
        this.__records.aboutToBeDeleted();
        this.__persisted.aboutToBeDeleted();
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
    private __summary: ObservedPropertyObjectPU<DailySummary>;
    get summary() {
        return this.__summary.get();
    }
    set summary(newValue: DailySummary) {
        this.__summary.set(newValue);
    }
    private __records: ObservedPropertyObjectPU<FoodRecord[]>;
    get records() {
        return this.__records.get();
    }
    set records(newValue: FoodRecord[]) {
        this.__records.set(newValue);
    }
    /** 防止同一张图被重复转存 */
    private __persisted: ObservedPropertySimplePU<boolean>;
    get persisted() {
        return this.__persisted.get();
    }
    set persisted(newValue: boolean) {
        this.__persisted.set(newValue);
    }
    aboutToAppear(): void {
        const raw: Object | undefined = router.getParams();
        if (raw !== undefined && raw !== null) {
            const params = raw as Record<string, Object>;
            const d: Object = params['dayKey'];
            if (d !== undefined && d !== null) {
                const s: string = `${d}`;
                if (s.length > 0 && s !== 'undefined') {
                    this.dayKey = s;
                }
            }
        }
        this.load();
    }
    onPageShow(): void {
        this.load();
    }
    private load(): void {
        this.summary = DailyService.summaryOf(this.dayKey);
        this.records = FoodRepo.loadDay(this.dayKey);
        this.persistImages();
    }
    /**
     * 图片转存与去重（每次进页面只跑一次）。
     *
     * 相机给的图片在临时目录，缓存也可能被系统回收，所以要转存到 filesDir。
     *
     * 两个关键点：
     *   1. dedupeImages 先把内容完全相同的重复文件合并掉。
     *      早期版本按记录逐条转存，把同一组照片复制了 N 份
     *      （实测 2 张照片变成 20 个文件，预览框里图片一直重复滚动）。
     *   2. 转存用 persistAll 整批共用一个 memo，避免又造出一批重复文件。
     *      落盘用 update 而不是 addMany，后者纯追加不去重。
     */
    private persistImages(): void {
        if (this.persisted) {
            return;
        }
        this.persisted = true;
        const ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
        ImageService.dedupeImages(this.records, ctx, (r: FoodRecord) => {
            FoodRepo.update(r);
        });
        for (const r of this.records) {
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
            const saved: string[] = ImageService.persistAll(list, ctx);
            r.imageUris = saved;
            r.imageUri = saved[0];
            try {
                FoodRepo.update(r);
            }
            catch (err) {
                hilog.warn(DOMAIN, 'CalorieLite', 'update record images failed');
            }
        }
    }
    /** 按餐次筛出记录 */
    private ofMeal(meal: MealType): FoodRecord[] {
        const out: FoodRecord[] = [];
        for (const r of this.records) {
            if (r.mealType === meal) {
                out.push(r);
            }
        }
        return out;
    }
    private mealKcal(meal: MealType): number {
        let sum: number = 0;
        for (const r of this.ofMeal(meal)) {
            sum += r.kcal;
        }
        return Math.round(sum);
    }
    /**
     * 汇总一餐的全部图片并去重。
     *
     * 同一餐的每条记录都存了同一组图（识别结果是共享的），
     * 所以这里必须去重，否则 Swiper 里会出现重复的同一张照片。
     */
    private mealImages(meal: MealType): string[] {
        const seen: string[] = [];
        for (const r of this.ofMeal(meal)) {
            for (const u of r.gallery()) {
                if (u.length > 0 && !seen.includes(u)) {
                    seen.push(u);
                }
            }
        }
        return seen;
    }
    /**
     * 页面推入/推出的过渡动画。
     *
     * 新页面从右侧滑入，旧页面稍向左让位并淡出；返回时整体反向，
     * 与系统返回手势的视觉方向一致。
     */
    pageTransition(): void {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            PageTransition.create();
        }, null);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            PageTransitionEnter.create({ type: RouteType.Push, duration: 300, curve: Curve.FastOutSlowIn });
            PageTransitionEnter.translate({ x: 80 });
            PageTransitionEnter.opacity(0);
        }, null);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            PageTransitionExit.create({ type: RouteType.Push, duration: 300, curve: Curve.FastOutSlowIn });
            PageTransitionExit.translate({ x: -40 });
            PageTransitionExit.opacity(0);
        }, null);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            PageTransitionEnter.create({ type: RouteType.Pop, duration: 300, curve: Curve.FastOutSlowIn });
            PageTransitionEnter.translate({ x: -40 });
            PageTransitionEnter.opacity(0);
        }, null);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            PageTransitionExit.create({ type: RouteType.Pop, duration: 300, curve: Curve.FastOutSlowIn });
            PageTransitionExit.translate({ x: 80 });
            PageTransitionExit.opacity(0);
        }, null);
        PageTransition.pop();
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.debugLine("entry/src/main/ets/pages/DayDetail.ets(181:5)", "entry");
            Column.width('100%');
            Column.height('100%');
            Column.backgroundColor(COLOR_BG);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // ------------------------------------------------ 顶栏
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/DayDetail.ets(183:7)", "entry");
            // ------------------------------------------------ 顶栏
            Row.width('100%');
            // ------------------------------------------------ 顶栏
            Row.padding({ left: PAGE_PAD, right: PAGE_PAD, top: 8, bottom: 8 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithChild({ type: ButtonType.Circle });
            Button.debugLine("entry/src/main/ets/pages/DayDetail.ets(184:9)", "entry");
            Button.width(36);
            Button.height(36);
            Button.backgroundColor(COLOR_CARD);
            Button.shadow(CARD_SHADOW);
            Button.onClick(() => {
                router.back();
            });
        }, Button);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('‹');
            Text.debugLine("entry/src/main/ets/pages/DayDetail.ets(185:11)", "entry");
            Text.fontSize(22);
            Text.fontColor(COLOR_TEXT);
        }, Text);
        Text.pop();
        Button.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(friendlyDate(this.dayKey));
            Text.debugLine("entry/src/main/ets/pages/DayDetail.ets(194:9)", "entry");
            Text.fontSize(17);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(COLOR_TEXT);
            Text.layoutWeight(1);
            Text.textAlign(TextAlign.Center);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/DayDetail.ets(201:9)", "entry");
            Row.width(36);
            Row.height(36);
        }, Row);
        Row.pop();
        // ------------------------------------------------ 顶栏
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Scroll.create();
            Scroll.debugLine("entry/src/main/ets/pages/DayDetail.ets(206:7)", "entry");
            Scroll.layoutWeight(1);
            Scroll.scrollBar(BarState.Off);
            Scroll.align(Alignment.Top);
        }, Scroll);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: GAP });
            Column.debugLine("entry/src/main/ets/pages/DayDetail.ets(207:9)", "entry");
            Column.width('100%');
            Column.padding({ left: PAGE_PAD, right: PAGE_PAD });
        }, Column);
        this.summaryCard.bind(this)();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.records.length === 0) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.emptyState.bind(this)();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        ForEach.create();
                        const forEachItemGenFunction = _item => {
                            const meal = _item;
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                If.create();
                                if (this.ofMeal(meal).length > 0) {
                                    this.ifElseBranchUpdateFunction(0, () => {
                                        this.mealSection.bind(this)(meal);
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
                });
            }
        }, If);
        If.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/DayDetail.ets(220:11)", "entry");
            Row.height(40);
        }, Row);
        Row.pop();
        Column.pop();
        Scroll.pop();
        Column.pop();
    }
    /** 顶部汇总：总摄入 + 缺口徽标 + 三大营养素 */
    summaryCard(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 14 });
            Column.debugLine("entry/src/main/ets/pages/DayDetail.ets(237:5)", "entry");
            Column.width('100%');
            Column.padding(16);
            Column.backgroundColor(COLOR_CARD);
            Column.borderRadius(RADIUS);
            Column.shadow(CARD_SHADOW);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/DayDetail.ets(238:7)", "entry");
            Row.width('100%');
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 2 });
            Column.debugLine("entry/src/main/ets/pages/DayDetail.ets(239:9)", "entry");
            Column.alignItems(HorizontalAlign.Start);
            Column.layoutWeight(1);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('总摄入');
            Text.debugLine("entry/src/main/ets/pages/DayDetail.ets(240:11)", "entry");
            Text.fontSize(12);
            Text.fontColor(COLOR_TEXT_SUB);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 4 });
            Row.debugLine("entry/src/main/ets/pages/DayDetail.ets(243:11)", "entry");
            Row.alignItems(VerticalAlign.Bottom);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(`${this.summary.intake}`);
            Text.debugLine("entry/src/main/ets/pages/DayDetail.ets(244:13)", "entry");
            Text.fontSize(30);
            Text.fontWeight(FontWeight.Bold);
            Text.fontColor(COLOR_TEXT);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('千卡');
            Text.debugLine("entry/src/main/ets/pages/DayDetail.ets(248:13)", "entry");
            Text.fontSize(12);
            Text.fontColor(COLOR_TEXT_SUB);
            Text.margin({ bottom: 4 });
        }, Text);
        Text.pop();
        Row.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.summary.deficit < 0
                ? `超出 ${-this.summary.deficit}`
                : `缺口 ${this.summary.deficit}`);
            Text.debugLine("entry/src/main/ets/pages/DayDetail.ets(258:9)", "entry");
            Text.fontSize(14);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(this.summary.deficit < 0 ? COLOR_WARN : COLOR_OK);
            Text.padding({ left: 12, right: 12, top: 6, bottom: 6 });
            Text.backgroundColor(this.summary.deficit < 0 ? '#1AE5533D' : '#1A2FA36B');
            Text.borderRadius(12);
        }, Text);
        Text.pop();
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(`预算 ${this.summary.budget} 千卡 · 共 ${this.summary.recordCount} 条记录`);
            Text.debugLine("entry/src/main/ets/pages/DayDetail.ets(270:7)", "entry");
            Text.fontSize(11);
            Text.fontColor(COLOR_TEXT_SUB);
            Text.width('100%');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Divider.create();
            Divider.debugLine("entry/src/main/ets/pages/DayDetail.ets(275:7)", "entry");
            Divider.color(COLOR_DIVIDER);
        }, Divider);
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new 
                    // 推荐的营养素克数按当日预算推算（碳水 50% / 蛋白 30% / 脂肪 20%）
                    MacroBar(this, {
                        protein: this.summary.protein,
                        fat: this.summary.fat,
                        carb: this.summary.carb,
                        carbTarget: macroTargetFor(this.summary.budget).carb,
                        proteinTarget: macroTargetFor(this.summary.budget).protein,
                        fatTarget: macroTargetFor(this.summary.budget).fat
                    }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/DayDetail.ets", line: 278, col: 7 });
                    ViewPU.create(componentCall);
                    let paramsLambda = () => {
                        return {
                            protein: this.summary.protein,
                            fat: this.summary.fat,
                            carb: this.summary.carb,
                            carbTarget: macroTargetFor(this.summary.budget).carb,
                            proteinTarget: macroTargetFor(this.summary.budget).protein,
                            fatTarget: macroTargetFor(this.summary.budget).fat
                        };
                    };
                    componentCall.paramsGenerator_ = paramsLambda;
                }
                else {
                    this.updateStateVarsOfChildByElmtId(elmtId, {
                        protein: this.summary.protein,
                        fat: this.summary.fat,
                        carb: this.summary.carb,
                        carbTarget: macroTargetFor(this.summary.budget).carb,
                        proteinTarget: macroTargetFor(this.summary.budget).protein,
                        fatTarget: macroTargetFor(this.summary.budget).fat
                    });
                }
            }, { name: "MacroBar" });
        }
        Column.pop();
    }
    /** 一餐：标题 + 图片预览框 + 菜品列表 */
    mealSection(meal: MealType, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 10 });
            Column.debugLine("entry/src/main/ets/pages/DayDetail.ets(297:5)", "entry");
            Column.width('100%');
            Column.alignItems(HorizontalAlign.Start);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/DayDetail.ets(298:7)", "entry");
            Row.width('100%');
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(mealTypeLabel(meal));
            Text.debugLine("entry/src/main/ets/pages/DayDetail.ets(299:9)", "entry");
            Text.fontSize(16);
            Text.fontWeight(FontWeight.Bold);
            Text.fontColor(COLOR_TEXT);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
            Blank.debugLine("entry/src/main/ets/pages/DayDetail.ets(303:9)", "entry");
        }, Blank);
        Blank.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(`${this.mealKcal(meal)} 千卡`);
            Text.debugLine("entry/src/main/ets/pages/DayDetail.ets(304:9)", "entry");
            Text.fontSize(13);
            Text.fontColor(COLOR_TEXT_SUB);
        }, Text);
        Text.pop();
        Row.pop();
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new 
                    // 整餐共用的大预览框（多图可左右滑动切换）
                    MealGallery(this, {
                        images: this.mealImages(meal),
                        frameHeight: FRAME_HEIGHT
                    }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/DayDetail.ets", line: 311, col: 7 });
                    ViewPU.create(componentCall);
                    let paramsLambda = () => {
                        return {
                            images: this.mealImages(meal),
                            frameHeight: FRAME_HEIGHT
                        };
                    };
                    componentCall.paramsGenerator_ = paramsLambda;
                }
                else {
                    this.updateStateVarsOfChildByElmtId(elmtId, {
                        images: this.mealImages(meal),
                        frameHeight: FRAME_HEIGHT
                    });
                }
            }, { name: "MealGallery" });
        }
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 菜品列表：图片已经在上面统一展示了，这里只列菜名与营养
            Column.create();
            Column.debugLine("entry/src/main/ets/pages/DayDetail.ets(317:7)", "entry");
            // 菜品列表：图片已经在上面统一展示了，这里只列菜名与营养
            Column.width('100%');
            // 菜品列表：图片已经在上面统一展示了，这里只列菜名与营养
            Column.padding({ left: 14, right: 14 });
            // 菜品列表：图片已经在上面统一展示了，这里只列菜名与营养
            Column.backgroundColor(COLOR_CARD);
            // 菜品列表：图片已经在上面统一展示了，这里只列菜名与营养
            Column.borderRadius(16);
            // 菜品列表：图片已经在上面统一展示了，这里只列菜名与营养
            Column.shadow(CARD_SHADOW);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            ForEach.create();
            const forEachItemGenFunction = (_item, idx: number) => {
                const r = _item;
                this.dishRow.bind(this)(r, idx > 0);
            };
            this.forEachUpdateFunction(elmtId, this.ofMeal(meal), forEachItemGenFunction, (r: FoodRecord) => r.id, true, false);
        }, ForEach);
        ForEach.pop();
        // 菜品列表：图片已经在上面统一展示了，这里只列菜名与营养
        Column.pop();
        Column.pop();
    }
    /** 一道菜：名称 + 克重/营养 + 热量，行间用细分隔线 */
    dishRow(r: FoodRecord, withDivider: boolean, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.debugLine("entry/src/main/ets/pages/DayDetail.ets(335:5)", "entry");
            Column.width('100%');
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (withDivider) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Divider.create();
                        Divider.debugLine("entry/src/main/ets/pages/DayDetail.ets(337:9)", "entry");
                        Divider.color(COLOR_DIVIDER);
                    }, Divider);
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 10 });
            Row.debugLine("entry/src/main/ets/pages/DayDetail.ets(339:7)", "entry");
            Row.width('100%');
            Row.padding({ top: 12, bottom: 12 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 3 });
            Column.debugLine("entry/src/main/ets/pages/DayDetail.ets(340:9)", "entry");
            Column.alignItems(HorizontalAlign.Start);
            Column.layoutWeight(1);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(r.name);
            Text.debugLine("entry/src/main/ets/pages/DayDetail.ets(341:11)", "entry");
            Text.fontSize(15);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(COLOR_TEXT);
            Text.maxLines(1);
            Text.textOverflow({ overflow: TextOverflow.Ellipsis });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.dishSubtitle(r));
            Text.debugLine("entry/src/main/ets/pages/DayDetail.ets(348:11)", "entry");
            Text.fontSize(11);
            Text.fontColor(COLOR_TEXT_SUB);
            Text.maxLines(1);
            Text.textOverflow({ overflow: TextOverflow.Ellipsis });
        }, Text);
        Text.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 2 });
            Row.debugLine("entry/src/main/ets/pages/DayDetail.ets(357:9)", "entry");
            Row.alignItems(VerticalAlign.Bottom);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(`${r.kcal}`);
            Text.debugLine("entry/src/main/ets/pages/DayDetail.ets(358:11)", "entry");
            Text.fontSize(17);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(COLOR_PRIMARY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('千卡');
            Text.debugLine("entry/src/main/ets/pages/DayDetail.ets(362:11)", "entry");
            Text.fontSize(10);
            Text.fontColor(COLOR_TEXT_SUB);
            Text.margin({ bottom: 2 });
        }, Text);
        Text.pop();
        Row.pop();
        Row.pop();
        Column.pop();
    }
    /** 菜品副标题：克重 + 营养（没有营养数据时退回时间） */
    private dishSubtitle(r: FoodRecord): string {
        const base: string = `${r.grams} g`;
        if (r.protein <= 0 && r.fat <= 0 && r.carb <= 0) {
            return `${base} · ${timeLabel(r.timestamp)}`;
        }
        return `${base} · 蛋白 ${r.protein} · 脂肪 ${r.fat} · 碳水 ${r.carb}`;
    }
    /** 空状态 */
    emptyState(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 12 });
            Column.debugLine("entry/src/main/ets/pages/DayDetail.ets(387:5)", "entry");
            Column.width('100%');
            Column.padding({ top: 44, bottom: 44, left: 24, right: 24 });
            Column.backgroundColor(COLOR_CARD);
            Column.borderRadius(RADIUS);
            Column.shadow(CARD_SHADOW);
            Column.justifyContent(FlexAlign.Center);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('🍚');
            Text.debugLine("entry/src/main/ets/pages/DayDetail.ets(388:7)", "entry");
            Text.fontSize(52);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('这天还没有饮食记录哦');
            Text.debugLine("entry/src/main/ets/pages/DayDetail.ets(390:7)", "entry");
            Text.fontSize(15);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(COLOR_TEXT);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('回到首页拍照识别，或在「记录」页用「补记」手动添加');
            Text.debugLine("entry/src/main/ets/pages/DayDetail.ets(394:7)", "entry");
            Text.fontSize(12);
            Text.fontColor(COLOR_TEXT_SUB);
            Text.textAlign(TextAlign.Center);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithChild({ type: ButtonType.Capsule });
            Button.debugLine("entry/src/main/ets/pages/DayDetail.ets(398:7)", "entry");
            Button.height(40);
            Button.backgroundColor(COLOR_PRIMARY);
            Button.margin({ top: 4 });
            Button.onClick(() => {
                router.pushUrl({ url: 'pages/ManualAdd' });
            });
        }, Button);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('去补记一笔');
            Text.debugLine("entry/src/main/ets/pages/DayDetail.ets(399:9)", "entry");
            Text.fontSize(14);
            Text.fontColor(Color.White);
        }, Text);
        Text.pop();
        Button.pop();
        Column.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
    public __resetStateVarsOnReuse__Internal(params: Object): void {
    }
    static getEntryName(): string {
        return "DayDetail";
    }
}
registerNamedRoute(() => new DayDetail(undefined, {}), "", { bundleName: "Calories.Lite.Test", moduleName: "entry", pagePath: "pages/DayDetail", pageFullPath: "entry/src/main/ets/pages/DayDetail", integratedHsp: "false", moduleType: "followWithHap" });
