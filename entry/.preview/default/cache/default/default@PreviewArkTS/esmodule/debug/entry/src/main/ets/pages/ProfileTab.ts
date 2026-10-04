if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface ProfileTab_Params {
    refreshTick?: number;
    profile?: UserProfile;
    aiReady?: boolean;
    profileVersion?: number;
    bmr?: number;
    tdee?: number;
    budget?: number;
    latestWeight?: number;
    effectiveWeight?: number;
    sheetShown?: boolean;
    editing?: string;
    pickerOptions?: string[];
    pickerIndex?: number;
    weightText?: string;
}
import router from "@ohos:router";
import promptAction from "@ohos:promptAction";
import hilog from "@ohos:hilog";
import { Gender } from "@normalized:N&&&entry/src/main/ets/model/Types&";
import type { ActivityLevel, Goal, UserProfile } from "@normalized:N&&&entry/src/main/ets/model/Types&";
import { ACTIVITY_ORDER, GOAL_ORDER, activityDesc, activityLabel, genderLabel, goalDesc, goalLabel } from "@normalized:N&&&entry/src/main/ets/model/Enums&";
import { calcBmi, calcBmr, calcDailyBudget, calcTdee, bmiLabel, estimateDaysToGoal } from "@normalized:N&&&entry/src/main/ets/service/CalorieCalc&";
import { DailyService } from "@normalized:N&&&entry/src/main/ets/service/DailyService&";
import { SettingsRepo } from "@normalized:N&&&entry/src/main/ets/service/SettingsRepo&";
import { AppState } from "@normalized:N&&&entry/src/main/ets/common/AppState&";
import { CARD_SHADOW, COLOR_BG, COLOR_CARD, COLOR_DIVIDER, COLOR_OK, COLOR_PRIMARY, COLOR_TEXT, COLOR_TEXT_SUB, COLOR_WARN, DUR_SLOW, GAP, NAV_RESERVE, PAGE_PAD, RADIUS } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
import { RollingNumber } from "@normalized:N&&&entry/src/main/ets/components/RollingNumber&";
const DOMAIN = 0x0000;
export class ProfileTab extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__refreshTick = new SynchedPropertySimpleOneWayPU(params.refreshTick, this, "refreshTick");
        this.__profile = new ObservedPropertyObjectPU(SettingsRepo.loadProfile(), this, "profile");
        this.__aiReady = new ObservedPropertySimplePU(false, this, "aiReady");
        this.__profileVersion = new ObservedPropertySimplePU(0, this, "profileVersion");
        this.__bmr = new ObservedPropertySimplePU(0, this, "bmr");
        this.__tdee = new ObservedPropertySimplePU(0, this, "tdee");
        this.__budget = new ObservedPropertySimplePU(0, this, "budget");
        this.__latestWeight = new ObservedPropertySimplePU(0, this, "latestWeight");
        this.__effectiveWeight = new ObservedPropertySimplePU(0, this, "effectiveWeight");
        this.__sheetShown = new ObservedPropertySimplePU(false, this, "sheetShown");
        this.__editing = new ObservedPropertySimplePU('age', this, "editing");
        this.__pickerOptions = new ObservedPropertyObjectPU([], this, "pickerOptions");
        this.__pickerIndex = new ObservedPropertySimplePU(0, this, "pickerIndex");
        this.__weightText = new ObservedPropertySimplePU('', this, "weightText");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: ProfileTab_Params) {
        if (params.refreshTick === undefined) {
            this.__refreshTick.set(0);
        }
        if (params.profile !== undefined) {
            this.profile = params.profile;
        }
        if (params.aiReady !== undefined) {
            this.aiReady = params.aiReady;
        }
        if (params.profileVersion !== undefined) {
            this.profileVersion = params.profileVersion;
        }
        if (params.bmr !== undefined) {
            this.bmr = params.bmr;
        }
        if (params.tdee !== undefined) {
            this.tdee = params.tdee;
        }
        if (params.budget !== undefined) {
            this.budget = params.budget;
        }
        if (params.latestWeight !== undefined) {
            this.latestWeight = params.latestWeight;
        }
        if (params.effectiveWeight !== undefined) {
            this.effectiveWeight = params.effectiveWeight;
        }
        if (params.sheetShown !== undefined) {
            this.sheetShown = params.sheetShown;
        }
        if (params.editing !== undefined) {
            this.editing = params.editing;
        }
        if (params.pickerOptions !== undefined) {
            this.pickerOptions = params.pickerOptions;
        }
        if (params.pickerIndex !== undefined) {
            this.pickerIndex = params.pickerIndex;
        }
        if (params.weightText !== undefined) {
            this.weightText = params.weightText;
        }
    }
    updateStateVars(params: ProfileTab_Params) {
        this.__refreshTick.reset(params.refreshTick);
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__refreshTick.purgeDependencyOnElmtId(rmElmtId);
        this.__profile.purgeDependencyOnElmtId(rmElmtId);
        this.__aiReady.purgeDependencyOnElmtId(rmElmtId);
        this.__profileVersion.purgeDependencyOnElmtId(rmElmtId);
        this.__bmr.purgeDependencyOnElmtId(rmElmtId);
        this.__tdee.purgeDependencyOnElmtId(rmElmtId);
        this.__budget.purgeDependencyOnElmtId(rmElmtId);
        this.__latestWeight.purgeDependencyOnElmtId(rmElmtId);
        this.__effectiveWeight.purgeDependencyOnElmtId(rmElmtId);
        this.__sheetShown.purgeDependencyOnElmtId(rmElmtId);
        this.__editing.purgeDependencyOnElmtId(rmElmtId);
        this.__pickerOptions.purgeDependencyOnElmtId(rmElmtId);
        this.__pickerIndex.purgeDependencyOnElmtId(rmElmtId);
        this.__weightText.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__refreshTick.aboutToBeDeleted();
        this.__profile.aboutToBeDeleted();
        this.__aiReady.aboutToBeDeleted();
        this.__profileVersion.aboutToBeDeleted();
        this.__bmr.aboutToBeDeleted();
        this.__tdee.aboutToBeDeleted();
        this.__budget.aboutToBeDeleted();
        this.__latestWeight.aboutToBeDeleted();
        this.__effectiveWeight.aboutToBeDeleted();
        this.__sheetShown.aboutToBeDeleted();
        this.__editing.aboutToBeDeleted();
        this.__pickerOptions.aboutToBeDeleted();
        this.__pickerIndex.aboutToBeDeleted();
        this.__weightText.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __refreshTick: SynchedPropertySimpleOneWayPU<number>;
    get refreshTick() {
        return this.__refreshTick.get();
    }
    set refreshTick(newValue: number) {
        this.__refreshTick.set(newValue);
    }
    /**
     * 个人档案。
     *
     * 刻意用 @State 保存整份档案，并在每次修改时**换一个新对象**：
     * ArkUI 的 @State 只比较引用，直接改 this.profile.age 不会触发重建，
     * 表现就是「改了年龄但卡片上的数字不动」。换对象才稳。
     */
    private __profile: ObservedPropertyObjectPU<UserProfile>;
    get profile() {
        return this.__profile.get();
    }
    set profile(newValue: UserProfile) {
        this.__profile.set(newValue);
    }
    private __aiReady: ObservedPropertySimplePU<boolean>;
    get aiReady() {
        return this.__aiReady.get();
    }
    set aiReady(newValue: boolean) {
        this.__aiReady.set(newValue);
    }
    private __profileVersion: ObservedPropertySimplePU<number>;
    get profileVersion() {
        return this.__profileVersion.get();
    }
    set profileVersion(newValue: number) {
        this.__profileVersion.set(newValue);
    }
    private __bmr: ObservedPropertySimplePU<number>;
    get bmr() {
        return this.__bmr.get();
    }
    set bmr(newValue: number) {
        this.__bmr.set(newValue);
    }
    private __tdee: ObservedPropertySimplePU<number>;
    get tdee() {
        return this.__tdee.get();
    }
    set tdee(newValue: number) {
        this.__tdee.set(newValue);
    }
    private __budget: ObservedPropertySimplePU<number>;
    get budget() {
        return this.__budget.get();
    }
    set budget(newValue: number) {
        this.__budget.set(newValue);
    }
    private __latestWeight: ObservedPropertySimplePU<number>;
    get latestWeight() {
        return this.__latestWeight.get();
    }
    set latestWeight(newValue: number) {
        this.__latestWeight.set(newValue);
    }
    /** 计算用的体重取值（可能是体重记录里的最新值，未必等于档案里的值） */
    private __effectiveWeight: ObservedPropertySimplePU<number>;
    get effectiveWeight() {
        return this.__effectiveWeight.get();
    }
    set effectiveWeight(newValue: number) {
        this.__effectiveWeight.set(newValue);
    }
    // ---- 底部选择面板 ----
    /** 是否展示面板 */
    private __sheetShown: ObservedPropertySimplePU<boolean>;
    get sheetShown() {
        return this.__sheetShown.get();
    }
    set sheetShown(newValue: boolean) {
        this.__sheetShown.set(newValue);
    }
    /** 当前在编辑哪一项：age / height / weight */
    private __editing: ObservedPropertySimplePU<string>;
    get editing() {
        return this.__editing.get();
    }
    set editing(newValue: string) {
        this.__editing.set(newValue);
    }
    /** 滚轮的候选项：年龄与身高用 */
    private __pickerOptions: ObservedPropertyObjectPU<string[]>;
    get pickerOptions() {
        return this.__pickerOptions.get();
    }
    set pickerOptions(newValue: string[]) {
        this.__pickerOptions.set(newValue);
    }
    /** 滚轮选中的下标 */
    private __pickerIndex: ObservedPropertySimplePU<number>;
    get pickerIndex() {
        return this.__pickerIndex.get();
    }
    set pickerIndex(newValue: number) {
        this.__pickerIndex.set(newValue);
    }
    /** 体重输入框的值 */
    private __weightText: ObservedPropertySimplePU<string>;
    get weightText() {
        return this.__weightText.get();
    }
    set weightText(newValue: string) {
        this.__weightText.set(newValue);
    }
    aboutToAppear(): void {
        this.reload();
    }
    onDidUpdate(): void {
        this.reload();
    }
    /** 面板标题 */
    private sheetTitle(): string {
        if (this.editing === 'age') {
            return '年龄';
        }
        return this.editing === 'height' ? '身高' : '体重';
    }
    /** 打开选择面板，并按当前值定位滚轮 */
    private openPicker(which: string): void {
        this.editing = which;
        if (which === 'weight') {
            // 体重用输入框：0.1 公斤的精度用滚轮太难拨
            this.weightText = `${this.profile.weightKg}`;
        }
        else {
            const from: number = which === 'age' ? 10 : 100;
            const to: number = which === 'age' ? 120 : 250;
            const cur: number = which === 'age' ? this.profile.age : this.profile.heightCm;
            const opts: string[] = [];
            for (let v = from; v <= to; v++) {
                opts.push(`${v}`);
            }
            this.pickerOptions = opts;
            const idx: number = cur - from;
            this.pickerIndex = idx >= 0 && idx < opts.length ? idx : 0;
        }
        this.sheetShown = true;
    }
    /** 确认写入 */
    private confirmPicker(): void {
        const which: string = this.editing;
        if (which === 'weight') {
            const v: number = Number.parseFloat(this.weightText);
            if (Number.isNaN(v) || v < 20 || v > 400) {
                promptAction.showToast({ message: '请输入 20-400 之间的体重' });
                return;
            }
            const rounded: number = Math.round(v * 10) / 10;
            this.apply((p: UserProfile) => {
                p.weightKg = rounded;
            });
        }
        else if (this.pickerOptions.length > 0) {
            const chosen: number = Number.parseInt(this.pickerOptions[this.pickerIndex]);
            if (which === 'age') {
                this.apply((p: UserProfile) => {
                    p.age = chosen;
                });
            }
            else {
                this.apply((p: UserProfile) => {
                    p.heightCm = chosen;
                });
            }
        }
        this.sheetShown = false;
    }
    private reload(): void {
        this.profile = SettingsRepo.loadProfile();
        this.aiReady = SettingsRepo.isAiReady();
        this.profileVersion++;
        const effective: UserProfile = DailyService.effectiveProfile();
        this.latestWeight = effective.weightKg;
        this.effectiveWeight = effective.weightKg;
        this.bmr = Math.round(calcBmr(effective));
        this.tdee = Math.round(calcTdee(effective));
        this.budget = calcDailyBudget(effective);
    }
    /**
     * 改一个字段并立刻生效。
     *
     * 三步缺一不可：换新对象（触发重建）→ 落盘 → 重算卡片数字。
     */
    private apply(update: (p: UserProfile) => void): void {
        const next: UserProfile = SettingsRepo.loadProfile();
        update(next);
        SettingsRepo.saveProfile(next);
        this.profile = next;
        this.profileVersion++;
        const effective: UserProfile = DailyService.effectiveProfile();
        this.latestWeight = effective.weightKg;
        this.bmr = Math.round(calcBmr(effective));
        this.tdee = Math.round(calcTdee(effective));
        this.budget = calcDailyBudget(effective);
        // 通知首页等同进程内的其它页面按新档案重算
        AppState.profileDirty = true;
    }
    private bmi(): number {
        return Math.round(calcBmi(this.latestWeight, this.profile.heightCm) * 10) / 10;
    }
    /** 目标达成预估天数，-1 表示当前目标不是减脂 */
    private goalDays(): number {
        const target: number = this.profile.gender === Gender.MALE ? 70 : 60;
        return estimateDaysToGoal(DailyService.effectiveProfile(), target);
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            /*
             * 用 Stack 叠一层自绘的底部面板，而不是系统的 bindSheet。
             *
             * 原因：bindSheet 自带一个圆形关闭按钮，压在右上角、正好盖住「确定」。
             * 试过 showClose: false，那个按钮依然在（说明它不是 showClose 控制的），
             * 所以干脆自绘——外观完全可控，也不会多出第二个关闭入口。
             */
            Stack.create({ alignContent: Alignment.Bottom });
            Stack.debugLine("entry/src/main/ets/pages/ProfileTab.ets(170:5)", "entry");
            /*
             * 用 Stack 叠一层自绘的底部面板，而不是系统的 bindSheet。
             *
             * 原因：bindSheet 自带一个圆形关闭按钮，压在右上角、正好盖住「确定」。
             * 试过 showClose: false，那个按钮依然在（说明它不是 showClose 控制的），
             * 所以干脆自绘——外观完全可控，也不会多出第二个关闭入口。
             */
            Stack.width('100%');
            /*
             * 用 Stack 叠一层自绘的底部面板，而不是系统的 bindSheet。
             *
             * 原因：bindSheet 自带一个圆形关闭按钮，压在右上角、正好盖住「确定」。
             * 试过 showClose: false，那个按钮依然在（说明它不是 showClose 控制的），
             * 所以干脆自绘——外观完全可控，也不会多出第二个关闭入口。
             */
            Stack.height('100%');
            /*
             * 用 Stack 叠一层自绘的底部面板，而不是系统的 bindSheet。
             *
             * 原因：bindSheet 自带一个圆形关闭按钮，压在右上角、正好盖住「确定」。
             * 试过 showClose: false，那个按钮依然在（说明它不是 showClose 控制的），
             * 所以干脆自绘——外观完全可控，也不会多出第二个关闭入口。
             */
            Stack.backgroundColor(COLOR_BG);
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Scroll.create();
            Scroll.debugLine("entry/src/main/ets/pages/ProfileTab.ets(171:7)", "entry");
            Scroll.width('100%');
            Scroll.height('100%');
            Scroll.backgroundColor(COLOR_BG);
            Scroll.scrollBar(BarState.Off);
            Scroll.align(Alignment.Top);
        }, Scroll);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: GAP });
            Column.debugLine("entry/src/main/ets/pages/ProfileTab.ets(172:9)", "entry");
            Column.width('100%');
            Column.padding({ left: PAGE_PAD, right: PAGE_PAD, top: 8 });
        }, Column);
        // ------------------------------------------------ 基础热量卡片
        this.budgetCard.bind(this)();
        // ------------------------------------------------ 个人情况
        this.profileCard.bind(this)();
        // ------------------------------------------------ AI 识别
        this.aiCard.bind(this)();
        // ------------------------------------------------ 关于与数据
        this.miscCard.bind(this)();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/ProfileTab.ets(185:11)", "entry");
            Row.height(NAV_RESERVE);
        }, Row);
        Row.pop();
        Column.pop();
        Scroll.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.sheetShown) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        // 半透明遮罩：点它也能关掉面板
                        Column.create();
                        Column.debugLine("entry/src/main/ets/pages/ProfileTab.ets(198:9)", "entry");
                        // 半透明遮罩：点它也能关掉面板
                        Column.width('100%');
                        // 半透明遮罩：点它也能关掉面板
                        Column.height('100%');
                        // 半透明遮罩：点它也能关掉面板
                        Column.backgroundColor('#66000000');
                        // 半透明遮罩：点它也能关掉面板
                        Column.onClick(() => {
                            this.sheetShown = false;
                        });
                    }, Column);
                    // 半透明遮罩：点它也能关掉面板
                    Column.pop();
                    this.valueSheet.bind(this)();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        /*
         * 用 Stack 叠一层自绘的底部面板，而不是系统的 bindSheet。
         *
         * 原因：bindSheet 自带一个圆形关闭按钮，压在右上角、正好盖住「确定」。
         * 试过 showClose: false，那个按钮依然在（说明它不是 showClose 控制的），
         * 所以干脆自绘——外观完全可控，也不会多出第二个关闭入口。
         */
        Stack.pop();
    }
    /** 数值选择面板（自绘底部弹层） */
    valueSheet(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 12 });
            Column.debugLine("entry/src/main/ets/pages/ProfileTab.ets(217:5)", "entry");
            Column.width('100%');
            Column.padding({ left: PAGE_PAD, right: PAGE_PAD });
            Column.backgroundColor(COLOR_CARD);
            Column.borderRadius({ topLeft: 20, topRight: 20 });
            Column.padding({ bottom: AppState.bottomInset + 12 });
            Column.transition(TransitionEffect.OPACITY
                .combine(TransitionEffect.translate({ y: 240 }))
                .animation({ duration: 260, curve: Curve.FastOutSlowIn }));
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 顶部拖拽条：提示这是一个可以下拉关闭的面板
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/ProfileTab.ets(219:7)", "entry");
            // 顶部拖拽条：提示这是一个可以下拉关闭的面板
            Row.width(36);
            // 顶部拖拽条：提示这是一个可以下拉关闭的面板
            Row.height(4);
            // 顶部拖拽条：提示这是一个可以下拉关闭的面板
            Row.backgroundColor(COLOR_DIVIDER);
            // 顶部拖拽条：提示这是一个可以下拉关闭的面板
            Row.borderRadius(2);
            // 顶部拖拽条：提示这是一个可以下拉关闭的面板
            Row.margin({ top: 8, bottom: 2 });
        }, Row);
        // 顶部拖拽条：提示这是一个可以下拉关闭的面板
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/ProfileTab.ets(226:7)", "entry");
            Row.width('100%');
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithChild({ type: ButtonType.Capsule });
            Button.debugLine("entry/src/main/ets/pages/ProfileTab.ets(227:9)", "entry");
            Button.height(34);
            Button.backgroundColor(COLOR_BG);
            Button.onClick(() => {
                this.sheetShown = false;
            });
        }, Button);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('取消');
            Text.debugLine("entry/src/main/ets/pages/ProfileTab.ets(228:11)", "entry");
            Text.fontSize(14);
            Text.fontColor(COLOR_TEXT_SUB);
        }, Text);
        Text.pop();
        Button.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.sheetTitle());
            Text.debugLine("entry/src/main/ets/pages/ProfileTab.ets(236:9)", "entry");
            Text.fontSize(16);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(COLOR_TEXT);
            Text.layoutWeight(1);
            Text.textAlign(TextAlign.Center);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 右端只有「确定」，不再有系统那个圆形关闭按钮压在上面
            Button.createWithChild({ type: ButtonType.Capsule });
            Button.debugLine("entry/src/main/ets/pages/ProfileTab.ets(244:9)", "entry");
            // 右端只有「确定」，不再有系统那个圆形关闭按钮压在上面
            Button.height(34);
            // 右端只有「确定」，不再有系统那个圆形关闭按钮压在上面
            Button.backgroundColor(COLOR_PRIMARY);
            // 右端只有「确定」，不再有系统那个圆形关闭按钮压在上面
            Button.onClick(() => {
                this.confirmPicker();
            });
        }, Button);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('确定');
            Text.debugLine("entry/src/main/ets/pages/ProfileTab.ets(245:11)", "entry");
            Text.fontSize(14);
            Text.fontColor(Color.White);
        }, Text);
        Text.pop();
        // 右端只有「确定」，不再有系统那个圆形关闭按钮压在上面
        Button.pop();
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.editing === 'weight') {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        // 体重：直接调起数字键盘，允许一位小数
                        TextInput.create({ text: this.weightText, placeholder: '输入体重' });
                        TextInput.debugLine("entry/src/main/ets/pages/ProfileTab.ets(257:9)", "entry");
                        // 体重：直接调起数字键盘，允许一位小数
                        TextInput.type(InputType.NUMBER_DECIMAL);
                        // 体重：直接调起数字键盘，允许一位小数
                        TextInput.fontSize(24);
                        // 体重：直接调起数字键盘，允许一位小数
                        TextInput.fontWeight(FontWeight.Medium);
                        // 体重：直接调起数字键盘，允许一位小数
                        TextInput.textAlign(TextAlign.Center);
                        // 体重：直接调起数字键盘，允许一位小数
                        TextInput.height(64);
                        // 体重：直接调起数字键盘，允许一位小数
                        TextInput.width('100%');
                        // 体重：直接调起数字键盘，允许一位小数
                        TextInput.backgroundColor(COLOR_BG);
                        // 体重：直接调起数字键盘，允许一位小数
                        TextInput.borderRadius(12);
                        // 体重：直接调起数字键盘，允许一位小数
                        TextInput.onChange((v: string) => {
                            this.weightText = v;
                        });
                    }, TextInput);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('公斤，可精确到 0.1');
                        Text.debugLine("entry/src/main/ets/pages/ProfileTab.ets(270:9)", "entry");
                        Text.fontSize(11);
                        Text.fontColor(COLOR_TEXT_SUB);
                    }, Text);
                    Text.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        TextPicker.create({ range: this.pickerOptions, selected: this.pickerIndex });
                        TextPicker.debugLine("entry/src/main/ets/pages/ProfileTab.ets(274:9)", "entry");
                        TextPicker.width('100%');
                        TextPicker.height(180);
                        TextPicker.selectedTextStyle({ color: COLOR_PRIMARY, font: { size: 20, weight: FontWeight.Medium } });
                        TextPicker.onChange((value: string | string[], index: number | number[]) => {
                            this.pickerIndex = typeof index === 'number' ? index : index[0];
                        });
                    }, TextPicker);
                    TextPicker.pop();
                });
            }
        }, If);
        If.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/ProfileTab.ets(283:7)", "entry");
            Row.height(16);
        }, Row);
        Row.pop();
        Column.pop();
    }
    budgetCard(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 12 });
            Column.debugLine("entry/src/main/ets/pages/ProfileTab.ets(299:5)", "entry");
            Column.width('100%');
            Column.padding(16);
            Column.backgroundColor(COLOR_CARD);
            Column.borderRadius(RADIUS);
            Column.shadow(CARD_SHADOW);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('每日基础热量');
            Text.debugLine("entry/src/main/ets/pages/ProfileTab.ets(300:7)", "entry");
            Text.fontSize(13);
            Text.fontColor(COLOR_TEXT_SUB);
            Text.width('100%');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/ProfileTab.ets(305:7)", "entry");
            Row.alignItems(VerticalAlign.Bottom);
            Row.width('100%');
        }, Row);
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new RollingNumber(this, {
                        value: this.budget,
                        fontSize: 40,
                        fontWeight: FontWeight.Bold,
                        textColor: COLOR_PRIMARY,
                        duration: DUR_SLOW
                    }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/ProfileTab.ets", line: 306, col: 9 });
                    ViewPU.create(componentCall);
                    let paramsLambda = () => {
                        return {
                            value: this.budget,
                            fontSize: 40,
                            fontWeight: FontWeight.Bold,
                            textColor: COLOR_PRIMARY,
                            duration: DUR_SLOW
                        };
                    };
                    componentCall.paramsGenerator_ = paramsLambda;
                }
                else {
                    this.updateStateVarsOfChildByElmtId(elmtId, {
                        value: this.budget,
                        fontSize: 40,
                        fontWeight: FontWeight.Bold,
                        textColor: COLOR_PRIMARY,
                        duration: DUR_SLOW
                    });
                }
            }, { name: "RollingNumber" });
        }
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(' 千卡');
            Text.debugLine("entry/src/main/ets/pages/ProfileTab.ets(313:9)", "entry");
            Text.fontSize(14);
            Text.fontColor(COLOR_TEXT_SUB);
            Text.margin({ bottom: 6 });
        }, Text);
        Text.pop();
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Divider.create();
            Divider.debugLine("entry/src/main/ets/pages/ProfileTab.ets(321:7)", "entry");
            Divider.color(COLOR_DIVIDER);
        }, Divider);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/ProfileTab.ets(323:7)", "entry");
            Row.width('100%');
            Row.justifyContent(FlexAlign.SpaceBetween);
        }, Row);
        this.metric.bind(this)('基础代谢', () => this.bmr);
        this.metric.bind(this)('总消耗', () => this.tdee);
        this.metric.bind(this)('BMI', () => this.bmi(), () => bmiLabel(this.bmi()), 1);
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(`按当前体重 ${this.latestWeight} 公斤、${genderLabel(this.profile.gender)}性、${this.profile.age} 岁、${this.profile.heightCm} 厘米计算`);
            Text.debugLine("entry/src/main/ets/pages/ProfileTab.ets(331:7)", "entry");
            Text.fontSize(11);
            Text.fontColor(COLOR_TEXT_SUB);
            Text.width('100%');
        }, Text);
        Text.pop();
        Column.pop();
    }
    /**
     * 一项指标，数字带滚动动效。
     *
     * value 用取值函数而不是直接传值：@Builder 的参数在容器构建时求值一次，
     * 之后状态变化不会重新求值，传值会表现为「改了年龄但卡片数字不动」。
     * 返回 number 而不是 string，才能交给 RollingNumber 逐帧插值。
     */
    metric(label: string, value: () => number, sub: () => string = () => '', decimals: number = 0, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 2 });
            Column.debugLine("entry/src/main/ets/pages/ProfileTab.ets(352:5)", "entry");
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
                        duration: DUR_SLOW,
                        decimals: decimals
                    }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/ProfileTab.ets", line: 353, col: 7 });
                    ViewPU.create(componentCall);
                    let paramsLambda = () => {
                        return {
                            value: value(),
                            fontSize: 18,
                            fontWeight: FontWeight.Medium,
                            textColor: COLOR_TEXT,
                            duration: DUR_SLOW,
                            decimals: decimals
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
                        duration: DUR_SLOW,
                        decimals: decimals
                    });
                }
            }, { name: "RollingNumber" });
        }
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(sub().length > 0 ? `${label} · ${sub()}` : label);
            Text.debugLine("entry/src/main/ets/pages/ProfileTab.ets(361:7)", "entry");
            Text.fontSize(11);
            Text.fontColor(COLOR_TEXT_SUB);
        }, Text);
        Text.pop();
        Column.pop();
    }
    profileCard(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 14 });
            Column.debugLine("entry/src/main/ets/pages/ProfileTab.ets(370:5)", "entry");
            Column.width('100%');
            Column.padding(16);
            Column.backgroundColor(COLOR_CARD);
            Column.borderRadius(RADIUS);
            Column.shadow(CARD_SHADOW);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('个人情况');
            Text.debugLine("entry/src/main/ets/pages/ProfileTab.ets(371:7)", "entry");
            Text.fontSize(15);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(COLOR_TEXT);
            Text.width('100%');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 性别
            Row.create({ space: 8 });
            Row.debugLine("entry/src/main/ets/pages/ProfileTab.ets(378:7)", "entry");
            // 性别
            Row.width('100%');
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('性别');
            Text.debugLine("entry/src/main/ets/pages/ProfileTab.ets(379:9)", "entry");
            Text.fontSize(14);
            Text.fontColor(COLOR_TEXT_SUB);
            Text.width(56);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            ForEach.create();
            const forEachItemGenFunction = _item => {
                const g = _item;
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Text.create(genderLabel(g));
                    Text.debugLine("entry/src/main/ets/pages/ProfileTab.ets(384:11)", "entry");
                    Text.fontSize(14);
                    Text.fontColor(this.profile.gender === g ? Color.White : COLOR_TEXT);
                    Text.textAlign(TextAlign.Center);
                    Text.layoutWeight(1);
                    Text.height(36);
                    Text.backgroundColor(this.profile.gender === g ? COLOR_PRIMARY : COLOR_BG);
                    Text.borderRadius(10);
                    Text.onClick(() => {
                        this.apply((p: UserProfile) => {
                            p.gender = g;
                        });
                    });
                }, Text);
                Text.pop();
            };
            this.forEachUpdateFunction(elmtId, [Gender.MALE, Gender.FEMALE], forEachItemGenFunction, (g: Gender) => g, false, false);
        }, ForEach);
        ForEach.pop();
        // 性别
        Row.pop();
        // 数值项：点击弹出底部选择面板
        this.numRow.bind(this)('年龄', () => this.profile.age, '岁', () => {
            this.openPicker('age');
        });
        this.numRow.bind(this)('身高', () => this.profile.heightCm, '厘米', () => {
            this.openPicker('height');
        });
        this.numRow.bind(this)('体重', () => this.profile.weightKg, '公斤', () => {
            this.openPicker('weight');
        });
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Divider.create();
            Divider.debugLine("entry/src/main/ets/pages/ProfileTab.ets(414:7)", "entry");
            Divider.color(COLOR_DIVIDER);
        }, Divider);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 活动水平
            Text.create('日常活动量');
            Text.debugLine("entry/src/main/ets/pages/ProfileTab.ets(417:7)", "entry");
            // 活动水平
            Text.fontSize(13);
            // 活动水平
            Text.fontColor(COLOR_TEXT_SUB);
            // 活动水平
            Text.width('100%');
        }, Text);
        // 活动水平
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            ForEach.create();
            const forEachItemGenFunction = _item => {
                const level = _item;
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Row.create();
                    Row.debugLine("entry/src/main/ets/pages/ProfileTab.ets(423:9)", "entry");
                    Row.width('100%');
                    Row.padding({ top: 8, bottom: 8 });
                    Row.onClick(() => {
                        this.apply((p: UserProfile) => {
                            p.activityLevel = level;
                        });
                    });
                }, Row);
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Column.create({ space: 2 });
                    Column.debugLine("entry/src/main/ets/pages/ProfileTab.ets(424:11)", "entry");
                    Column.alignItems(HorizontalAlign.Start);
                    Column.layoutWeight(1);
                }, Column);
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Text.create(activityLabel(level));
                    Text.debugLine("entry/src/main/ets/pages/ProfileTab.ets(425:13)", "entry");
                    Text.fontSize(14);
                    Text.fontColor(this.profile.activityLevel === level ? COLOR_PRIMARY : COLOR_TEXT);
                }, Text);
                Text.pop();
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Text.create(activityDesc(level));
                    Text.debugLine("entry/src/main/ets/pages/ProfileTab.ets(428:13)", "entry");
                    Text.fontSize(11);
                    Text.fontColor(COLOR_TEXT_SUB);
                }, Text);
                Text.pop();
                Column.pop();
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    If.create();
                    if (this.profile.activityLevel === level) {
                        this.ifElseBranchUpdateFunction(0, () => {
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Text.create('✓');
                                Text.debugLine("entry/src/main/ets/pages/ProfileTab.ets(436:13)", "entry");
                                Text.fontSize(16);
                                Text.fontColor(COLOR_PRIMARY);
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
            };
            this.forEachUpdateFunction(elmtId, ACTIVITY_ORDER, forEachItemGenFunction, (level: ActivityLevel) => level, false, false);
        }, ForEach);
        ForEach.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Divider.create();
            Divider.debugLine("entry/src/main/ets/pages/ProfileTab.ets(450:7)", "entry");
            Divider.color(COLOR_DIVIDER);
        }, Divider);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 目标
            Text.create('目标');
            Text.debugLine("entry/src/main/ets/pages/ProfileTab.ets(453:7)", "entry");
            // 目标
            Text.fontSize(13);
            // 目标
            Text.fontColor(COLOR_TEXT_SUB);
            // 目标
            Text.width('100%');
        }, Text);
        // 目标
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            ForEach.create();
            const forEachItemGenFunction = _item => {
                const goal = _item;
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Row.create();
                    Row.debugLine("entry/src/main/ets/pages/ProfileTab.ets(459:9)", "entry");
                    Row.width('100%');
                    Row.padding({ top: 8, bottom: 8 });
                    Row.onClick(() => {
                        this.apply((p: UserProfile) => {
                            p.goal = goal;
                        });
                    });
                }, Row);
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Column.create({ space: 2 });
                    Column.debugLine("entry/src/main/ets/pages/ProfileTab.ets(460:11)", "entry");
                    Column.alignItems(HorizontalAlign.Start);
                    Column.layoutWeight(1);
                }, Column);
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Text.create(goalLabel(goal));
                    Text.debugLine("entry/src/main/ets/pages/ProfileTab.ets(461:13)", "entry");
                    Text.fontSize(14);
                    Text.fontColor(this.profile.goal === goal ? COLOR_PRIMARY : COLOR_TEXT);
                }, Text);
                Text.pop();
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Text.create(goalDesc(goal));
                    Text.debugLine("entry/src/main/ets/pages/ProfileTab.ets(464:13)", "entry");
                    Text.fontSize(11);
                    Text.fontColor(COLOR_TEXT_SUB);
                }, Text);
                Text.pop();
                Column.pop();
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    If.create();
                    if (this.profile.goal === goal) {
                        this.ifElseBranchUpdateFunction(0, () => {
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Text.create('✓');
                                Text.debugLine("entry/src/main/ets/pages/ProfileTab.ets(472:13)", "entry");
                                Text.fontSize(16);
                                Text.fontColor(COLOR_PRIMARY);
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
            };
            this.forEachUpdateFunction(elmtId, GOAL_ORDER, forEachItemGenFunction, (goal: Goal) => goal, false, false);
        }, ForEach);
        ForEach.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.goalDays() > 0) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(`按当前目标，约 ${this.goalDays()} 天后可减到目标体重`);
                        Text.debugLine("entry/src/main/ets/pages/ProfileTab.ets(487:9)", "entry");
                        Text.fontSize(11);
                        Text.fontColor(COLOR_TEXT_SUB);
                        Text.width('100%');
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
        Column.pop();
    }
    /**
     * 一行数值项：点击数值弹出底部选择面板。
     *
     * 去掉了原来的「−」「+」小按钮——每点一次只挪一格，改 10 岁要点 10 次，
     * 而且两个按钮挤在行里让整行显得零碎。改成点数值直接调起
     * 底部半模态面板，年龄/身高用滚轮，体重用带小数点的键盘。
     *
     * value 用取值函数而不是直接传值：@Builder 的参数在容器构建时求值一次，
     * 之后状态变化不会重新求值，传值会表现为「改完数字不动」。
     */
    numRow(label: string, value: () => number, unit: string, onTap: () => void, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 8 });
            Row.debugLine("entry/src/main/ets/pages/ProfileTab.ets(512:5)", "entry");
            Row.width('100%');
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(label);
            Text.debugLine("entry/src/main/ets/pages/ProfileTab.ets(513:7)", "entry");
            Text.fontSize(14);
            Text.fontColor(COLOR_TEXT_SUB);
            Text.width(56);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
            Blank.debugLine("entry/src/main/ets/pages/ProfileTab.ets(518:7)", "entry");
        }, Blank);
        Blank.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 只有数值本身可点，热区抬到 40vp 保证好按
            Row.create({ space: 4 });
            Row.debugLine("entry/src/main/ets/pages/ProfileTab.ets(521:7)", "entry");
            // 只有数值本身可点，热区抬到 40vp 保证好按
            Row.height(40);
            // 只有数值本身可点，热区抬到 40vp 保证好按
            Row.padding({ left: 12, right: 6 });
            // 只有数值本身可点，热区抬到 40vp 保证好按
            Row.backgroundColor(COLOR_BG);
            // 只有数值本身可点，热区抬到 40vp 保证好按
            Row.borderRadius(10);
            // 只有数值本身可点，热区抬到 40vp 保证好按
            Row.onClick(onTap);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(`${value()}`);
            Text.debugLine("entry/src/main/ets/pages/ProfileTab.ets(522:9)", "entry");
            Text.fontSize(17);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(COLOR_PRIMARY);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(unit);
            Text.debugLine("entry/src/main/ets/pages/ProfileTab.ets(526:9)", "entry");
            Text.fontSize(12);
            Text.fontColor(COLOR_TEXT_SUB);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('›');
            Text.debugLine("entry/src/main/ets/pages/ProfileTab.ets(529:9)", "entry");
            Text.fontSize(14);
            Text.fontColor(COLOR_TEXT_SUB);
            Text.margin({ left: 2 });
        }, Text);
        Text.pop();
        // 只有数值本身可点，热区抬到 40vp 保证好按
        Row.pop();
        Row.pop();
    }
    aiCard(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 10 });
            Column.debugLine("entry/src/main/ets/pages/ProfileTab.ets(545:5)", "entry");
            Column.width('100%');
            Column.padding(16);
            Column.backgroundColor(COLOR_CARD);
            Column.borderRadius(RADIUS);
            Column.shadow(CARD_SHADOW);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/ProfileTab.ets(546:7)", "entry");
            Row.width('100%');
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('AI 拍照识别');
            Text.debugLine("entry/src/main/ets/pages/ProfileTab.ets(547:9)", "entry");
            Text.fontSize(15);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(COLOR_TEXT);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
            Blank.debugLine("entry/src/main/ets/pages/ProfileTab.ets(551:9)", "entry");
        }, Blank);
        Blank.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.aiReady ? '已配置' : '未配置');
            Text.debugLine("entry/src/main/ets/pages/ProfileTab.ets(552:9)", "entry");
            Text.fontSize(12);
            Text.fontColor(this.aiReady ? COLOR_OK : COLOR_WARN);
        }, Text);
        Text.pop();
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.aiReady
                ? '使用你自己的 DeepSeek API Key，识别结果只发往 DeepSeek'
                : '填上你的 DeepSeek API Key 就能拍照识别食物，一张照片约 0.4 分钱；本应用不提供也不代管任何额度');
            Text.debugLine("entry/src/main/ets/pages/ProfileTab.ets(558:7)", "entry");
            Text.fontSize(12);
            Text.fontColor(COLOR_TEXT_SUB);
            Text.width('100%');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithChild({ type: ButtonType.Capsule });
            Button.debugLine("entry/src/main/ets/pages/ProfileTab.ets(565:7)", "entry");
            Button.width('100%');
            Button.height(42);
            Button.backgroundColor(COLOR_PRIMARY);
            Button.onClick(() => {
                try {
                    router.pushUrl({ url: 'pages/AiSettings' });
                }
                catch (err) {
                    hilog.error(DOMAIN, 'CalorieLite', 'goAiSettings failed');
                }
            });
        }, Button);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.aiReady ? '修改配置' : '去配置');
            Text.debugLine("entry/src/main/ets/pages/ProfileTab.ets(566:9)", "entry");
            Text.fontSize(14);
            Text.fontColor(Color.White);
        }, Text);
        Text.pop();
        Button.pop();
        Column.pop();
    }
    miscCard(parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 4 });
            Column.debugLine("entry/src/main/ets/pages/ProfileTab.ets(590:5)", "entry");
            Column.width('100%');
            Column.padding(16);
            Column.backgroundColor(COLOR_CARD);
            Column.borderRadius(RADIUS);
            Column.shadow(CARD_SHADOW);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('关于');
            Text.debugLine("entry/src/main/ets/pages/ProfileTab.ets(591:7)", "entry");
            Text.fontSize(15);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(COLOR_TEXT);
            Text.width('100%');
            Text.margin({ bottom: 6 });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('轻卡记 —— 只做三件事：算出你一天该吃多少、帮你记下吃了多少、告诉你今天差多少。');
            Text.debugLine("entry/src/main/ets/pages/ProfileTab.ets(598:7)", "entry");
            Text.fontSize(12);
            Text.fontColor(COLOR_TEXT_SUB);
            Text.width('100%');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('所有记录只存在本机，不上传任何服务器；食物表内置，AI 识别按你自己的配置直连。');
            Text.debugLine("entry/src/main/ets/pages/ProfileTab.ets(603:7)", "entry");
            Text.fontSize(12);
            Text.fontColor(COLOR_TEXT_SUB);
            Text.width('100%');
            Text.margin({ top: 4 });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Divider.create();
            Divider.debugLine("entry/src/main/ets/pages/ProfileTab.ets(609:7)", "entry");
            Divider.color(COLOR_DIVIDER);
            Divider.margin({ top: 12, bottom: 8 });
        }, Divider);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/ProfileTab.ets(611:7)", "entry");
            Row.width('100%');
            Row.padding({ top: 6, bottom: 6 });
            Row.onClick(() => {
                this.confirmClear();
            });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('清空全部数据');
            Text.debugLine("entry/src/main/ets/pages/ProfileTab.ets(612:9)", "entry");
            Text.fontSize(14);
            Text.fontColor(COLOR_WARN);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
            Blank.debugLine("entry/src/main/ets/pages/ProfileTab.ets(615:9)", "entry");
        }, Blank);
        Blank.pop();
        Row.pop();
        Column.pop();
    }
    private async confirmClear(): Promise<void> {
        try {
            const res = await promptAction.showDialog({
                title: '清空全部数据',
                message: '会删除所有饮食记录、体重记录和设置，且无法恢复。确定继续吗？',
                buttons: [
                    { text: '取消', color: COLOR_TEXT_SUB },
                    { text: '清空', color: COLOR_WARN }
                ]
            });
            if (res.index === 1) {
                SettingsRepo.clearAll();
                this.reload();
                promptAction.showToast({ message: '已清空' });
            }
        }
        catch (err) {
            hilog.error(DOMAIN, 'CalorieLite', 'confirmClear failed');
        }
    }
    rerender() {
        this.updateDirtyElements();
    }
    public __resetStateVarsOnReuse__Internal(params: Object): void {
    }
}
