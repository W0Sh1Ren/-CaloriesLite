/**
 * AI 识别配置页。
 *
 * 用户自带 API：填服务商、接口地址、Key、模型名，点「测试」当场验证能不能用。
 * Key 只存在本机应用沙箱里，不经任何中转。
 */
import { router, promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { AiConfig, AiProvider } from '../model/Types';
import { PRESETS, ProviderPreset, providerLabel } from '../model/Enums';
import { SettingsRepo } from '../service/SettingsRepo';
import { VisionService, VisionError } from '../service/VisionService';
import { COLOR_BG, COLOR_CARD, COLOR_DIVIDER, COLOR_OK, COLOR_PRIMARY, COLOR_TEXT, COLOR_TEXT_SUB, COLOR_WARN, GAP, PAGE_PAD, RADIUS } from '../common/Theme';

const DOMAIN = 0x0000;

@Entry
@Component
struct AiSettings {
  @State provider: AiProvider = AiProvider.OPENAI_COMPATIBLE;
  @State baseUrl: string = '';
  @State apiKey: string = '';
  @State model: string = '';
  @State showKey: boolean = false;
  @State testing: boolean = false;
  @State testResult: string = '';
  @State testOk: boolean = false;

  aboutToAppear(): void {
    const c: AiConfig = SettingsRepo.loadAiConfig();
    this.provider = c.provider;
    this.baseUrl = c.baseUrl;
    this.apiKey = c.apiKey;
    this.model = c.model;
  }

  private current(): AiConfig {
    return new AiConfig(this.provider, this.baseUrl.trim(), this.apiKey.trim(), this.model.trim());
  }

  private applyPreset(p: ProviderPreset): void {
    this.provider = p.provider;
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
            Text('拍照识别用的是你自己的 AI 接口。下面填的信息只保存本机，识别时由手机直连你填的服务商，不经过任何中间服务器。')
              .fontSize(12)
              .fontColor(COLOR_TEXT_SUB)
              .width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor(COLOR_CARD)
          .borderRadius(RADIUS)

          // 服务商选择
          Column({ space: 10 }) {
            Text('接口类型')
              .fontSize(13)
              .fontColor(COLOR_TEXT_SUB)
              .width('100%')

            Row({ space: 8 }) {
              ForEach([AiProvider.OPENAI_COMPATIBLE, AiProvider.GEMINI], (p: AiProvider) => {
                Text(providerLabel(p))
                  .fontSize(13)
                  .fontColor(this.provider === p ? Color.White : COLOR_TEXT)
                  .textAlign(TextAlign.Center)
                  .layoutWeight(1)
                  .height(40)
                  .backgroundColor(this.provider === p ? COLOR_PRIMARY : COLOR_BG)
                  .borderRadius(10)
                  .onClick(() => {
                    this.provider = p;
                    this.testResult = '';
                  })
              }, (p: AiProvider) => p)
            }
            .width('100%')

            Text(this.provider === AiProvider.OPENAI_COMPATIBLE
              ? '适用于绝大多数服务商：智谱、通义、Kimi、DeepSeek、硅基流动、OpenAI 以及各类兼容接口'
              : 'Google 官方接口，需要能访问 googleapis.com 的网络环境')
              .fontSize(11)
              .fontColor(COLOR_TEXT_SUB)
              .width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor(COLOR_CARD)
          .borderRadius(RADIUS)

          // 常用预设
          Column({ space: 10 }) {
            Text('常用服务商（点一下自动填好地址和模型）')
              .fontSize(13)
              .fontColor(COLOR_TEXT_SUB)
              .width('100%')

            ForEach(PRESETS, (p: ProviderPreset) => {
              Row() {
                Column({ space: 2 }) {
                  Text(p.title)
                    .fontSize(14)
                    .fontColor(COLOR_TEXT)
                  Text(p.hint)
                    .fontSize(11)
                    .fontColor(COLOR_TEXT_SUB)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Text(this.baseUrl === p.baseUrl && this.model === p.model ? '✓' : '填入')
                  .fontSize(12)
                  .fontColor(this.baseUrl === p.baseUrl && this.model === p.model ? COLOR_OK : COLOR_PRIMARY)
              }
              .width('100%')
              .padding({ top: 8, bottom: 8 })
              .onClick(() => {
                this.applyPreset(p);
              })
            }, (p: ProviderPreset) => p.title)
          }
          .width('100%')
          .padding(16)
          .backgroundColor(COLOR_CARD)
          .borderRadius(RADIUS)

          // 填写区
          Column({ space: 14 }) {
            this.field('接口地址', this.baseUrl, 'https://api.example.com/v1', false, (v: string) => {
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
                .backgroundColor(COLOR_BG)
                .borderRadius(10)
                .onChange((v: string) => {
                  this.apiKey = v;
                })
            }
            .width('100%')

            this.field('模型名', this.model, '例如 glm-4v-flash', false, (v: string) => {
              this.model = v;
            })

            Text('模型必须支持图片输入（识图）。纯文本模型无法识别照片。')
              .fontSize(11)
              .fontColor(COLOR_TEXT_SUB)
              .width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor(COLOR_CARD)
          .borderRadius(RADIUS)

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
        .backgroundColor(COLOR_BG)
        .borderRadius(10)
        .onChange(onChange)
    }
    .width('100%')
  }
}
