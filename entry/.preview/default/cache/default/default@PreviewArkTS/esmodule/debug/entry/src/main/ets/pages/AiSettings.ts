if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface AiSettings_Params {
    baseUrl?: string;
    apiKey?: string;
    model?: string;
    thinking?: boolean;
    showKey?: boolean;
    testing?: boolean;
    testResult?: string;
    testOk?: boolean;
}
import router from "@ohos:router";
import promptAction from "@ohos:promptAction";
import hilog from "@ohos:hilog";
import { AiConfig, AiProvider } from "@normalized:N&&&entry/src/main/ets/model/Types&";
import { AI_BASE_URL, AI_MODEL, PRESETS } from "@normalized:N&&&entry/src/main/ets/model/Enums&";
import type { ProviderPreset } from "@normalized:N&&&entry/src/main/ets/model/Enums&";
import { SettingsRepo } from "@normalized:N&&&entry/src/main/ets/service/SettingsRepo&";
import { VisionService, VisionError } from "@normalized:N&&&entry/src/main/ets/service/VisionService&";
import { CARD_SHADOW, COLOR_BG, COLOR_CARD, COLOR_DIVIDER, COLOR_OK, COLOR_PRIMARY, COLOR_TEXT, COLOR_TEXT_SUB, COLOR_WARN, GAP, PAGE_PAD, RADIUS } from "@normalized:N&&&entry/src/main/ets/common/Theme&";
const DOMAIN = 0x0000;
class AiSettings extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__baseUrl = new ObservedPropertySimplePU(AI_BASE_URL, this, "baseUrl");
        this.__apiKey = new ObservedPropertySimplePU('', this, "apiKey");
        this.__model = new ObservedPropertySimplePU(AI_MODEL, this, "model");
        this.__thinking = new ObservedPropertySimplePU(false, this, "thinking");
        this.__showKey = new ObservedPropertySimplePU(false, this, "showKey");
        this.__testing = new ObservedPropertySimplePU(false, this, "testing");
        this.__testResult = new ObservedPropertySimplePU('', this, "testResult");
        this.__testOk = new ObservedPropertySimplePU(false, this, "testOk");
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: AiSettings_Params) {
        if (params.baseUrl !== undefined) {
            this.baseUrl = params.baseUrl;
        }
        if (params.apiKey !== undefined) {
            this.apiKey = params.apiKey;
        }
        if (params.model !== undefined) {
            this.model = params.model;
        }
        if (params.thinking !== undefined) {
            this.thinking = params.thinking;
        }
        if (params.showKey !== undefined) {
            this.showKey = params.showKey;
        }
        if (params.testing !== undefined) {
            this.testing = params.testing;
        }
        if (params.testResult !== undefined) {
            this.testResult = params.testResult;
        }
        if (params.testOk !== undefined) {
            this.testOk = params.testOk;
        }
    }
    updateStateVars(params: AiSettings_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__baseUrl.purgeDependencyOnElmtId(rmElmtId);
        this.__apiKey.purgeDependencyOnElmtId(rmElmtId);
        this.__model.purgeDependencyOnElmtId(rmElmtId);
        this.__thinking.purgeDependencyOnElmtId(rmElmtId);
        this.__showKey.purgeDependencyOnElmtId(rmElmtId);
        this.__testing.purgeDependencyOnElmtId(rmElmtId);
        this.__testResult.purgeDependencyOnElmtId(rmElmtId);
        this.__testOk.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__baseUrl.aboutToBeDeleted();
        this.__apiKey.aboutToBeDeleted();
        this.__model.aboutToBeDeleted();
        this.__thinking.aboutToBeDeleted();
        this.__showKey.aboutToBeDeleted();
        this.__testing.aboutToBeDeleted();
        this.__testResult.aboutToBeDeleted();
        this.__testOk.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    /** 固定走 OpenAI 兼容协议，不需要用户选 */
    private __baseUrl: ObservedPropertySimplePU<string>;
    get baseUrl() {
        return this.__baseUrl.get();
    }
    set baseUrl(newValue: string) {
        this.__baseUrl.set(newValue);
    }
    private __apiKey: ObservedPropertySimplePU<string>;
    get apiKey() {
        return this.__apiKey.get();
    }
    set apiKey(newValue: string) {
        this.__apiKey.set(newValue);
    }
    private __model: ObservedPropertySimplePU<string>;
    get model() {
        return this.__model.get();
    }
    set model(newValue: string) {
        this.__model.set(newValue);
    }
    /** 思考模式，默认关；开了更准但更贵更慢 */
    private __thinking: ObservedPropertySimplePU<boolean>;
    get thinking() {
        return this.__thinking.get();
    }
    set thinking(newValue: boolean) {
        this.__thinking.set(newValue);
    }
    private __showKey: ObservedPropertySimplePU<boolean>;
    get showKey() {
        return this.__showKey.get();
    }
    set showKey(newValue: boolean) {
        this.__showKey.set(newValue);
    }
    private __testing: ObservedPropertySimplePU<boolean>;
    get testing() {
        return this.__testing.get();
    }
    set testing(newValue: boolean) {
        this.__testing.set(newValue);
    }
    private __testResult: ObservedPropertySimplePU<string>;
    get testResult() {
        return this.__testResult.get();
    }
    set testResult(newValue: string) {
        this.__testResult.set(newValue);
    }
    private __testOk: ObservedPropertySimplePU<boolean>;
    get testOk() {
        return this.__testOk.get();
    }
    set testOk(newValue: boolean) {
        this.__testOk.set(newValue);
    }
    aboutToAppear(): void {
        const c: AiConfig = SettingsRepo.loadAiConfig();
        this.baseUrl = c.baseUrl.length > 0 ? c.baseUrl : AI_BASE_URL;
        this.apiKey = c.apiKey;
        this.model = c.model.length > 0 ? c.model : AI_MODEL;
        this.thinking = c.thinking;
    }
    private current(): AiConfig {
        return new AiConfig(AiProvider.OPENAI_COMPATIBLE, this.baseUrl.trim(), this.apiKey.trim(), this.model.trim(), this.thinking);
    }
    private applyPreset(p: ProviderPreset): void {
        this.baseUrl = p.baseUrl;
        this.model = p.model;
        this.testResult = '';
    }
    /** 先存再测，这样测试用的就是用户眼前这份配置 */
    private async test(): Promise<void> {
        if (this.testing) {
            return;
        }
        this.testing = true;
        this.testResult = '';
        const config: AiConfig = this.current();
        SettingsRepo.saveAiConfig(config);
        try {
            const reply: string = await VisionService.testConnection(config);
            this.testOk = true;
            this.testResult = `连接成功，模型回复：${reply}`;
        }
        catch (err) {
            this.testOk = false;
            if (err instanceof VisionError) {
                this.testResult = (err as VisionError).message;
            }
            else {
                const e: Error = err as Error;
                this.testResult = e.message.length > 0 ? e.message : '测试失败';
            }
            hilog.error(DOMAIN, 'CalorieLite', 'ai test failed');
        }
        finally {
            this.testing = false;
        }
    }
    private save(): void {
        SettingsRepo.saveAiConfig(this.current());
        promptAction.showToast({ message: '已保存' });
        router.back();
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.debugLine("entry/src/main/ets/pages/AiSettings.ets(85:5)", "entry");
            Column.width('100%');
            Column.height('100%');
            Column.backgroundColor(COLOR_BG);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 顶部栏
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/AiSettings.ets(87:7)", "entry");
            // 顶部栏
            Row.width('100%');
            // 顶部栏
            Row.padding({ left: PAGE_PAD, right: PAGE_PAD, top: 8, bottom: 8 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithChild({ type: ButtonType.Circle });
            Button.debugLine("entry/src/main/ets/pages/AiSettings.ets(88:9)", "entry");
            Button.width(36);
            Button.height(36);
            Button.backgroundColor(COLOR_CARD);
            Button.onClick(() => {
                router.back();
            });
        }, Button);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('‹');
            Text.debugLine("entry/src/main/ets/pages/AiSettings.ets(89:11)", "entry");
            Text.fontSize(22);
            Text.fontColor(COLOR_TEXT);
        }, Text);
        Text.pop();
        Button.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('AI 识别配置');
            Text.debugLine("entry/src/main/ets/pages/AiSettings.ets(96:9)", "entry");
            Text.fontSize(17);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(COLOR_TEXT);
            Text.layoutWeight(1);
            Text.textAlign(TextAlign.Center);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/AiSettings.ets(103:9)", "entry");
            Row.width(36);
            Row.height(36);
        }, Row);
        Row.pop();
        // 顶部栏
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Scroll.create();
            Scroll.debugLine("entry/src/main/ets/pages/AiSettings.ets(108:7)", "entry");
            Scroll.layoutWeight(1);
            Scroll.scrollBar(BarState.Off);
            Scroll.align(Alignment.Top);
        }, Scroll);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: GAP });
            Column.debugLine("entry/src/main/ets/pages/AiSettings.ets(109:9)", "entry");
            Column.width('100%');
            Column.padding({ left: PAGE_PAD, right: PAGE_PAD, top: 8, bottom: 16 });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 说明
            Column.create({ space: 6 });
            Column.debugLine("entry/src/main/ets/pages/AiSettings.ets(111:11)", "entry");
            // 说明
            Column.width('100%');
            // 说明
            Column.padding(16);
            // 说明
            Column.backgroundColor(COLOR_CARD);
            // 说明
            Column.borderRadius(RADIUS);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('这个应用不卖会员，也不代管额度');
            Text.debugLine("entry/src/main/ets/pages/AiSettings.ets(112:13)", "entry");
            Text.fontSize(14);
            Text.fontWeight(FontWeight.Medium);
            Text.fontColor(COLOR_TEXT);
            Text.width('100%');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('拍照识别用的是你自己的 DeepSeek API Key。下面填的信息只保存本机，识别时由手机直连 DeepSeek，不经过任何中间服务器。');
            Text.debugLine("entry/src/main/ets/pages/AiSettings.ets(117:13)", "entry");
            Text.fontSize(12);
            Text.fontColor(COLOR_TEXT_SUB);
            Text.width('100%');
        }, Text);
        Text.pop();
        // 说明
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 接口类型：固定走 OpenAI 兼容协议，不再让用户选
            Column.create({ space: 6 });
            Column.debugLine("entry/src/main/ets/pages/AiSettings.ets(128:11)", "entry");
            // 接口类型：固定走 OpenAI 兼容协议，不再让用户选
            Column.width('100%');
            // 接口类型：固定走 OpenAI 兼容协议，不再让用户选
            Column.padding(16);
            // 接口类型：固定走 OpenAI 兼容协议，不再让用户选
            Column.backgroundColor(COLOR_CARD);
            // 接口类型：固定走 OpenAI 兼容协议，不再让用户选
            Column.borderRadius(RADIUS);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('接口协议');
            Text.debugLine("entry/src/main/ets/pages/AiSettings.ets(129:13)", "entry");
            Text.fontSize(13);
            Text.fontColor(COLOR_TEXT_SUB);
            Text.width('100%');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('OpenAI 兼容（DeepSeek）');
            Text.debugLine("entry/src/main/ets/pages/AiSettings.ets(133:13)", "entry");
            Text.fontSize(14);
            Text.fontColor(COLOR_TEXT);
            Text.width('100%');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('请求发往 DeepSeek 的 /chat/completions 接口，API Key 只保存在本机。');
            Text.debugLine("entry/src/main/ets/pages/AiSettings.ets(137:13)", "entry");
            Text.fontSize(11);
            Text.fontColor(COLOR_TEXT_SUB);
            Text.width('100%');
        }, Text);
        Text.pop();
        // 接口类型：固定走 OpenAI 兼容协议，不再让用户选
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 服务商信息（当前只支持 DeepSeek）
            Column.create({ space: 10 });
            Column.debugLine("entry/src/main/ets/pages/AiSettings.ets(148:11)", "entry");
            // 服务商信息（当前只支持 DeepSeek）
            Column.width('100%');
            // 服务商信息（当前只支持 DeepSeek）
            Column.padding(16);
            // 服务商信息（当前只支持 DeepSeek）
            Column.backgroundColor(COLOR_CARD);
            // 服务商信息（当前只支持 DeepSeek）
            Column.borderRadius(RADIUS);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('服务商');
            Text.debugLine("entry/src/main/ets/pages/AiSettings.ets(149:13)", "entry");
            Text.fontSize(13);
            Text.fontColor(COLOR_TEXT_SUB);
            Text.width('100%');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            ForEach.create();
            const forEachItemGenFunction = _item => {
                const p = _item;
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Row.create();
                    Row.debugLine("entry/src/main/ets/pages/AiSettings.ets(155:15)", "entry");
                    Row.width('100%');
                    Row.padding({ top: 6, bottom: 6 });
                    Row.onClick(() => {
                        this.applyPreset(p);
                    });
                }, Row);
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Column.create({ space: 3 });
                    Column.debugLine("entry/src/main/ets/pages/AiSettings.ets(156:17)", "entry");
                    Column.alignItems(HorizontalAlign.Start);
                    Column.layoutWeight(1);
                }, Column);
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Text.create(p.title);
                    Text.debugLine("entry/src/main/ets/pages/AiSettings.ets(157:19)", "entry");
                    Text.fontSize(15);
                    Text.fontWeight(FontWeight.Medium);
                    Text.fontColor(COLOR_TEXT);
                }, Text);
                Text.pop();
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Text.create(p.hint);
                    Text.debugLine("entry/src/main/ets/pages/AiSettings.ets(161:19)", "entry");
                    Text.fontSize(11);
                    Text.fontColor(COLOR_TEXT_SUB);
                }, Text);
                Text.pop();
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    Text.create(`${p.baseUrl}  ·  ${p.model}`);
                    Text.debugLine("entry/src/main/ets/pages/AiSettings.ets(164:19)", "entry");
                    Text.fontSize(10);
                    Text.fontColor(COLOR_TEXT_SUB);
                    Text.maxLines(2);
                }, Text);
                Text.pop();
                Column.pop();
                this.observeComponentCreation2((elmtId, isInitialRender) => {
                    If.create();
                    if (this.baseUrl === p.baseUrl && this.model === p.model) {
                        this.ifElseBranchUpdateFunction(0, () => {
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Text.create('✓');
                                Text.debugLine("entry/src/main/ets/pages/AiSettings.ets(173:19)", "entry");
                                Text.fontSize(16);
                                Text.fontColor(COLOR_OK);
                            }, Text);
                            Text.pop();
                        });
                    }
                    else {
                        this.ifElseBranchUpdateFunction(1, () => {
                            this.observeComponentCreation2((elmtId, isInitialRender) => {
                                Text.create('填入');
                                Text.debugLine("entry/src/main/ets/pages/AiSettings.ets(177:19)", "entry");
                                Text.fontSize(12);
                                Text.fontColor(COLOR_PRIMARY);
                            }, Text);
                            Text.pop();
                        });
                    }
                }, If);
                If.pop();
                Row.pop();
            };
            this.forEachUpdateFunction(elmtId, PRESETS, forEachItemGenFunction, (p: ProviderPreset) => p.title, false, false);
        }, ForEach);
        ForEach.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('换模型不必改代码：把下面的「模型名」改成 DeepSeek 平台上其它支持识图的模型即可。');
            Text.debugLine("entry/src/main/ets/pages/AiSettings.ets(189:13)", "entry");
            Text.fontSize(11);
            Text.fontColor(COLOR_TEXT_SUB);
            Text.width('100%');
        }, Text);
        Text.pop();
        // 服务商信息（当前只支持 DeepSeek）
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 填写区
            Column.create({ space: 14 });
            Column.debugLine("entry/src/main/ets/pages/AiSettings.ets(200:11)", "entry");
            // 填写区
            Column.width('100%');
            // 填写区
            Column.padding(16);
            // 填写区
            Column.backgroundColor(COLOR_CARD);
            // 填写区
            Column.borderRadius(RADIUS);
            // 填写区
            Column.shadow(CARD_SHADOW);
        }, Column);
        this.field.bind(this)('接口地址', this.baseUrl, AI_BASE_URL, false, (v: string) => {
            this.baseUrl = v;
        });
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // API Key：可切换明文
            Column.create({ space: 6 });
            Column.debugLine("entry/src/main/ets/pages/AiSettings.ets(206:13)", "entry");
            // API Key：可切换明文
            Column.width('100%');
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/AiSettings.ets(207:15)", "entry");
            Row.width('100%');
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('API Key');
            Text.debugLine("entry/src/main/ets/pages/AiSettings.ets(208:17)", "entry");
            Text.fontSize(13);
            Text.fontColor(COLOR_TEXT_SUB);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Blank.create();
            Blank.debugLine("entry/src/main/ets/pages/AiSettings.ets(211:17)", "entry");
        }, Blank);
        Blank.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.showKey ? '隐藏' : '显示');
            Text.debugLine("entry/src/main/ets/pages/AiSettings.ets(212:17)", "entry");
            Text.fontSize(12);
            Text.fontColor(COLOR_PRIMARY);
            Text.onClick(() => {
                this.showKey = !this.showKey;
            });
        }, Text);
        Text.pop();
        Row.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            TextInput.create({ text: this.apiKey, placeholder: '粘贴你的 API Key' });
            TextInput.debugLine("entry/src/main/ets/pages/AiSettings.ets(221:15)", "entry");
            TextInput.type(this.showKey ? InputType.Normal : InputType.Password);
            TextInput.fontSize(14);
            TextInput.height(44);
            TextInput.width('100%');
            TextInput.backgroundColor(COLOR_BG);
            TextInput.borderRadius(10);
            TextInput.onChange((v: string) => {
                this.apiKey = v;
            });
        }, TextInput);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('在 platform.deepseek.com 的「API keys」里创建，形如 sk-xxxxxxxx');
            Text.debugLine("entry/src/main/ets/pages/AiSettings.ets(232:15)", "entry");
            Text.fontSize(11);
            Text.fontColor(COLOR_TEXT_SUB);
            Text.width('100%');
        }, Text);
        Text.pop();
        // API Key：可切换明文
        Column.pop();
        this.field.bind(this)('模型名', this.model, AI_MODEL, false, (v: string) => {
            this.model = v;
        });
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(`默认 ${AI_MODEL}，支持图像理解，1M 上下文。`);
            Text.debugLine("entry/src/main/ets/pages/AiSettings.ets(243:13)", "entry");
            Text.fontSize(11);
            Text.fontColor(COLOR_TEXT_SUB);
            Text.width('100%');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('别填 deepseek-v4-flash 或 deepseek-v4-flash-vision-exp——那两个名字对应的模型已下线。');
            Text.debugLine("entry/src/main/ets/pages/AiSettings.ets(247:13)", "entry");
            Text.fontSize(11);
            Text.fontColor(COLOR_TEXT_SUB);
            Text.width('100%');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('模型必须支持图片输入，DeepSeek 的 deepseek-v4-pro 不支持识图。');
            Text.debugLine("entry/src/main/ets/pages/AiSettings.ets(251:13)", "entry");
            Text.fontSize(11);
            Text.fontColor(COLOR_TEXT_SUB);
            Text.width('100%');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Divider.create();
            Divider.debugLine("entry/src/main/ets/pages/AiSettings.ets(256:13)", "entry");
            Divider.color(COLOR_DIVIDER);
        }, Divider);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 思考模式开关
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/AiSettings.ets(259:13)", "entry");
            // 思考模式开关
            Row.width('100%');
            // 思考模式开关
            Row.padding({ top: 4 });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 3 });
            Column.debugLine("entry/src/main/ets/pages/AiSettings.ets(260:15)", "entry");
            Column.alignItems(HorizontalAlign.Start);
            Column.layoutWeight(1);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('深度思考');
            Text.debugLine("entry/src/main/ets/pages/AiSettings.ets(261:17)", "entry");
            Text.fontSize(14);
            Text.fontColor(COLOR_TEXT);
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.thinking
                ? '开启：更准，但思维链按输出计费，单次可能贵 5 倍且更慢'
                : '关闭：更快更省。识图列清单不需要深思，建议保持关闭');
            Text.debugLine("entry/src/main/ets/pages/AiSettings.ets(264:17)", "entry");
            Text.fontSize(11);
            Text.fontColor(COLOR_TEXT_SUB);
        }, Text);
        Text.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Toggle.create({ type: ToggleType.Switch, isOn: this.thinking });
            Toggle.debugLine("entry/src/main/ets/pages/AiSettings.ets(273:15)", "entry");
            Toggle.selectedColor(COLOR_PRIMARY);
            Toggle.onChange((on: boolean) => {
                this.thinking = on;
                this.testResult = '';
            });
        }, Toggle);
        Toggle.pop();
        // 思考模式开关
        Row.pop();
        // 填写区
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            // 测试结果
            if (this.testResult.length > 0) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Row.create({ space: 8 });
                        Row.debugLine("entry/src/main/ets/pages/AiSettings.ets(291:13)", "entry");
                        Row.width('100%');
                        Row.padding(14);
                        Row.backgroundColor(COLOR_CARD);
                        Row.borderRadius(RADIUS);
                    }, Row);
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(this.testOk ? '✓' : '!');
                        Text.debugLine("entry/src/main/ets/pages/AiSettings.ets(292:15)", "entry");
                        Text.fontSize(14);
                        Text.fontWeight(FontWeight.Bold);
                        Text.fontColor(this.testOk ? COLOR_OK : COLOR_WARN);
                    }, Text);
                    Text.pop();
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        Text.create(this.testResult);
                        Text.debugLine("entry/src/main/ets/pages/AiSettings.ets(296:15)", "entry");
                        Text.fontSize(12);
                        Text.fontColor(this.testOk ? COLOR_OK : COLOR_WARN);
                        Text.layoutWeight(1);
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
            Row.debugLine("entry/src/main/ets/pages/AiSettings.ets(307:11)", "entry");
            Row.height(80);
        }, Row);
        Row.pop();
        Column.pop();
        Scroll.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 底部操作
            Row.create({ space: 12 });
            Row.debugLine("entry/src/main/ets/pages/AiSettings.ets(317:7)", "entry");
            // 底部操作
            Row.width('100%');
            // 底部操作
            Row.padding({ left: PAGE_PAD, right: PAGE_PAD, top: 10, bottom: 10 });
            // 底部操作
            Row.backgroundColor(COLOR_CARD);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithChild({ type: ButtonType.Capsule });
            Button.debugLine("entry/src/main/ets/pages/AiSettings.ets(318:9)", "entry");
            Button.layoutWeight(1);
            Button.height(46);
            Button.backgroundColor(COLOR_CARD);
            Button.enabled(!this.testing);
            Button.onClick(() => {
                this.test();
            });
        }, Button);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create({ space: 8 });
            Row.debugLine("entry/src/main/ets/pages/AiSettings.ets(319:11)", "entry");
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            if (this.testing) {
                this.ifElseBranchUpdateFunction(0, () => {
                    this.observeComponentCreation2((elmtId, isInitialRender) => {
                        LoadingProgress.create();
                        LoadingProgress.debugLine("entry/src/main/ets/pages/AiSettings.ets(321:15)", "entry");
                        LoadingProgress.width(18);
                        LoadingProgress.height(18);
                        LoadingProgress.color(COLOR_PRIMARY);
                    }, LoadingProgress);
                });
            }
            else {
                this.ifElseBranchUpdateFunction(1, () => {
                });
            }
        }, If);
        If.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.testing ? '测试中…' : '测试连接');
            Text.debugLine("entry/src/main/ets/pages/AiSettings.ets(326:13)", "entry");
            Text.fontSize(15);
            Text.fontColor(COLOR_PRIMARY);
        }, Text);
        Text.pop();
        Row.pop();
        Button.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithChild({ type: ButtonType.Capsule });
            Button.debugLine("entry/src/main/ets/pages/AiSettings.ets(339:9)", "entry");
            Button.layoutWeight(1);
            Button.height(46);
            Button.backgroundColor(COLOR_PRIMARY);
            Button.onClick(() => {
                this.save();
            });
        }, Button);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create('保存');
            Text.debugLine("entry/src/main/ets/pages/AiSettings.ets(340:11)", "entry");
            Text.fontSize(16);
            Text.fontColor(Color.White);
        }, Text);
        Text.pop();
        Button.pop();
        // 底部操作
        Row.pop();
        Column.pop();
    }
    /** 统一的单行输入项 */
    field(label: string, value: string, placeholder: string, isPassword: boolean, onChange: (v: string) => void, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create({ space: 6 });
            Column.debugLine("entry/src/main/ets/pages/AiSettings.ets(361:5)", "entry");
            Column.width('100%');
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(label);
            Text.debugLine("entry/src/main/ets/pages/AiSettings.ets(362:7)", "entry");
            Text.fontSize(13);
            Text.fontColor(COLOR_TEXT_SUB);
            Text.width('100%');
        }, Text);
        Text.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            TextInput.create({ text: value, placeholder: placeholder });
            TextInput.debugLine("entry/src/main/ets/pages/AiSettings.ets(367:7)", "entry");
            TextInput.type(isPassword ? InputType.Password : InputType.Normal);
            TextInput.fontSize(14);
            TextInput.height(44);
            TextInput.width('100%');
            TextInput.backgroundColor(COLOR_BG);
            TextInput.borderRadius(10);
            TextInput.onChange(onChange);
        }, TextInput);
        Column.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
    public __resetStateVarsOnReuse__Internal(params: Object): void {
    }
    static getEntryName(): string {
        return "AiSettings";
    }
}
registerNamedRoute(() => new AiSettings(undefined, {}), "", { bundleName: "Calories.Lite.Test", moduleName: "entry", pagePath: "pages/AiSettings", pageFullPath: "entry/src/main/ets/pages/AiSettings", integratedHsp: "false", moduleType: "followWithHap" });
