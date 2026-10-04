if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface ManualAdd_Params {
    keyword?: string;
    category?: string;
    results?: FoodItem[];
    selected?: FoodItem | null;
    gramsText?: string;
    meal?: MealType;
}
import router from "@ohos:router";
import promptAction from "@ohos:promptAction";
import { FoodRecord, FoodSource, MealType } from "@normalized:N&&&entry/src/main/ets/model/Types&";
import type { FoodDraft, FoodItem } from "@normalized:N&&&entry/src/main/ets/model/Types&";
import { MEAL_ORDER, mealTypeLabel } from "@normalized:N&&&entry/src/main/ets/model/Enums&";
import { FOOD_CATEGORIES } from "@normalized:N&&&entry/src/main/ets/model/FoodDatabase&";
import { searchFoods, draftFromItem } from "@normalized:N&&&entry/src/main/ets/service/FoodMatcher&";
import { todayKey } from "@normalized:N&&&entry/src/main/ets/common/DateUtil&";
import { makeId } from "@normalized:N&&&entry/src/main/ets/common/JsonUtil&";
import { FoodRepo } from "@normalized:N&&&entry/src/main/ets/service/FoodRepo&";
import { AppState } from "@normalized:N&&&entry/src/main/ets/common/AppState&";
import { DailyService } from "@normalized:N&&&entry/src/main/ets/service/DailyService&";
import { COLOR_BG, COLOR_CARD, COLOR_DIVIDER, COLOR_PRIMARY, COLOR_TEXT, COLOR_TEXT_SUB, PAGE_PAD, RADIUS } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
class ManualAdd extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__keyword = new ObservedPropertySimplePU('', this, "keyword");
        this.__category = new ObservedPropertySimplePU('', this, "category");
        this.__results = new ObservedPropertyObjectPU([], this, "results");
        this.__selected = new ObservedPropertyObjectPU(null, this, "selected");
        this.__gramsText = new ObservedPropertySimplePU('', this, "gramsText");
        this.__meal = new ObservedPropertySimplePU(MealType.LUNCH, this, "meal");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: ManualAdd_Params) {
        if (params.keyword !== undefined) {
            this.keyword = params.keyword;
        }
        if (params.category !== undefined) {
            this.category = params.category;
        }
        if (params.results !== undefined) {
            this.results = params.results;
        }
        if (params.selected !== undefined) {
            this.selected = params.selected;
        }
        if (params.gramsText !== undefined) {
            this.gramsText = params.gramsText;
        }
        if (params.meal !== undefined) {
            this.meal = params.meal;
        }
    }
    updateStateVars(params: ManualAdd_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__keyword.purgeDependencyOnElmtId(rmElmtId);
        this.__category.purgeDependencyOnElmtId(rmElmtId);
        this.__results.purgeDependencyOnElmtId(rmElmtId);
        this.__selected.purgeDependencyOnElmtId(rmElmtId);
        this.__gramsText.purgeDependencyOnElmtId(rmElmtId);
        this.__meal.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__keyword.aboutToBeDeleted();
        this.__category.aboutToBeDeleted();
        this.__results.aboutToBeDeleted();
        this.__selected.aboutToBeDeleted();
        this.__gramsText.aboutToBeDeleted();
        this.__meal.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __keyword: ObservedPropertySimplePU<string>;
    get keyword() {
        return this.__keyword.get();
    }
    set keyword(newValue: string) {
        this.__keyword.set(newValue);
    }
    private __category: ObservedPropertySimplePU<string>;
    get category() {
        return this.__category.get();
    }
    set category(newValue: string) {
        this.__category.set(newValue);
    }
    private __results: ObservedPropertyObjectPU<FoodItem[]>;
    get results() {
        return this.__results.get();
    }
    set results(newValue: FoodItem[]) {
        this.__results.set(newValue);
    }
    private __selected: ObservedPropertyObjectPU<FoodItem | null>;
    get selected() {
        return this.__selected.get();
    }
    set selected(newValue: FoodItem | null) {
        this.__selected.set(newValue);
    }
    private __gramsText: ObservedPropertySimplePU<string>;
    get gramsText() {
        return this.__gramsText.get();
    }
    set gramsText(newValue: string) {
        this.__gramsText.set(newValue);
    }
    private __meal: ObservedPropertySimplePU<MealType>;
    get meal() {
        return this.__meal.get();
    }
    set meal(newValue: MealType) {
        this.__meal.set(newValue);
    }
    aboutToAppear(): void {
        this.results = searchFoods('', 60);
        this.meal = AppState.targetMeal;
    }
    private doSearch(): void {
        this.results = searchFoods(this.keyword, 60);
    }
    /** 选分类：再点一次取消筛选 */
    private toggleCategory(c: string): void {
        this.category = this.category === c ? '' : c;
        if (this.category.length === 0) {
            this.doSearch();
        }
        else {
            this.results = searchFoods(this.keyword, 200).filter((f: FoodItem) => f.category === this.category);
        }
    }
    private pick(item: FoodItem): void {
        this.selected = item;
        this.gramsText = `${item.defaultGrams}`;
    }
    /** 当前选中项的实时热量预览 */
    private preview(): FoodDraft | null {
        const item: FoodItem | null = this.selected;
        if (item === null) {
            return null;
        }
        const g: number = Number.parseFloat(this.gramsText);
        const grams: number = Number.isNaN(g) || g <= 0 ? item.defaultGrams : Math.round(g);
        return draftFromItem(item, grams);
    }
    private save(): void {
        const draft: FoodDraft | null = this.preview();
        if (draft === null) {
            promptAction.showToast({ message: '先选一个食物' });
            return;
        }
        FoodRepo.add(new FoodRecord(makeId(), todayKey(), Date.now(), this.meal, draft.name, draft.grams, draft.kcal, draft.protein, draft.fat, draft.carb, FoodSource.DATABASE, '', '手动从食物表添加'));
        AppState.needRefreshHome = true;
        // 显式推送到全局，首页与记录页当帧刷新
        AppState.mirrorToday(DailyService.summaryOf(todayKey()));
        AppState.notifyDataChanged();
        promptAction.showToast({ message: `已记录 ${draft.name} ${draft.kcal} 千卡` });
        router.back();
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.debugLine("entry/src/main/ets/pages/ManualAdd.ets(84:5)", "entry");
            Column.width('100%');
            Column.height('100%');
            Column.backgroundColor(COLOR_BG);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 顶部栏
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/ManualAdd.ets(86:7)", "entry");
            // 顶部栏
            Row.width('100%');
            // 顶部栏
            Row.padding({ left: PAGE_PAD, right: PAGE_PAD, top: 8, bottom: 8 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithChild({ type: ButtonType.Circle });
            Button.debugLine("entry/src/main/ets/pages/ManualAdd.ets(87:9)", "entry");
            Button.width(36);
            Button.height(36);
            Button.backgroundColor(COLOR_CARD);
            Button.onClick(() => {
                router.back();
            });
        }, Button);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('‹');
            Text.debugLine("entry/src/main/ets/pages/ManualAdd.ets(88:11)", "entry");
            Text.fontSize(22);
            Text.fontColor(COLOR_TEXT);
        }, Text);
        Text.pop();
        Button.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('手动添加');
            Text.debugLine("entry/src/main/ets/pages/ManualAdd.ets(95:9)", "entry");
            Text.fontSize(17);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(COLOR_TEXT);
            Text.layoutWeight(1);
            Text.textAlign(TextAlign.Center);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/ManualAdd.ets(102:9)", "entry");
            Row.width(36);
            Row.height(36);
        }, Row);
        Row.pop();
        // 顶部栏
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 搜索
            Row.create({ space: 10 });
            Row.debugLine("entry/src/main/ets/pages/ManualAdd.ets(108:7)", "entry");
            // 搜索
            Row.width('100%');
            // 搜索
            Row.padding({ left: PAGE_PAD, right: PAGE_PAD, bottom: 8 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            TextInput.create({ text: this.keyword, placeholder: '搜索食物，如「米饭」「鸡胸肉」' });
            TextInput.debugLine("entry/src/main/ets/pages/ManualAdd.ets(109:9)", "entry");
            TextInput.fontSize(14);
            TextInput.height(42);
            TextInput.layoutWeight(1);
            TextInput.backgroundColor(COLOR_CARD);
            TextInput.borderRadius(10);
            TextInput.onChange((v: string) => {
                this.keyword = v;
                this.doSearch();
            });
        }, TextInput);
        // 搜索
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 分类筛选
            Scroll.create();
            Scroll.debugLine("entry/src/main/ets/pages/ManualAdd.ets(124:7)", "entry");
            // 分类筛选
            Scroll.scrollable(ScrollDirection.Horizontal);
            // 分类筛选
            Scroll.scrollBar(BarState.Off);
            // 分类筛选
            Scroll.width('100%');
            // 分类筛选
            Scroll.height(40);
        }, Scroll);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 8 });
            Row.debugLine("entry/src/main/ets/pages/ManualAdd.ets(125:9)", "entry");
            Row.padding({ left: PAGE_PAD, right: PAGE_PAD });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            ForEach.create();
            const forEachItemGenFunction = _item => {
                const c = _item;
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Text.create(c);
                    Text.debugLine("entry/src/main/ets/pages/ManualAdd.ets(127:13)", "entry");
                    Text.fontSize(13);
                    Text.fontColor(this.category === c ? Color.White : COLOR_TEXT);
                    Text.padding({ left: 14, right: 14, top: 6, bottom: 6 });
                    Text.backgroundColor(this.category === c ? COLOR_PRIMARY : COLOR_CARD);
                    Text.borderRadius(14);
                    Text.onClick(() => {
                        this.toggleCategory(c);
                    });
                }, Text);
                Text.pop();
            };
            this.forEachUpdateFunction(elmtId, FOOD_CATEGORIES, forEachItemGenFunction, (c: string) => c, false, false);
        }, ForEach);
        ForEach.pop();
        Row.pop();
        // 分类筛选
        Scroll.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 结果列表
            List.create({ space: 6 });
            List.debugLine("entry/src/main/ets/pages/ManualAdd.ets(146:7)", "entry");
            // 结果列表
            List.layoutWeight(1);
            // 结果列表
            List.width('100%');
            // 结果列表
            List.padding({ left: PAGE_PAD, right: PAGE_PAD });
            // 结果列表
            List.scrollBar(BarState.Off);
        }, List);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            ForEach.create();
            const forEachItemGenFunction = _item => {
                const item = _item;
                {
                    const itemCreation = (elmtId, isInitialRender) => {
                        ViewStackProcessor.StartGetAccessRecordingFor(elmtId);
                        ListItem.create(deepRenderFunction, true);
                        if (!isInitialRender) {
                            ListItem.pop();
                        }
                        ViewStackProcessor.StopGetAccessRecording();
                    };
                    const itemCreation2 = (elmtId, isInitialRender) => {
                        ListItem.create(deepRenderFunction, true);
                        ListItem.onClick(() => {
                            this.pick(item);
                        });
                        ListItem.debugLine("entry/src/main/ets/pages/ManualAdd.ets(148:11)", "entry");
                    };
                    const deepRenderFunction = (elmtId, isInitialRender) => {
                        itemCreation(elmtId, isInitialRender);
                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                            Row.create();
                            Row.debugLine("entry/src/main/ets/pages/ManualAdd.ets(149:13)", "entry");
                            Row.width('100%');
                            Row.padding(14);
                            Row.backgroundColor(COLOR_CARD);
                            Row.borderRadius(10);
                        }, Row);
                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                            Column.create({ space: 3 });
                            Column.debugLine("entry/src/main/ets/pages/ManualAdd.ets(150:15)", "entry");
                            Column.alignItems(HorizontalAlign.Start);
                            Column.layoutWeight(1);
                        }, Column);
                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                            Text.create(item.name);
                            Text.debugLine("entry/src/main/ets/pages/ManualAdd.ets(151:17)", "entry");
                            Text.fontSize(15);
                            Text.fontColor(COLOR_TEXT);
                        }, Text);
                        Text.pop();
                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                            Text.create(`${item.category} · 每 100 克`);
                            Text.debugLine("entry/src/main/ets/pages/ManualAdd.ets(154:17)", "entry");
                            Text.fontSize(11);
                            Text.fontColor(COLOR_TEXT_SUB);
                        }, Text);
                        Text.pop();
                        Column.pop();
                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                            Text.create(`${item.kcalPer100g}`);
                            Text.debugLine("entry/src/main/ets/pages/ManualAdd.ets(161:15)", "entry");
                            Text.fontSize(16);
                            Text.fontWeight(FontWeight.Medium);
                            Text.fontColor(this.selected !== null && this.selected.name === item.name ? COLOR_PRIMARY : COLOR_TEXT);
                        }, Text);
                        Text.pop();
                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                            Text.create(' 千卡');
                            Text.debugLine("entry/src/main/ets/pages/ManualAdd.ets(165:15)", "entry");
                            Text.fontSize(11);
                            Text.fontColor(COLOR_TEXT_SUB);
                        }, Text);
                        Text.pop();
                        Row.pop();
                        ListItem.pop();
                    };
                    this.observeComponentCreation2(itemCreation2, ListItem);
                    ListItem.pop();
                }
            };
            this.forEachUpdateFunction(elmtId, this.results, forEachItemGenFunction, (item: FoodItem) => item.name, false, false);
        }, ForEach);
        ForEach.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.results.length === 0) {
                this.ifElseBranchUpdateFunction(0, () => {
                    {
                        const itemCreation = (elmtId, isInitialRender) => {
                            ViewStackProcessor.StartGetAccessRecordingFor(elmtId);
                            ListItem.create(deepRenderFunction, true);
                            if (!isInitialRender) {
                                ListItem.pop();
                            }
                            ViewStackProcessor.StopGetAccessRecording();
                        };
                        const itemCreation2 = (elmtId, isInitialRender) => {
                            ListItem.create(deepRenderFunction, true);
                            ListItem.debugLine("entry/src/main/ets/pages/ManualAdd.ets(180:11)", "entry");
                        };
                        const deepRenderFunction = (elmtId, isInitialRender) => {
                            itemCreation(elmtId, isInitialRender);
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Column.create({ space: 6 });
                                Column.debugLine("entry/src/main/ets/pages/ManualAdd.ets(181:13)", "entry");
                                Column.width('100%');
                                Column.padding(24);
                                Column.backgroundColor(COLOR_CARD);
                                Column.borderRadius(RADIUS);
                            }, Column);
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Text.create('没找到这个食物');
                                Text.debugLine("entry/src/main/ets/pages/ManualAdd.ets(182:15)", "entry");
                                Text.fontSize(14);
                                Text.fontColor(COLOR_TEXT);
                            }, Text);
                            Text.pop();
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Text.create('试试换个说法，或者用拍照识别让 AI 估算');
                                Text.debugLine("entry/src/main/ets/pages/ManualAdd.ets(185:15)", "entry");
                                Text.fontSize(12);
                                Text.fontColor(COLOR_TEXT_SUB);
                            }, Text);
                            Text.pop();
                            Column.pop();
                            ListItem.pop();
                        };
                        this.observeComponentCreation2(itemCreation2, ListItem);
                        ListItem.pop();
                    }
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        {
            const itemCreation = (elmtId, isInitialRender) => {
                ViewStackProcessor.StartGetAccessRecordingFor(elmtId);
                ListItem.create(deepRenderFunction, true);
                if (!isInitialRender) {
                    ListItem.pop();
                }
                ViewStackProcessor.StopGetAccessRecording();
            };
            const itemCreation2 = (elmtId, isInitialRender) => {
                ListItem.create(deepRenderFunction, true);
                ListItem.debugLine("entry/src/main/ets/pages/ManualAdd.ets(196:9)", "entry");
            };
            const deepRenderFunction = (elmtId, isInitialRender) => {
                itemCreation(elmtId, isInitialRender);
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Row.create();
                    Row.debugLine("entry/src/main/ets/pages/ManualAdd.ets(197:11)", "entry");
                    Row.height(100);
                }, Row);
                Row.pop();
                ListItem.pop();
            };
            this.observeComponentCreation2(itemCreation2, ListItem);
            ListItem.pop();
        }
        // 结果列表
        List.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            // 底部：已选食物 + 份量 + 保存
            if (this.selected !== null) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create({ space: 12 });
                        Column.debugLine("entry/src/main/ets/pages/ManualAdd.ets(207:9)", "entry");
                        Column.width('100%');
                        Column.padding(16);
                        Column.backgroundColor(COLOR_CARD);
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Row.create();
                        Row.debugLine("entry/src/main/ets/pages/ManualAdd.ets(208:11)", "entry");
                        Row.width('100%');
                    }, Row);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create({ space: 3 });
                        Column.debugLine("entry/src/main/ets/pages/ManualAdd.ets(209:13)", "entry");
                        Column.alignItems(HorizontalAlign.Start);
                        Column.layoutWeight(1);
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(this.selected.name);
                        Text.debugLine("entry/src/main/ets/pages/ManualAdd.ets(210:15)", "entry");
                        Text.fontSize(15);
                        Text.fontWeight(FontWeight.Medium);
                        Text.fontColor(COLOR_TEXT);
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(this.preview() !== null
                            ? `${(this.preview() as FoodDraft).kcal} 千卡 · 蛋白 ${(this.preview() as FoodDraft).protein}g / 脂肪 ${(this.preview() as FoodDraft).fat}g / 碳水 ${(this.preview() as FoodDraft).carb}g`
                            : '');
                        Text.debugLine("entry/src/main/ets/pages/ManualAdd.ets(214:15)", "entry");
                        Text.fontSize(11);
                        Text.fontColor(COLOR_TEXT_SUB);
                    }, Text);
                    Text.pop();
                    Column.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Button.createWithChild({ type: ButtonType.Circle });
                        Button.debugLine("entry/src/main/ets/pages/ManualAdd.ets(223:13)", "entry");
                        Button.width(28);
                        Button.height(28);
                        Button.backgroundColor(COLOR_DIVIDER);
                        Button.onClick(() => {
                            this.selected = null;
                        });
                    }, Button);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('✕');
                        Text.debugLine("entry/src/main/ets/pages/ManualAdd.ets(224:15)", "entry");
                        Text.fontSize(13);
                        Text.fontColor(COLOR_TEXT_SUB);
                    }, Text);
                    Text.pop();
                    Button.pop();
                    Row.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Row.create({ space: 10 });
                        Row.debugLine("entry/src/main/ets/pages/ManualAdd.ets(233:11)", "entry");
                        Row.width('100%');
                    }, Row);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('份量');
                        Text.debugLine("entry/src/main/ets/pages/ManualAdd.ets(234:13)", "entry");
                        Text.fontSize(13);
                        Text.fontColor(COLOR_TEXT_SUB);
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        TextInput.create({ text: this.gramsText });
                        TextInput.debugLine("entry/src/main/ets/pages/ManualAdd.ets(237:13)", "entry");
                        TextInput.type(InputType.NUMBER_DECIMAL);
                        TextInput.fontSize(14);
                        TextInput.height(40);
                        TextInput.layoutWeight(1);
                        TextInput.backgroundColor(COLOR_BG);
                        TextInput.borderRadius(8);
                        TextInput.onChange((v: string) => {
                            this.gramsText = v;
                        });
                    }, TextInput);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('克');
                        Text.debugLine("entry/src/main/ets/pages/ManualAdd.ets(247:13)", "entry");
                        Text.fontSize(13);
                        Text.fontColor(COLOR_TEXT_SUB);
                    }, Text);
                    Text.pop();
                    Row.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Row.create({ space: 8 });
                        Row.debugLine("entry/src/main/ets/pages/ManualAdd.ets(253:11)", "entry");
                        Row.width('100%');
                    }, Row);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        ForEach.create();
                        const forEachItemGenFunction = _item => {
                            const m = _item;
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Text.create(mealTypeLabel(m));
                                Text.debugLine("entry/src/main/ets/pages/ManualAdd.ets(255:15)", "entry");
                                Text.fontSize(13);
                                Text.fontColor(this.meal === m ? Color.White : COLOR_TEXT);
                                Text.textAlign(TextAlign.Center);
                                Text.layoutWeight(1);
                                Text.height(34);
                                Text.backgroundColor(this.meal === m ? COLOR_PRIMARY : COLOR_BG);
                                Text.borderRadius(8);
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
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Button.createWithChild({ type: ButtonType.Capsule });
                        Button.debugLine("entry/src/main/ets/pages/ManualAdd.ets(270:11)", "entry");
                        Button.width('100%');
                        Button.height(46);
                        Button.backgroundColor(COLOR_PRIMARY);
                        Button.onClick(() => {
                            this.save();
                        });
                    }, Button);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('添加到记录');
                        Text.debugLine("entry/src/main/ets/pages/ManualAdd.ets(271:13)", "entry");
                        Text.fontSize(16);
                        Text.fontColor(Color.White);
                    }, Text);
                    Text.pop();
                    Button.pop();
                    Column.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        Column.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
    public __resetStateVarsOnReuse__Internal(params: Object): void {
    }
    static getEntryName(): string {
        return "ManualAdd";
    }
}
registerNamedRoute(() => new ManualAdd(undefined, {}), "", { bundleName: "Calories.Lite.Test", moduleName: "entry", pagePath: "pages/ManualAdd", pageFullPath: "entry/src/main/ets/pages/ManualAdd", integratedHsp: "false", moduleType: "followWithHap" });
