/**
 * AI 识别配置页。
 *
 * 用 DeepSeek 的 OpenAI 兼容接口做识图：填 API Key 和模型名，点「测试」当场验证。
 * Key 只存在本机应用沙箱里，不经任何中转。
 */
import { router, promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { AiConfig, AiProvider } from '../model/Types';
import { AI_BASE_URL, AI_MODEL, PRESETS, ProviderPreset } from '../model/Enums';
import { SettingsRepo } from '../service/SettingsRepo';
import { VisionService, VisionError } from '../service/VisionService';
import { CARD_SHADOW, COLOR_BG, COLOR_CARD, COLOR_DIVIDER, COLOR_OK, COLOR_PRIMARY, COLOR_TEXT, COLOR_TEXT_SUB, COLOR_WARN, GAP, INPUT_PLACEHOLDER, INPUT_TEXT, PAGE_PAD, RADIUS } from '../common/Theme';

const DOMAIN = 0x0000;

@Entry
@Component
struct AiSettings {
  /** 固定走 OpenAI 兼容协议，不需要用户选 */
  @State baseUrl: string = AI_BASE_URL;
  @State apiKey: string = '';
  @State model: string = AI_MODEL;
  /** 思考模式，默认关；开了更准但更贵更慢 */
  @State thinking: boolean = false;
  @State showKey: boolean = false;
  @State testing: boolean = false;
  @State testResult: string = '';
  @State testOk: boolean = false;

  aboutToAppear(): void {
    const c: AiConfig = SettingsRepo.loadAiConfig();
    this.baseUrl = c.baseUrl.length > 0 ? c.baseUrl : AI_BASE_URL;
    this.apiKey = c.apiKey;
    this.model = c.model.length > 0 ? c.model : AI_MODEL;
    this.thinking = c.thinking;
  }

  private current(): AiConfig {
    return new AiConfig(AiProvider.OPENAI_COMPATIBLE, this.baseUrl.trim(), this.apiKey.trim(),
      this.model.trim(), this.thinking);
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
    } catch (err) {
      this.testOk = false;
      if (err instanceof VisionError) {
        this.testResult = (err as VisionError).message;
      } else {
        const e: Error = err as Error;
        this.testResult = e.message.length > 0 ? e.message : '测试失败';
      }
      hilog.error(DOMAIN, 'CalorieLite', 'ai test failed');
    } finally {
      this.testing = false;
    }
  }

  private save(): void {
    SettingsRepo.saveAiConfig(this.current());
    promptAction.showToast({ message: '已保存' });
    router.back();
  }

  build() {
    Column() {
      // 顶部栏
      Row() {
        Button({ type: ButtonType.Circle }) {
          Text('‹').fontSize(22).fontColor(COLOR_TEXT)
        }
        .width(36).height(36).backgroundColor(COLOR_CARD)
        .onClick(() => {
          router.back();
        })

        Text('AI 识别配置')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_TEXT)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Row().width(36).height(36)
      }
      .width('100%')
      .padding({ left: PAGE_PAD, right: PAGE_PAD, top: 8, bottom: 8 })

      Scroll() {
        Column({ space: GAP }) {
          // 说明
          Column({ space: 6 }) {
            Text('这个应用不卖会员，也不代管额度')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(COLOR_TEXT)
              .width('100%')
            Text('拍照识别用的是你自己的 DeepSeek API Key。下面填的信息只保存本机，识别时由手机直连 DeepSeek，不经过任何中间服务器。')
              .fontSize(12)
              .fontColor(COLOR_TEXT_SUB)
              .width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor(COLOR_CARD)
          .borderRadius(RADIUS)

          // 接口类型：固定走 OpenAI 兼容协议，不再让用户选
          Column({ space: 6 }) {
            Text('接口协议')
              .fontSize(13)
              .fontColor(COLOR_TEXT_SUB)
              .width('100%')
            Text('OpenAI 兼容（DeepSeek）')
              .fontSize(14)
              .fontColor(COLOR_TEXT)
              .width('100%')
            Text('请求发往 DeepSeek 的 /chat/completions 接口，API Key 只保存在本机。')
              .fontSize(11)
              .fontColor(COLOR_TEXT_SUB)
              .width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor(COLOR_CARD)
          .borderRadius(RADIUS)

          // 服务商信息（当前只支持 DeepSeek）
          Column({ space: 10 }) {
            Text('服务商')
              .fontSize(13)
              .fontColor(COLOR_TEXT_SUB)
              .width('100%')

            ForEach(PRESETS, (p: ProviderPreset) => {
              Row() {
                Column({ space: 3 }) {
                  Text(p.title)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(COLOR_TEXT)
                  Text(p.hint)
                    .fontSize(11)
                    .fontColor(COLOR_TEXT_SUB)
                  Text(`${p.baseUrl}  ·  ${p.model}`)
                    .fontSize(10)
                    .fontColor(COLOR_TEXT_SUB)
                    .maxLines(2)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                if (this.baseUrl === p.baseUrl && this.model === p.model) {
                  Text('✓')
                    .fontSize(16)
                    .fontColor(COLOR_OK)
                } else {
                  Text('填入')
                    .fontSize(12)
                    .fontColor(COLOR_PRIMARY)
                }
              }
              .width('100%')
              .padding({ top: 6, bottom: 6 })
              .onClick(() => {
                this.applyPreset(p);
              })
            }, (p: ProviderPreset) => p.title)

            Text('换模型不必改代码：把下面的「模型名」改成 DeepSeek 平台上其它支持识图的模型即可。')
              .fontSize(11)
              .fontColor(COLOR_TEXT_SUB)
              .width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor(COLOR_CARD)
          .borderRadius(RADIUS)

          // 填写区
          Column({ space: 14 }) {
            this.field('接口地址', this.baseUrl, AI_BASE_URL, false, (v: string) => {
              this.baseUrl = v;
            })

            // API Key：可切换明文
            Column({ space: 6 }) {
              Row() {
                Text('API Key')
                  .fontSize(13)
                  .fontColor(COLOR_TEXT_SUB)
                Blank()
                Text(this.showKey ? '隐藏' : '显示')
                  .fontSize(12)
                  .fontColor(COLOR_PRIMARY)
                  .onClick(() => {
                    this.showKey = !this.showKey;
                  })
              }
              .width('100%')

              TextInput({ text: this.apiKey, placeholder: '粘贴你的 API Key' })
                .type(this.showKey ? InputType.Normal : InputType.Password)
                .fontSize(14)
                .height(44)
                .width('100%')
                .fontColor(INPUT_TEXT)
                .placeholderColor(INPUT_PLACEHOLDER)
                .backgroundColor(COLOR_BG)
                .borderRadius(10)
                .onChange((v: string) => {
                  this.apiKey = v;
                })

              Text('在 platform.deepseek.com 的「API keys」里创建，形如 sk-xxxxxxxx')
                .fontSize(11)
                .fontColor(COLOR_TEXT_SUB)
                .width('100%')
            }
            .width('100%')

            this.field('模型名', this.model, AI_MODEL, false, (v: string) => {
              this.model = v;
            })

            Text(`默认 ${AI_MODEL}，支持图像理解，1M 上下文。`)
              .fontSize(11)
              .fontColor(COLOR_TEXT_SUB)
              .width('100%')
            Text('别填 deepseek-v4-flash 或 deepseek-v4-flash-vision-exp——那两个名字对应的模型已下线。')
              .fontSize(11)
              .fontColor(COLOR_TEXT_SUB)
              .width('100%')
            Text('模型必须支持图片输入，DeepSeek 的 deepseek-v4-pro 不支持识图。')
              .fontSize(11)
              .fontColor(COLOR_TEXT_SUB)
              .width('100%')

            Divider().color(COLOR_DIVIDER)

            // 思考模式开关
            Row() {
              Column({ space: 3 }) {
                Text('深度思考')
                  .fontSize(14)
                  .fontColor(COLOR_TEXT)
                Text(this.thinking
                  ? '开启：更准，但思维链按输出计费，单次可能贵 5 倍且更慢'
                  : '关闭：更快更省。识图列清单不需要深思，建议保持关闭')
                  .fontSize(11)
                  .fontColor(COLOR_TEXT_SUB)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Toggle({ type: ToggleType.Switch, isOn: this.thinking })
                .selectedColor(COLOR_PRIMARY)
                .onChange((on: boolean) => {
                  this.thinking = on;
                  this.testResult = '';
                })
            }
            .width('100%')
            .padding({ top: 4 })
          }
          .width('100%')
          .padding(16)
          .backgroundColor(COLOR_CARD)
          .borderRadius(RADIUS)
          .shadow(CARD_SHADOW)

          // 测试结果
          if (this.testResult.length > 0) {
            Row({ space: 8 }) {
              Text(this.testOk ? '✓' : '!')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.testOk ? COLOR_OK : COLOR_WARN)
              Text(this.testResult)
                .fontSize(12)
                .fontColor(this.testOk ? COLOR_OK : COLOR_WARN)
                .layoutWeight(1)
            }
            .width('100%')
            .padding(14)
            .backgroundColor(COLOR_CARD)
            .borderRadius(RADIUS)
          }

          Row().height(80)
        }
        .width('100%')
        .padding({ left: PAGE_PAD, right: PAGE_PAD, top: 8, bottom: 16 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)

      // 底部操作
      Row({ space: 12 }) {
        Button({ type: ButtonType.Capsule }) {
          Row({ space: 8 }) {
            if (this.testing) {
              LoadingProgress()
                .width(18)
                .height(18)
                .color(COLOR_PRIMARY)
            }
            Text(this.testing ? '测试中…' : '测试连接')
              .fontSize(15)
              .fontColor(COLOR_PRIMARY)
          }
        }
        .layoutWeight(1)
        .height(46)
        .backgroundColor(COLOR_CARD)
        .enabled(!this.testing)
        .onClick(() => {
          this.test();
        })

        Button({ type: ButtonType.Capsule }) {
          Text('保存').fontSize(16).fontColor(Color.White)
        }
        .layoutWeight(1)
        .height(46)
        .backgroundColor(COLOR_PRIMARY)
        .onClick(() => {
          this.save();
        })
      }
      .width('100%')
      .padding({ left: PAGE_PAD, right: PAGE_PAD, top: 10, bottom: 10 })
      .backgroundColor(COLOR_CARD)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BG)
  }

  /** 统一的单行输入项 */
  @Builder
  field(label: string, value: string, placeholder: string, isPassword: boolean, onChange: (v: string) => void) {
    Column({ space: 6 }) {
      Text(label)
        .fontSize(13)
        .fontColor(COLOR_TEXT_SUB)
        .width('100%')

      TextInput({ text: value, placeholder: placeholder })
        .type(isPassword ? InputType.Password : InputType.Normal)
        .fontSize(14)
        .height(44)
        .width('100%')
        .fontColor(INPUT_TEXT)
        .placeholderColor(INPUT_PLACEHOLDER)
        .backgroundColor(COLOR_BG)
        .borderRadius(10)
        .onChange(onChange)
    }
    .width('100%')
  }
}
