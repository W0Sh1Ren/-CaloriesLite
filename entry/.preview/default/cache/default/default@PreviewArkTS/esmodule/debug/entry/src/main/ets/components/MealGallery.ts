if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface MealGallery_Params {
    images?: string[];
    frameHeight?: number;
    index?: number;
}
import { RADIUS } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
export class MealGallery extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__images = new SynchedPropertyObjectOneWayPU(params.images, this, "images");
        this.__frameHeight = new SynchedPropertySimpleOneWayPU(params.frameHeight, this, "frameHeight");
        this.__index = new ObservedPropertySimplePU(0, this, "index");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: MealGallery_Params) {
        if (params.images === undefined) {
            this.__images.set([]);
        }
        if (params.frameHeight === undefined) {
            this.__frameHeight.set(190);
        }
        if (params.index !== undefined) {
            this.index = params.index;
        }
    }
    updateStateVars(params: MealGallery_Params) {
        this.__images.reset(params.images);
        this.__frameHeight.reset(params.frameHeight);
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__images.purgeDependencyOnElmtId(rmElmtId);
        this.__frameHeight.purgeDependencyOnElmtId(rmElmtId);
        this.__index.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__images.aboutToBeDeleted();
        this.__frameHeight.aboutToBeDeleted();
        this.__index.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    /** 这一餐的全部图片（调用方需保证已去重） */
    private __images: SynchedPropertySimpleOneWayPU<string[]>;
    get images() {
        return this.__images.get();
    }
    set images(newValue: string[]) {
        this.__images.set(newValue);
    }
    /** 预览框高度 */
    private __frameHeight: SynchedPropertySimpleOneWayPU<number>;
    get frameHeight() {
        return this.__frameHeight.get();
    }
    set frameHeight(newValue: number) {
        this.__frameHeight.set(newValue);
    }
    /** Swiper 当前页，用于右下角页码 */
    private __index: ObservedPropertySimplePU<number>;
    get index() {
        return this.__index.get();
    }
    set index(newValue: number) {
        this.__index.set(newValue);
    }
    frame(uri: string, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Image.create(uri);
            Image.debugLine("entry/src/main/ets/components/MealGallery.ets(26:5)", "entry");
            Image.width('100%');
            Image.height('100%');
            Image.objectFit(ImageFit.Cover);
            Image.draggable(false);
        }, Image);
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create({ alignContent: Alignment.BottomEnd });
            Stack.debugLine("entry/src/main/ets/components/MealGallery.ets(34:5)", "entry");
            Stack.width('100%');
            Stack.height(this.frameHeight);
            Stack.borderRadius(RADIUS);
            Stack.clip(true);
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.images.length === 0) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        // 没图时给一个等高的浅色占位，卡片高度才稳定
                        Column.create();
                        Column.debugLine("entry/src/main/ets/components/MealGallery.ets(37:9)", "entry");
                        // 没图时给一个等高的浅色占位，卡片高度才稳定
                        Column.width('100%');
                        // 没图时给一个等高的浅色占位，卡片高度才稳定
                        Column.height(this.frameHeight);
                        // 没图时给一个等高的浅色占位，卡片高度才稳定
                        Column.justifyContent(FlexAlign.Center);
                        // 没图时给一个等高的浅色占位，卡片高度才稳定
                        Column.backgroundColor('#F1F3F5');
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('🍽');
                        Text.debugLine("entry/src/main/ets/components/MealGallery.ets(38:11)", "entry");
                        Text.fontSize(28);
                    }, Text);
                    Text.pop();
                    // 没图时给一个等高的浅色占位，卡片高度才稳定
                    Column.pop();
                });
            }
            else if (this.images.length === 1) {
                this.ifElseBranchUpdateFunction(1, () => {
                    this.frame.bind(this)(this.images[0]);
                });
            }
            else {
                this.ifElseBranchUpdateFunction(2, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Swiper.create();
                        Swiper.debugLine("entry/src/main/ets/components/MealGallery.ets(48:9)", "entry");
                        Swiper.width('100%');
                        Swiper.height(this.frameHeight);
                        Swiper.loop(false);
                        Swiper.indicator(false);
                        Swiper.onChange((i: number) => {
                            this.index = i;
                        });
                    }, Swiper);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        ForEach.create();
                        const forEachItemGenFunction = (_item, idx: number) => {
                            const uri = _item;
                            this.frame.bind(this)(uri);
                        };
                        this.forEachUpdateFunction(elmtId, this.images, forEachItemGenFunction, (uri: string, idx: number) => `${idx}-${uri}`, true, true);
                    }, ForEach);
                    ForEach.pop();
                    Swiper.pop();
                });
            }
        }, If);
        If.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.images.length > 1) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(`${this.index + 1} / ${this.images.length}`);
                        Text.debugLine("entry/src/main/ets/components/MealGallery.ets(64:9)", "entry");
                        Text.fontSize(11);
                        Text.fontColor('#FFFFFF');
                        Text.padding({ left: 8, right: 8, top: 3, bottom: 3 });
                        Text.backgroundColor('#66000000');
                        Text.borderRadius(9);
                        Text.margin({ right: 10, bottom: 10 });
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
        Stack.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
    public __resetStateVarsOnReuse__Internal(params: Object): void {
    }
}
