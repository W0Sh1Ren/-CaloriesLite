if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface CameraPage_Params {
    imageUris?: string[];
    notes?: string;
    busy?: boolean;
    statusText?: string;
    errorText?: string;
}
import router from "@ohos:router";
import type common from "@ohos:app.ability.common";
import hilog from "@ohos:hilog";
import type { AiConfig } from '../model/Types';
import { guessMealType } from "@normalized:N&&&entry/src/main/ets/model/Enums&";
import { hourOf } from "@normalized:N&&&entry/src/main/ets/common/DateUtil&";
import { SettingsRepo } from "@normalized:N&&&entry/src/main/ets/service/SettingsRepo&";
import { ImageService, ImageError } from "@normalized:N&&&entry/src/main/ets/service/ImageService&";
import type { PreparedImage } from "@normalized:N&&&entry/src/main/ets/service/ImageService&";
import { VisionService, VisionError } from "@normalized:N&&&entry/src/main/ets/service/VisionService&";
import type { VisionResult } from "@normalized:N&&&entry/src/main/ets/service/VisionService&";
import { PermissionUtil } from "@normalized:N&&&entry/src/main/ets/common/PermissionUtil&";
import { AppState, PendingResult } from "@normalized:N&&&entry/src/main/ets/common/AppState&";
import { CARD_SHADOW, COLOR_BG, COLOR_CARD, COLOR_DIVIDER, COLOR_PRIMARY, COLOR_TEXT, COLOR_TEXT_SUB, COLOR_WARN, GAP, PAGE_PAD, RADIUS } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
const DOMAIN = 0x0000;
/** 一次最多几张照片 */
const MAX_IMAGES: number = 4;
class CameraPage extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__imageUris = new ObservedPropertyObjectPU([], this, "imageUris");
        this.__notes = new ObservedPropertySimplePU('', this, "notes");
        this.__busy = new ObservedPropertySimplePU(false, this, "busy");
        this.__statusText = new ObservedPropertySimplePU('', this, "statusText");
        this.__errorText = new ObservedPropertySimplePU('', this, "errorText");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: CameraPage_Params) {
        if (params.imageUris !== undefined) {
            this.imageUris = params.imageUris;
        }
        if (params.notes !== undefined) {
            this.notes = params.notes;
        }
        if (params.busy !== undefined) {
            this.busy = params.busy;
        }
        if (params.statusText !== undefined) {
            this.statusText = params.statusText;
        }
        if (params.errorText !== undefined) {
            this.errorText = params.errorText;
        }
    }
    updateStateVars(params: CameraPage_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__imageUris.purgeDependencyOnElmtId(rmElmtId);
        this.__notes.purgeDependencyOnElmtId(rmElmtId);
        this.__busy.purgeDependencyOnElmtId(rmElmtId);
        this.__statusText.purgeDependencyOnElmtId(rmElmtId);
        this.__errorText.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__imageUris.aboutToBeDeleted();
        this.__notes.aboutToBeDeleted();
        this.__busy.aboutToBeDeleted();
        this.__statusText.aboutToBeDeleted();
        this.__errorText.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    /** 已选/已拍的图片 uri 列表，可多张 */
    private __imageUris: ObservedPropertyObjectPU<string[]>;
    get imageUris() {
        return this.__imageUris.get();
    }
    set imageUris(newValue: string[]) {
        this.__imageUris.set(newValue);
    }
    /** 用户手写的补充说明，会随请求发给模型 */
    private __notes: ObservedPropertySimplePU<string>;
    get notes() {
        return this.__notes.get();
    }
    set notes(newValue: string) {
        this.__notes.set(newValue);
    }
    private __busy: ObservedPropertySimplePU<boolean>;
    get busy() {
        return this.__busy.get();
    }
    set busy(newValue: boolean) {
        this.__busy.set(newValue);
    }
    private __statusText: ObservedPropertySimplePU<string>;
    get statusText() {
        return this.__statusText.get();
    }
    set statusText(newValue: string) {
        this.__statusText.set(newValue);
    }
    private __errorText: ObservedPropertySimplePU<string>;
    get errorText() {
        return this.__errorText.get();
    }
    set errorText(newValue: string) {
        this.__errorText.set(newValue);
    }
    private uiContext(): common.UIAbilityContext {
        return this.getUIContext().getHostContext() as common.UIAbilityContext;
    }
    /** 拍一张并追加到列表（支持连拍多张） */
    private async onTakePhoto(): Promise<void> {
        if (this.busy) {
            return;
        }
        if (this.imageUris.length >= MAX_IMAGES) {
            this.errorText = `最多 ${MAX_IMAGES} 张照片`;
            return;
        }
        this.errorText = '';
        try {
            await PermissionUtil.ensureCamera(this.uiContext());
            const uri: string = await ImageService.takePhoto(this.uiContext());
            if (uri.length === 0) {
                return; // 用户取消
            }
            this.addImage(uri);
        }
        catch (err) {
            this.handleError(err);
        }
    }
    /** 从相册选图，可一次选多张 */
    private async onPickGallery(): Promise<void> {
        if (this.busy) {
            return;
        }
        this.errorText = '';
        try {
            await PermissionUtil.ensurePhotoRead(this.uiContext());
            const remaining: number = MAX_IMAGES - this.imageUris.length;
            if (remaining <= 0) {
                this.errorText = `最多 ${MAX_IMAGES} 张照片`;
                return;
            }
            const uris: string[] = await ImageService.pickFromGallery(remaining);
            if (uris.length === 0) {
                return; // 用户取消
            }
            for (const u of uris) {
                this.addImage(u);
            }
        }
        catch (err) {
            this.handleError(err);
        }
    }
    /** 追加一张图，去重 */
    private addImage(uri: string): void {
        if (this.imageUris.includes(uri)) {
            return;
        }
        const next: string[] = this.imageUris.slice();
        next.push(uri);
        this.imageUris = next;
        this.errorText = '';
    }
    /** 移除一张 */
    private removeImage(index: number): void {
        const next: string[] = [];
        for (let i = 0; i < this.imageUris.length; i++) {
            if (i !== index) {
                next.push(this.imageUris[i]);
            }
        }
        this.imageUris = next;
    }
    /** 压缩全部图片并发起识别 */
    private async analyze(): Promise<void> {
        if (this.imageUris.length === 0) {
            this.errorText = '先拍一张或选一张照片';
            return;
        }
        this.busy = true;
        this.errorText = '';
        try {
            const config: AiConfig = SettingsRepo.loadAiConfig();
            VisionService.validate(config);
            const ctx: common.UIAbilityContext = this.uiContext();
            const bases: string[] = [];
            const localUris: string[] = [];
            for (let i = 0; i < this.imageUris.length; i++) {
                this.statusText = this.imageUris.length > 1
                    ? `正在压缩第 ${i + 1}/${this.imageUris.length} 张…`
                    : '正在压缩图片…';
                const prepared: PreparedImage = await ImageService.prepare(this.imageUris[i], ctx);
                bases.push(prepared.base64);
                localUris.push(prepared.localUri.length > 0 ? prepared.localUri : this.imageUris[i]);
            }
            this.statusText = `正在用 ${config.model} 识别…`;
            // 多张图一次发过去，热量与三大营养素同一次返回
            const result: VisionResult = await VisionService.recognize(config, bases, this.notes);
            AppState.pending = new PendingResult(localUris, result.drafts, result.overallNote, result.model, this.notes.trim());
            AppState.needRefreshHome = true;
            AppState.targetMeal = guessMealType(hourOf(Date.now()));
            router.pushUrl({ url: 'pages/ResultConfirm' });
        }
        catch (err) {
            this.handleError(err);
        }
        finally {
            this.busy = false;
            this.statusText = '';
        }
    }
    private handleError(err: Object): void {
        let msg: string = '出了点问题，再试一次';
        if (err instanceof VisionError) {
            msg = (err as VisionError).message;
        }
        else if (err instanceof ImageError) {
            msg = (err as ImageError).message;
        }
        else {
            const e: Error = err as Error;
            msg = e.message.length > 0 ? e.message : msg;
        }
        this.errorText = msg;
        hilog.error(DOMAIN, 'CalorieLite', 'camera page error: %{public}s', msg);
    }
    private goAiSettings(): void {
        router.pushUrl({ url: 'pages/AiSettings' });
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.debugLine("entry/src/main/ets/pages/Camera.ets(176:5)", "entry");
            Column.width('100%');
            Column.height('100%');
            Column.backgroundColor(COLOR_BG);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 顶部栏
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/Camera.ets(178:7)", "entry");
            // 顶部栏
            Row.width('100%');
            // 顶部栏
            Row.padding({ left: PAGE_PAD, right: PAGE_PAD, top: 8, bottom: 8 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithChild({ type: ButtonType.Circle });
            Button.debugLine("entry/src/main/ets/pages/Camera.ets(179:9)", "entry");
            Button.width(36);
            Button.height(36);
            Button.backgroundColor(COLOR_CARD);
            Button.onClick(() => {
                router.back();
            });
        }, Button);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('‹');
            Text.debugLine("entry/src/main/ets/pages/Camera.ets(180:11)", "entry");
            Text.fontSize(22);
            Text.fontColor(COLOR_TEXT);
        }, Text);
        Text.pop();
        Button.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('拍照识别');
            Text.debugLine("entry/src/main/ets/pages/Camera.ets(187:9)", "entry");
            Text.fontSize(17);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(COLOR_TEXT);
            Text.layoutWeight(1);
            Text.textAlign(TextAlign.Center);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 占位，保持标题居中
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/Camera.ets(195:9)", "entry");
            // 占位，保持标题居中
            Row.width(36);
            // 占位，保持标题居中
            Row.height(36);
        }, Row);
        // 占位，保持标题居中
        Row.pop();
        // 顶部栏
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Scroll.create();
            Scroll.debugLine("entry/src/main/ets/pages/Camera.ets(200:7)", "entry");
            Scroll.layoutWeight(1);
            Scroll.scrollBar(BarState.Off);
            Scroll.align(Alignment.Top);
        }, Scroll);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: GAP });
            Column.debugLine("entry/src/main/ets/pages/Camera.ets(201:9)", "entry");
            Column.width('100%');
            Column.padding({ left: PAGE_PAD, right: PAGE_PAD, top: 8, bottom: 16 });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            // ------------------------------------------------ 图片区
            if (this.imageUris.length === 0) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create({ space: 8 });
                        Column.debugLine("entry/src/main/ets/pages/Camera.ets(204:13)", "entry");
                        Column.width('100%');
                        Column.height(200);
                        Column.justifyContent(FlexAlign.Center);
                        Column.backgroundColor(COLOR_CARD);
                        Column.borderRadius(RADIUS);
                        Column.shadow(CARD_SHADOW);
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('📷');
                        Text.debugLine("entry/src/main/ets/pages/Camera.ets(205:15)", "entry");
                        Text.fontSize(44);
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(`拍一张或从相册选几张，最多 ${MAX_IMAGES} 张`);
                        Text.debugLine("entry/src/main/ets/pages/Camera.ets(207:15)", "entry");
                        Text.fontSize(13);
                        Text.fontColor(COLOR_TEXT_SUB);
                        Text.textAlign(TextAlign.Center);
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('同一餐的多张照片一起发送，模型会合并判断，比逐张识别更准');
                        Text.debugLine("entry/src/main/ets/pages/Camera.ets(211:15)", "entry");
                        Text.fontSize(11);
                        Text.fontColor(COLOR_TEXT_SUB);
                        Text.textAlign(TextAlign.Center);
                    }, Text);
                    Text.pop();
                    Column.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        // 缩略图横向排列，每张右上角带删除
                        Scroll.create();
                        Scroll.debugLine("entry/src/main/ets/pages/Camera.ets(224:13)", "entry");
                        // 缩略图横向排列，每张右上角带删除
                        Scroll.scrollable(ScrollDirection.Horizontal);
                        // 缩略图横向排列，每张右上角带删除
                        Scroll.scrollBar(BarState.Off);
                        // 缩略图横向排列，每张右上角带删除
                        Scroll.width('100%');
                    }, Scroll);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Row.create({ space: 10 });
                        Row.debugLine("entry/src/main/ets/pages/Camera.ets(225:15)", "entry");
                        Row.padding({ right: 4 });
                    }, Row);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        ForEach.create();
                        const forEachItemGenFunction = (_item, index: number) => {
                            const uri = _item;
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Stack.create({ alignContent: Alignment.TopEnd });
                                Stack.debugLine("entry/src/main/ets/pages/Camera.ets(227:19)", "entry");
                                Stack.width(150);
                                Stack.height(150);
                            }, Stack);
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Image.create(uri);
                                Image.debugLine("entry/src/main/ets/pages/Camera.ets(228:21)", "entry");
                                Image.width(150);
                                Image.height(150);
                                Image.objectFit(ImageFit.Cover);
                                Image.borderRadius(14);
                            }, Image);
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Button.createWithChild({ type: ButtonType.Circle });
                                Button.debugLine("entry/src/main/ets/pages/Camera.ets(234:21)", "entry");
                                Button.width(24);
                                Button.height(24);
                                Button.backgroundColor('#99000000');
                                Button.margin({ top: 6, right: 6 });
                                Button.onClick(() => {
                                    this.removeImage(index);
                                });
                            }, Button);
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Text.create('✕');
                                Text.debugLine("entry/src/main/ets/pages/Camera.ets(235:23)", "entry");
                                Text.fontSize(12);
                                Text.fontColor(Color.White);
                            }, Text);
                            Text.pop();
                            Button.pop();
                            Stack.pop();
                        };
                        this.forEachUpdateFunction(elmtId, this.imageUris, forEachItemGenFunction, (uri: string, index: number) => `${index}-${uri}`, true, true);
                    }, ForEach);
                    ForEach.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        If.create();
                        // 末尾的「再加一张」入口
                        if (this.imageUris.length < MAX_IMAGES) {
                            this.ifElseBranchUpdateFunction(0, () => {
                                this.observeComponentCreation2((elmtId, isInitialRender) => {
                                    Column.create({ space: 4 });
                                    Column.debugLine("entry/src/main/ets/pages/Camera.ets(251:19)", "entry");
                                    Column.width(150);
                                    Column.height(150);
                                    Column.justifyContent(FlexAlign.Center);
                                    Column.backgroundColor(COLOR_CARD);
                                    Column.borderRadius(14);
                                    Column.border({ width: 1, color: COLOR_DIVIDER, style: BorderStyle.Dashed });
                                    Column.onClick(() => {
                                        this.onPickGallery();
                                    });
                                }, Column);
                                this.observeComponentCreation2((elmtId, isInitialRender) => {
                                    Text.create('+');
                                    Text.debugLine("entry/src/main/ets/pages/Camera.ets(252:21)", "entry");
                                    Text.fontSize(28);
                                    Text.fontColor(COLOR_TEXT_SUB);
                                }, Text);
                                Text.pop();
                                this.observeComponentCreation2((elmtId, isInitialRender) => {
                                    Text.create('再加一张');
                                    Text.debugLine("entry/src/main/ets/pages/Camera.ets(253:21)", "entry");
                                    Text.fontSize(11);
                                    Text.fontColor(COLOR_TEXT_SUB);
                                }, Text);
                                Text.pop();
                                Column.pop();
                            });
                        }
                        else {
                            this.ifElseBranchUpdateFunction(1, () => {
                            });
                        }
                    }, If);
                    If.pop();
                    Row.pop();
                    // 缩略图横向排列，每张右上角带删除
                    Scroll.pop();
                });
            }
        }, If);
        If.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // ------------------------------------------------ 补充说明
            Column.create({ space: 6 });
            Column.debugLine("entry/src/main/ets/pages/Camera.ets(274:11)", "entry");
            // ------------------------------------------------ 补充说明
            Column.width('100%');
            // ------------------------------------------------ 补充说明
            Column.padding(14);
            // ------------------------------------------------ 补充说明
            Column.backgroundColor(COLOR_CARD);
            // ------------------------------------------------ 补充说明
            Column.borderRadius(RADIUS);
            // ------------------------------------------------ 补充说明
            Column.shadow(CARD_SHADOW);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/Camera.ets(275:13)", "entry");
            Row.width('100%');
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('补充说明');
            Text.debugLine("entry/src/main/ets/pages/Camera.ets(276:15)", "entry");
            Text.fontSize(13);
            Text.fontColor(COLOR_TEXT_SUB);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
            Blank.debugLine("entry/src/main/ets/pages/Camera.ets(279:15)", "entry");
        }, Blank);
        Blank.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(`${this.notes.length}/100`);
            Text.debugLine("entry/src/main/ets/pages/Camera.ets(280:15)", "entry");
            Text.fontSize(11);
            Text.fontColor(COLOR_TEXT_SUB);
        }, Text);
        Text.pop();
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            TextArea.create({
                text: this.notes,
                placeholder: '可选。例如「这碗面只吃了一半」「米饭是小半碗」，模型会据此调整份量'
            });
            TextArea.debugLine("entry/src/main/ets/pages/Camera.ets(286:13)", "entry");
            TextArea.fontSize(14);
            TextArea.height(80);
            TextArea.width('100%');
            TextArea.backgroundColor(COLOR_BG);
            TextArea.borderRadius(10);
            TextArea.maxLength(100);
            TextArea.onChange((v: string) => {
                this.notes = v;
            });
        }, TextArea);
        // ------------------------------------------------ 补充说明
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            // 错误提示
            if (this.errorText.length > 0) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Row.create({ space: 8 });
                        Row.debugLine("entry/src/main/ets/pages/Camera.ets(308:13)", "entry");
                        Row.width('100%');
                        Row.padding(12);
                        Row.backgroundColor('#FFF1EF');
                        Row.borderRadius(10);
                    }, Row);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('!');
                        Text.debugLine("entry/src/main/ets/pages/Camera.ets(309:15)", "entry");
                        Text.fontSize(14);
                        Text.fontColor(COLOR_WARN);
                        Text.fontWeight(FontWeight.Bold);
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(this.errorText);
                        Text.debugLine("entry/src/main/ets/pages/Camera.ets(313:15)", "entry");
                        Text.fontSize(13);
                        Text.fontColor(COLOR_WARN);
                        Text.layoutWeight(1);
                    }, Text);
                    Text.pop();
                    Row.pop();
                });
            }
            // 忙碌状态
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            // 忙碌状态
            if (this.busy) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Row.create({ space: 10 });
                        Row.debugLine("entry/src/main/ets/pages/Camera.ets(326:13)", "entry");
                        Row.width('100%');
                        Row.padding(14);
                        Row.backgroundColor(COLOR_CARD);
                        Row.borderRadius(RADIUS);
                    }, Row);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        LoadingProgress.create();
                        LoadingProgress.debugLine("entry/src/main/ets/pages/Camera.ets(327:15)", "entry");
                        LoadingProgress.width(22);
                        LoadingProgress.height(22);
                        LoadingProgress.color(COLOR_PRIMARY);
                    }, LoadingProgress);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(this.statusText);
                        Text.debugLine("entry/src/main/ets/pages/Camera.ets(331:15)", "entry");
                        Text.fontSize(13);
                        Text.fontColor(COLOR_TEXT_SUB);
                        Text.layoutWeight(1);
                    }, Text);
                    Text.pop();
                    Row.pop();
                });
            }
            // ------------------------------------------------ 操作
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // ------------------------------------------------ 操作
            Row.create({ space: 10 });
            Row.debugLine("entry/src/main/ets/pages/Camera.ets(343:11)", "entry");
            // ------------------------------------------------ 操作
            Row.width('100%');
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithChild({ type: ButtonType.Capsule });
            Button.debugLine("entry/src/main/ets/pages/Camera.ets(344:13)", "entry");
            Button.layoutWeight(1);
            Button.height(48);
            Button.backgroundColor(COLOR_CARD);
            Button.enabled(!this.busy);
            Button.onClick(() => {
                this.onTakePhoto();
            });
        }, Button);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('拍照');
            Text.debugLine("entry/src/main/ets/pages/Camera.ets(345:15)", "entry");
            Text.fontSize(16);
            Text.fontColor(COLOR_TEXT);
        }, Text);
        Text.pop();
        Button.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithChild({ type: ButtonType.Capsule });
            Button.debugLine("entry/src/main/ets/pages/Camera.ets(355:13)", "entry");
            Button.layoutWeight(1);
            Button.height(48);
            Button.backgroundColor(COLOR_CARD);
            Button.enabled(!this.busy);
            Button.onClick(() => {
                this.onPickGallery();
            });
        }, Button);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('相册');
            Text.debugLine("entry/src/main/ets/pages/Camera.ets(356:15)", "entry");
            Text.fontSize(16);
            Text.fontColor(COLOR_TEXT);
        }, Text);
        Text.pop();
        Button.pop();
        // ------------------------------------------------ 操作
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 主操作：开始识别
            Button.createWithChild({ type: ButtonType.Capsule });
            Button.debugLine("entry/src/main/ets/pages/Camera.ets(369:11)", "entry");
            // 主操作：开始识别
            Button.width('100%');
            // 主操作：开始识别
            Button.height(50);
            // 主操作：开始识别
            Button.backgroundColor(COLOR_PRIMARY);
            // 主操作：开始识别
            Button.enabled(!this.busy && this.imageUris.length > 0);
            // 主操作：开始识别
            Button.opacity(!this.busy && this.imageUris.length > 0 ? 1 : 0.5);
            // 主操作：开始识别
            Button.onClick(() => {
                this.analyze();
            });
        }, Button);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.busy ? '识别中…' : '开始识别');
            Text.debugLine("entry/src/main/ets/pages/Camera.ets(370:13)", "entry");
            Text.fontSize(16);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(Color.White);
        }, Text);
        Text.pop();
        // 主操作：开始识别
        Button.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            // 配置提示
            if (!SettingsRepo.isAiReady()) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create({ space: 8 });
                        Column.debugLine("entry/src/main/ets/pages/Camera.ets(386:13)", "entry");
                        Column.width('100%');
                        Column.padding(16);
                        Column.backgroundColor(COLOR_CARD);
                        Column.borderRadius(RADIUS);
                        Column.alignItems(HorizontalAlign.Start);
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('识别功能还没配置');
                        Text.debugLine("entry/src/main/ets/pages/Camera.ets(387:15)", "entry");
                        Text.fontSize(14);
                        Text.fontColor(COLOR_TEXT);
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('需要填入你自己的 AI 接口地址、API Key 和模型名才能识别');
                        Text.debugLine("entry/src/main/ets/pages/Camera.ets(390:15)", "entry");
                        Text.fontSize(12);
                        Text.fontColor(COLOR_TEXT_SUB);
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Button.createWithChild({ type: ButtonType.Capsule });
                        Button.debugLine("entry/src/main/ets/pages/Camera.ets(393:15)", "entry");
                        Button.height(38);
                        Button.backgroundColor(COLOR_PRIMARY);
                        Button.onClick(() => {
                            this.goAiSettings();
                        });
                    }, Button);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('去配置');
                        Text.debugLine("entry/src/main/ets/pages/Camera.ets(394:17)", "entry");
                        Text.fontSize(14);
                        Text.fontColor(Color.White);
                    }, Text);
                    Text.pop();
                    Button.pop();
                    Column.pop();
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Column.create({ space: 6 });
                        Column.debugLine("entry/src/main/ets/pages/Camera.ets(408:13)", "entry");
                        Column.width('100%');
                    }, Column);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(`当前模型：${SettingsRepo.loadAiConfig().model}`);
                        Text.debugLine("entry/src/main/ets/pages/Camera.ets(409:15)", "entry");
                        Text.fontSize(12);
                        Text.fontColor(COLOR_TEXT_SUB);
                        Text.width('100%');
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create('照片只会在本机压缩后发送到 DeepSeek');
                        Text.debugLine("entry/src/main/ets/pages/Camera.ets(413:15)", "entry");
                        Text.fontSize(12);
                        Text.fontColor(COLOR_TEXT_SUB);
                        Text.width('100%');
                    }, Text);
                    Text.pop();
                    Column.pop();
                });
            }
        }, If);
        If.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/Camera.ets(421:11)", "entry");
            Row.height(16);
        }, Row);
        Row.pop();
        Column.pop();
        Scroll.pop();
        Column.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
    public __resetStateVarsOnReuse__Internal(params: Object): void {
    }
    static getEntryName(): string {
        return "CameraPage";
    }
}
registerNamedRoute(() => new CameraPage(undefined, {}), "", { bundleName: "Calories.Lite.Test", moduleName: "entry", pagePath: "pages/Camera", pageFullPath: "entry/src/main/ets/pages/Camera", integratedHsp: "false", moduleType: "followWithHap" });
