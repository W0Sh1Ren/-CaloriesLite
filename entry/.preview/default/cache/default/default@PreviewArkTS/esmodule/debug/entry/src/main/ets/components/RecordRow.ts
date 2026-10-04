if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface RecordRow_Params {
    record?: FoodRecord;
    /** 删除回调，由父组件处理数据与刷新 */
    onDelete?: (id: string) => void;
}
import { FoodRecord, FoodSource, MealType } from "@normalized:N&&&entry/src/main/ets/model/Types&";
import { foodSourceLabel } from "@normalized:N&&&entry/src/main/ets/model/Enums&";
import { timeLabel } from "@normalized:N&&&entry/src/main/ets/common/DateUtil&";
import { CARD_SHADOW, COLOR_CARB, COLOR_CARD, COLOR_DIVIDER, COLOR_FAT, COLOR_OK, COLOR_PROTEIN, COLOR_PRIMARY, COLOR_TEXT, COLOR_TEXT_SUB, RADIUS } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
export class RecordRow extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__record = new SynchedPropertyObjectOneWayPU(params.record, this, "record");
        this.onDelete = () => {
        };
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: RecordRow_Params) {
        if (params.record === undefined) {
            this.__record.set(new FoodRecord('', '', 0, MealType.SNACK, '', 0, 0, 0, 0, 0, FoodSource.MANUAL, '', ''));
        }
        if (params.onDelete !== undefined) {
            this.onDelete = params.onDelete;
        }
    }
    updateStateVars(params: RecordRow_Params) {
        this.__record.reset(params.record);
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__record.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__record.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __record: SynchedPropertySimpleOneWayPU<FoodRecord>;
    get record() {
        return this.__record.get();
    }
    set record(newValue: FoodRecord) {
        this.__record.set(newValue);
    }
    /** 删除回调，由父组件处理数据与刷新 */
    private onDelete: (id: string) => void;
    /** 来源标签的颜色：查表命中用绿色，AI 估算用主色，提醒用户可信度不同 */
    private sourceColor(): string {
        return this.record.source === FoodSource.DATABASE ? COLOR_OK : COLOR_PRIMARY;
    }
    /** 是否记录了营养素。三项全为 0 视为没有数据 */
    private hasMacros(): boolean {
        return this.record.protein > 0 || this.record.fat > 0 || this.record.carb > 0;
    }
    macro(label: string, grams: number, color: string, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 3 });
            Row.debugLine("entry/src/main/ets/components/RecordRow.ets(29:5)", "entry");
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 一个小色点代替图标，标明是哪一项
            Row.create();
            Row.debugLine("entry/src/main/ets/components/RecordRow.ets(31:7)", "entry");
            // 一个小色点代替图标，标明是哪一项
            Row.width(5);
            // 一个小色点代替图标，标明是哪一项
            Row.height(5);
            // 一个小色点代替图标，标明是哪一项
            Row.backgroundColor(color);
            // 一个小色点代替图标，标明是哪一项
            Row.borderRadius(3);
        }, Row);
        // 一个小色点代替图标，标明是哪一项
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(`${label} ${grams}g`);
            Text.debugLine("entry/src/main/ets/components/RecordRow.ets(36:7)", "entry");
            Text.fontSize(11);
            Text.fontColor(COLOR_TEXT_SUB);
        }, Text);
        Text.pop();
        Row.pop();
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 12 });
            Row.debugLine("entry/src/main/ets/components/RecordRow.ets(43:5)", "entry");
            Row.width('100%');
            Row.padding({ left: 12, right: 12, top: 10, bottom: 10 });
            Row.backgroundColor(COLOR_CARD);
            Row.borderRadius(RADIUS);
            Row.shadow(CARD_SHADOW);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 左侧：来源标识条
            Row.create();
            Row.debugLine("entry/src/main/ets/components/RecordRow.ets(45:7)", "entry");
            // 左侧：来源标识条
            Row.width(3);
            // 左侧：来源标识条
            Row.height(34);
            // 左侧：来源标识条
            Row.backgroundColor(this.sourceColor());
            // 左侧：来源标识条
            Row.borderRadius(2);
        }, Row);
        // 左侧：来源标识条
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 3 });
            Column.debugLine("entry/src/main/ets/components/RecordRow.ets(51:7)", "entry");
            Column.alignItems(HorizontalAlign.Start);
            Column.layoutWeight(1);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.record.name);
            Text.debugLine("entry/src/main/ets/components/RecordRow.ets(52:9)", "entry");
            Text.fontSize(16);
            Text.fontColor(COLOR_TEXT);
            Text.maxLines(1);
            Text.textOverflow({ overflow: TextOverflow.Ellipsis });
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 6 });
            Row.debugLine("entry/src/main/ets/components/RecordRow.ets(58:9)", "entry");
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(`${this.record.grams} g`);
            Text.debugLine("entry/src/main/ets/components/RecordRow.ets(59:11)", "entry");
            Text.fontSize(12);
            Text.fontColor(COLOR_TEXT_SUB);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('·');
            Text.debugLine("entry/src/main/ets/components/RecordRow.ets(63:11)", "entry");
            Text.fontSize(12);
            Text.fontColor(COLOR_DIVIDER);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(foodSourceLabel(this.record.source));
            Text.debugLine("entry/src/main/ets/components/RecordRow.ets(67:11)", "entry");
            Text.fontSize(12);
            Text.fontColor(this.sourceColor());
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('·');
            Text.debugLine("entry/src/main/ets/components/RecordRow.ets(71:11)", "entry");
            Text.fontSize(12);
            Text.fontColor(COLOR_DIVIDER);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(timeLabel(this.record.timestamp));
            Text.debugLine("entry/src/main/ets/components/RecordRow.ets(75:11)", "entry");
            Text.fontSize(12);
            Text.fontColor(COLOR_TEXT_SUB);
        }, Text);
        Text.pop();
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            // 三大营养素。旧记录没存过这些值，全为 0 时整行不显示，
            // 避免出现「蛋白 0g 脂肪 0g 碳水 0g」这种误导性的空数据。
            if (this.hasMacros()) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Row.create({ space: 8 });
                        Row.debugLine("entry/src/main/ets/components/RecordRow.ets(83:11)", "entry");
                    }, Row);
                    this.macro.bind(this)('蛋白', this.record.protein, COLOR_PROTEIN);
                    this.macro.bind(this)('脂肪', this.record.fat, COLOR_FAT);
                    this.macro.bind(this)('碳水', this.record.carb, COLOR_CARB);
                    Row.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(`${this.record.kcal}`);
            Text.debugLine("entry/src/main/ets/components/RecordRow.ets(93:7)", "entry");
            Text.fontSize(19);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(COLOR_TEXT);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('千卡');
            Text.debugLine("entry/src/main/ets/components/RecordRow.ets(98:7)", "entry");
            Text.fontSize(11);
            Text.fontColor(COLOR_TEXT_SUB);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 删除按钮：点击后再弹确认，避免误删
            Button.createWithChild({ type: ButtonType.Circle, stateEffect: true });
            Button.debugLine("entry/src/main/ets/components/RecordRow.ets(103:7)", "entry");
            // 删除按钮：点击后再弹确认，避免误删
            Button.width(28);
            // 删除按钮：点击后再弹确认，避免误删
            Button.height(28);
            // 删除按钮：点击后再弹确认，避免误删
            Button.backgroundColor(COLOR_DIVIDER);
            // 删除按钮：点击后再弹确认，避免误删
            Button.onClick(() => {
                this.onDelete(this.record.id);
            });
        }, Button);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('✕');
            Text.debugLine("entry/src/main/ets/components/RecordRow.ets(104:9)", "entry");
            Text.fontSize(13);
            Text.fontColor(COLOR_TEXT_SUB);
        }, Text);
        Text.pop();
        // 删除按钮：点击后再弹确认，避免误删
        Button.pop();
        Row.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
    public __resetStateVarsOnReuse__Internal(params: Object): void {
    }
}
