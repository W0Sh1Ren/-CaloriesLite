if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface ResultConfirm_Params {
    drafts?: EditableDraft[];
    imageUris?: string[];
    userNotes?: string;
    overallNote?: string;
    model?: string;
    meal?: MealType;
}
import router from "@ohos:router";
import promptAction from "@ohos:promptAction";
import { FoodRecord, FoodSource, MealType } from "@normalized:N&&&entry/src/main/ets/model/Types&";
import type { FoodDraft } from "@normalized:N&&&entry/src/main/ets/model/Types&";
import { MEAL_ORDER, mealTypeLabel } from "@normalized:N&&&entry/src/main/ets/model/Enums&";
import { todayKey } from "@normalized:N&&&entry/src/main/ets/common/DateUtil&";
import { makeId } from "@normalized:N&&&entry/src/main/ets/common/JsonUtil&";
import { FoodRepo } from "@normalized:N&&&entry/src/main/ets/service/FoodRepo&";
import { DailyService } from "@normalized:N&&&entry/src/main/ets/service/DailyService&";
import { AppState } from "@normalized:N&&&entry/src/main/ets/common/AppState&";
import type { PendingResult } from "@normalized:N&&&entry/src/main/ets/common/AppState&";
import { CARD_SHADOW, COLOR_BG, COLOR_CARD, COLOR_DIVIDER, COLOR_OK, COLOR_PRIMARY, COLOR_TEXT, COLOR_TEXT_SUB, COLOR_WARN, GAP, PAGE_PAD, RADIUS } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
const DOMAIN = 0x0000;
/** 可编辑的草稿行 */
@Observed
class EditableDraft {
    name: string = '';
    gramsText: string = '';
    kcal: number = 0;
    protein: number = 0;
    fat: number = 0;
    carb: number = 0;
    confidence: string = '';
    source: FoodSource = FoodSource.AI;
    note: string = '';
    /** 每 100 克的营养密度，用于改克重时按比例重算 */
    kcalPer100g: number = 0;
    proteinPer100g: number = 0;
    fatPer100g: number = 0;
    carbPer100g: number = 0;
    constructor(draft: FoodDraft) {
        this.name = draft.name;
        this.gramsText = `${draft.grams}`;
        this.kcal = draft.kcal;
        this.protein = draft.protein;
        this.fat = draft.fat;
        this.carb = draft.carb;
        this.confidence = draft.confidence;
        this.source = draft.source;
        this.note = draft.note;
        if (draft.grams > 0) {
            const ratio: number = 100 / draft.grams;
            this.kcalPer100g = draft.kcal * ratio;
            this.proteinPer100g = draft.protein * ratio;
            this.fatPer100g = draft.fat * ratio;
            this.carbPer100g = draft.carb * ratio;
        }
    }
    grams(): number {
        const v: number = Number.parseFloat(this.gramsText);
        return Number.isNaN(v) || v <= 0 ? 0 : Math.round(v);
    }
    /** 改完克重后按比例重算全部营养值；没有基准值时保持原样 */
    recompute(): void {
        if (this.kcalPer100g <= 0) {
            return;
        }
        const ratio: number = this.grams() / 100;
        this.kcal = Math.round(this.kcalPer100g * ratio);
        this.protein = round1(this.proteinPer100g * ratio);
        this.fat = round1(this.fatPer100g * ratio);
        this.carb = round1(this.carbPer100g * ratio);
    }
}
/** 保留一位小数 */
function round1(v: number): number {
    return Math.round(v * 10) / 10;
}
class ResultConfirm extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__drafts = new ObservedPropertyObjectPU([], this, "drafts");
        this.__imageUris = new ObservedPropertyObjectPU([], this, "imageUris");
        this.__userNotes = new ObservedPropertySimplePU('', this, "userNotes");
        this.__overallNote = new ObservedPropertySimplePU('', this, "overallNote");
        this.__model = new ObservedPropertySimplePU('', this, "model");
        this.__meal = new ObservedPropertySimplePU(MealType.LUNCH, this, "meal");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: ResultConfirm_Params) {
        if (params.drafts !== undefined) {
            this.drafts = params.drafts;
        }
        if (params.imageUris !== undefined) {
            this.imageUris = params.imageUris;
        }
        if (params.userNotes !== undefined) {
            this.userNotes = params.userNotes;
        }
        if (params.overallNote !== undefined) {
            this.overallNote = params.overallNote;
        }
        if (params.model !== undefined) {
            this.model = params.model;
        }
        if (params.meal !== undefined) {
            this.meal = params.meal;
        }
    }
    updateStateVars(params: ResultConfirm_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__drafts.purgeDependencyOnElmtId(rmElmtId);
        this.__imageUris.purgeDependencyOnElmtId(rmElmtId);
        this.__userNotes.purgeDependencyOnElmtId(rmElmtId);
        this.__overallNote.purgeDependencyOnElmtId(rmElmtId);
        this.__model.purgeDependencyOnElmtId(rmElmtId);
        this.__meal.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__drafts.aboutToBeDeleted();
        this.__imageUris.aboutToBeDeleted();
        this.__userNotes.aboutToBeDeleted();
        this.__overallNote.aboutToBeDeleted();
        this.__model.aboutToBeDeleted();
        this.__meal.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __drafts: ObservedPropertyObjectPU<EditableDraft[]>;
    get drafts() {
        return this.__drafts.get();
    }
    set drafts(newValue: EditableDraft[]) {
        this.__drafts.set(newValue);
    }
    private __imageUris: ObservedPropertyObjectPU<string[]>;
    get imageUris() {
        return this.__imageUris.get();
    }
    set imageUris(newValue: string[]) {
        this.__imageUris.set(newValue);
    }
    /** 用户手写的补充说明（已随请求发给模型），结果页回显供核对 */
    private __userNotes: ObservedPropertySimplePU<string>;
    get userNotes() {
        return this.__userNotes.get();
    }
    set userNotes(newValue: string) {
        this.__userNotes.set(newValue);
    }
    private __overallNote: ObservedPropertySimplePU<string>;
    get overallNote() {
        return this.__overallNote.get();
    }
    set overallNote(newValue: string) {
        this.__overallNote.set(newValue);
    }
    private __model: ObservedPropertySimplePU<string>;
    get model() {
        return this.__model.get();
    }
    set model(newValue: string) {
        this.__model.set(newValue);
    }
    private __meal: ObservedPropertySimplePU<MealType>;
    get meal() {
        return this.__meal.get();
    }
    set meal(newValue: MealType) {
        this.__meal.set(newValue);
    }
    aboutToAppear(): void {
        const pending: PendingResult | null = AppState.pending;
        if (pending === null) {
            // 没有待确认数据（例如异常返回），直接退回上一页
            promptAction.showToast({ message: '没有待确认的识别结果' });
            router.back();
            return;
        }
        const rows: EditableDraft[] = [];
        for (const d of pending.drafts) {
            rows.push(new EditableDraft(d));
        }
        this.drafts = rows;
        this.imageUris = pending.imageUris;
        this.userNotes = pending.userNotes;
        this.overallNote = pending.overallNote;
        this.model = pending.model;
        this.meal = AppState.targetMeal;
    }
    private totalKcal(): number {
        let sum: number = 0;
        for (const d of this.drafts) {
            sum += d.kcal;
        }
        return Math.round(sum);
    }
    /** 置信度对应的提示色与文案 */
    private confidenceLabel(level: string): string {
        if (level === 'high') {
            return '较可信';
        }
        if (level === 'medium') {
            return '一般';
        }
        return '不确定';
    }
    private confidenceColor(level: string): string {
        if (level === 'high') {
            return COLOR_OK;
        }
        if (level === 'medium') {
            return COLOR_PRIMARY;
        }
        return COLOR_WARN;
    }
    /** 删除某一行 */
    private removeRow(index: number): void {
        const next: EditableDraft[] = [];
        for (let i = 0; i < this.drafts.length; i++) {
            if (i !== index) {
                next.push(this.drafts[i]);
            }
        }
        this.drafts = next;
    }
    /** 全部写入记录 */
    private confirm(): void {
        if (this.drafts.length === 0) {
            promptAction.showToast({ message: '没有可保存的条目' });
            return;
        }
        const day: string = todayKey();
        const now: number = Date.now();
        // 整组图片写进每条记录：详情页要支持一餐多图滑动浏览，
        // 只留第一张的话其余照片就白拍了。
        const images: string[] = this.imageUris.slice();
        const records: FoodRecord[] = [];
        for (const d of this.drafts) {
            const grams: number = d.grams();
            if (grams <= 0 || d.kcal <= 0) {
                promptAction.showToast({ message: `「${d.name}」缺少克重或热量，请补全后再保存` });
                return;
            }
            const rec: FoodRecord = new FoodRecord(makeId(), day, now, this.meal, d.name, grams, d.kcal, d.protein, d.fat, d.carb, d.source, images.length > 0 ? images[0] : '', d.note);
            rec.imageUris = images;
            records.push(rec);
        }
        FoodRepo.addMany(records);
        AppState.clearPending();
        AppState.needRefreshHome = true;
        // 显式通知全局：首页/记录页绑定的汇总值当帧就会更新，
        // 不用等页面生命周期回调（这正是「必须退出重进才显示」的根因）
        AppState.mirrorToday(DailyService.summaryOf(day));
        AppState.notifyDataChanged();
        promptAction.showToast({ message: `已记录 ${records.length} 项，共 ${this.totalKcal()} 千卡` });
        router.back();
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(191:5)", "entry");
            Column.width('100%');
            Column.height('100%');
            Column.backgroundColor(COLOR_BG);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 顶部栏
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(193:7)", "entry");
            // 顶部栏
            Row.width('100%');
            // 顶部栏
            Row.padding({ left: PAGE_PAD, right: PAGE_PAD, top: 8, bottom: 8 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithChild({ type: ButtonType.Circle });
            Button.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(194:9)", "entry");
            Button.width(36);
            Button.height(36);
            Button.backgroundColor(COLOR_CARD);
            Button.onClick(() => {
                AppState.clearPending();
                router.back();
            });
        }, Button);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('‹');
            Text.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(195:11)", "entry");
            Text.fontSize(22);
            Text.fontColor(COLOR_TEXT);
        }, Text);
        Text.pop();
        Button.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('确认识别结果');
            Text.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(203:9)", "entry");
            Text.fontSize(17);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(COLOR_TEXT);
            Text.layoutWeight(1);
            Text.textAlign(TextAlign.Center);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(210:9)", "entry");
            Row.width(36);
            Row.height(36);
        }, Row);
        Row.pop();
        // 顶部栏
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Scroll.create();
            Scroll.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(215:7)", "entry");
            Scroll.layoutWeight(1);
            Scroll.scrollBar(BarState.Off);
            Scroll.align(Alignment.Top);
        }, Scroll);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: GAP });
            Column.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(216:9)", "entry");
            Column.width('100%');
            Column.padding({ left: PAGE_PAD, right: PAGE_PAD, top: 8, bottom: 16 });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            // 送出去识别的原图（可能多张）+ 模型信息
            if (this.imageUris.length > 0) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Scroll.create();
                        Scroll.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(219:13)", "entry");
                        Scroll.scrollable(this.imageUris.length > 1 ? ScrollDirection.Horizontal : ScrollDirection.Vertical);
                        Scroll.scrollBar(BarState.Off);
                        Scroll.width('100%');
                    }, Scroll);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Row.create({ space: 10 });
                        Row.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(220:15)", "entry");
                    }, Row);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        ForEach.create();
                        const forEachItemGenFunction = (_item, index: number) => {
                            const uri = _item;
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Image.create(uri);
                                Image.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(222:19)", "entry");
                                Image.width(this.imageUris.length > 1 ? 120 : '100%');
                                Image.height(this.imageUris.length > 1 ? 120 : 180);
                                Image.objectFit(ImageFit.Cover);
                                Image.borderRadius(RADIUS);
                            }, Image);
                        };
                        this.forEachUpdateFunction(elmtId, this.imageUris, forEachItemGenFunction, (uri: string, index: number) => `${index}-${uri}`, true, true);
                    }, ForEach);
                    ForEach.pop();
                    Row.pop();
                    Scroll.pop();
                });
            }
            // 回显用户自己写的补充说明，方便核对模型有没有照做
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            // 回显用户自己写的补充说明，方便核对模型有没有照做
            if (this.userNotes.length > 0) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Row.create({ space: 8 });
                        Row.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(237:13)", "entry");
                        Row.width('100%');
                        Row.padding(12);
                        Row.backgroundColor(COLOR_CARD);
                        Row.borderRadius(RADIUS);
                        Row.shadow(CARD_SHADOW);
                    }, Row);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('你的说明');
                        Text.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(238:15)", "entry");
                        Text.fontSize(11);
                        Text.fontColor(COLOR_TEXT_SUB);
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(this.userNotes);
                        Text.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(241:15)", "entry");
                        Text.fontSize(12);
                        Text.fontColor(COLOR_TEXT);
                        Text.layoutWeight(1);
                        Text.maxLines(2);
                        Text.textOverflow({ overflow: TextOverflow.Ellipsis });
                    }, Text);
                    Text.pop();
                    Row.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(255:11)", "entry");
            Row.width('100%');
            Row.padding({ left: 4 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(`识别模型：${this.model}`);
            Text.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(256:13)", "entry");
            Text.fontSize(11);
            Text.fontColor(COLOR_TEXT_SUB);
        }, Text);
        Text.pop();
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.overallNote.length > 0) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Row.create();
                        Row.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(264:13)", "entry");
                        Row.width('100%');
                        Row.padding(12);
                        Row.backgroundColor(COLOR_CARD);
                        Row.borderRadius(10);
                    }, Row);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(this.overallNote);
                        Text.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(265:15)", "entry");
                        Text.fontSize(12);
                        Text.fontColor(COLOR_TEXT_SUB);
                        Text.layoutWeight(1);
                    }, Text);
                    Text.pop();
                    Row.pop();
                });
            }
            // 餐次选择
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 餐次选择
            Column.create({ space: 8 });
            Column.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(277:11)", "entry");
            // 餐次选择
            Column.width('100%');
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('记到哪一餐');
            Text.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(278:13)", "entry");
            Text.fontSize(13);
            Text.fontColor(COLOR_TEXT_SUB);
            Text.width('100%');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 8 });
            Row.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(283:13)", "entry");
            Row.width('100%');
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            ForEach.create();
            const forEachItemGenFunction = _item => {
                const m = _item;
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Text.create(mealTypeLabel(m));
                    Text.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(285:17)", "entry");
                    Text.fontSize(14);
                    Text.fontColor(this.meal === m ? Color.White : COLOR_TEXT);
                    Text.textAlign(TextAlign.Center);
                    Text.layoutWeight(1);
                    Text.height(38);
                    Text.backgroundColor(this.meal === m ? COLOR_PRIMARY : COLOR_CARD);
                    Text.borderRadius(10);
                    Text.onClick(() => {
                        this.meal = m;
                    });
                }, Text);
                Text.pop();
            };
            this.forEachUpdateFunction(elmtId, MEAL_ORDER, forEachItemGenFunction, (m: MealType) => m, false, false);
        }, ForEach);
        ForEach.pop();
        Row.pop();
        // 餐次选择
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 逐条确认
            ForEach.create();
            const forEachItemGenFunction = (_item, index: number) => {
                const item = _item;
                this.draftCard.bind(this)(item, index);
            };
            this.forEachUpdateFunction(elmtId, this.drafts, forEachItemGenFunction, (item: EditableDraft, index: number) => `${index}-${item.name}`, true, true);
        }, ForEach);
        // 逐条确认
        ForEach.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(307:11)", "entry");
            Row.height(80);
        }, Row);
        Row.pop();
        Column.pop();
        Scroll.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 底部合计与保存
            Row.create({ space: 12 });
            Row.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(317:7)", "entry");
            // 底部合计与保存
            Row.width('100%');
            // 底部合计与保存
            Row.padding({ left: PAGE_PAD, right: PAGE_PAD, top: 10, bottom: 10 });
            // 底部合计与保存
            Row.backgroundColor(COLOR_CARD);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 2 });
            Column.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(318:9)", "entry");
            Column.alignItems(HorizontalAlign.Start);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('合计');
            Text.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(319:11)", "entry");
            Text.fontSize(11);
            Text.fontColor(COLOR_TEXT_SUB);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(`${this.totalKcal()} 千卡`);
            Text.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(322:11)", "entry");
            Text.fontSize(18);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(COLOR_TEXT);
        }, Text);
        Text.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
            Blank.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(329:9)", "entry");
        }, Blank);
        Blank.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithChild({ type: ButtonType.Capsule });
            Button.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(331:9)", "entry");
            Button.height(46);
            Button.width(140);
            Button.backgroundColor(COLOR_PRIMARY);
            Button.onClick(() => {
                this.confirm();
            });
        }, Button);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('确认记录');
            Text.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(332:11)", "entry");
            Text.fontSize(16);
            Text.fontColor(Color.White);
        }, Text);
        Text.pop();
        Button.pop();
        // 底部合计与保存
        Row.pop();
        Column.pop();
    }
    draftCard(item: EditableDraft, index: number, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 10 });
            Column.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(352:5)", "entry");
            Column.width('100%');
            Column.padding(14);
            Column.backgroundColor(COLOR_CARD);
            Column.borderRadius(RADIUS);
            Column.shadow(CARD_SHADOW);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 8 });
            Row.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(353:7)", "entry");
            Row.width('100%');
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            TextInput.create({ text: item.name });
            TextInput.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(354:9)", "entry");
            TextInput.fontSize(15);
            TextInput.height(40);
            TextInput.layoutWeight(1);
            TextInput.backgroundColor(COLOR_BG);
            TextInput.borderRadius(8);
            TextInput.onChange((v: string) => {
                item.name = v;
            });
        }, TextInput);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithChild({ type: ButtonType.Circle });
            Button.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(364:9)", "entry");
            Button.width(30);
            Button.height(30);
            Button.backgroundColor(COLOR_DIVIDER);
            Button.onClick(() => {
                this.removeRow(index);
            });
        }, Button);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('✕');
            Text.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(365:11)", "entry");
            Text.fontSize(13);
            Text.fontColor(COLOR_TEXT_SUB);
        }, Text);
        Text.pop();
        Button.pop();
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 8 });
            Row.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(374:7)", "entry");
            Row.width('100%');
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            TextInput.create({ text: item.gramsText, placeholder: '克重' });
            TextInput.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(375:9)", "entry");
            TextInput.type(InputType.NUMBER_DECIMAL);
            TextInput.fontSize(14);
            TextInput.height(40);
            TextInput.layoutWeight(1);
            TextInput.backgroundColor(COLOR_BG);
            TextInput.borderRadius(8);
            TextInput.onChange((v: string) => {
                item.gramsText = v;
                item.recompute();
                // 触发列表重建，让热量数字刷新
                this.drafts = this.drafts.slice();
            });
        }, TextInput);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('克');
            Text.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(389:9)", "entry");
            Text.fontSize(13);
            Text.fontColor(COLOR_TEXT_SUB);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(`${item.kcal} 千卡`);
            Text.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(393:9)", "entry");
            Text.fontSize(15);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(COLOR_TEXT);
            Text.width(78);
            Text.textAlign(TextAlign.End);
        }, Text);
        Text.pop();
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 三大营养素：让用户当场看到 AI 估了什么，而不是只看到一个热量
            Row.create({ space: 12 });
            Row.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(403:7)", "entry");
            // 三大营养素：让用户当场看到 AI 估了什么，而不是只看到一个热量
            Row.width('100%');
        }, Row);
        this.macroTag.bind(this)('蛋白', item.protein);
        this.macroTag.bind(this)('脂肪', item.fat);
        this.macroTag.bind(this)('碳水', item.carb);
        // 三大营养素：让用户当场看到 AI 估了什么，而不是只看到一个热量
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 8 });
            Row.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(410:7)", "entry");
            Row.width('100%');
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.confidenceLabel(item.confidence));
            Text.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(411:9)", "entry");
            Text.fontSize(11);
            Text.fontColor(this.confidenceColor(item.confidence));
            Text.padding({ left: 6, right: 6, top: 2, bottom: 2 });
            Text.backgroundColor(COLOR_BG);
            Text.borderRadius(4);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(item.source === FoodSource.DATABASE ? '查表数值' : 'AI 估算');
            Text.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(418:9)", "entry");
            Text.fontSize(11);
            Text.fontColor(COLOR_TEXT_SUB);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(item.note);
            Text.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(422:9)", "entry");
            Text.fontSize(11);
            Text.fontColor(COLOR_TEXT_SUB);
            Text.layoutWeight(1);
            Text.maxLines(2);
            Text.textOverflow({ overflow: TextOverflow.Ellipsis });
        }, Text);
        Text.pop();
        Row.pop();
        Column.pop();
    }
    /** 一个营养素小标签 */
    macroTag(label: string, grams: number, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 3 });
            Row.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(441:5)", "entry");
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(label);
            Text.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(442:7)", "entry");
            Text.fontSize(11);
            Text.fontColor(COLOR_TEXT_SUB);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(`${grams} g`);
            Text.debugLine("entry/src/main/ets/pages/ResultConfirm.ets(445:7)", "entry");
            Text.fontSize(12);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(COLOR_TEXT);
        }, Text);
        Text.pop();
        Row.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
    public __resetStateVarsOnReuse__Internal(params: Object): void {
    }
    static getEntryName(): string {
        return "ResultConfirm";
    }
}
registerNamedRoute(() => new ResultConfirm(undefined, {}), "", { bundleName: "Calories.Lite.Test", moduleName: "entry", pagePath: "pages/ResultConfirm", pageFullPath: "entry/src/main/ets/pages/ResultConfirm", integratedHsp: "false", moduleType: "followWithHap" });
