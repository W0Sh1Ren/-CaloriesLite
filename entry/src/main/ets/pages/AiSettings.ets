/**
 * AI 识别配置页。
 *
 * 用智谱开放平台的 OpenAI 兼容接口做识图：填 API Key 和模型名，点「测试」当场验证。
 * Key 只存在本机应用沙箱里，不经任何中转。
 */
import { router, promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { AiConfig, AiProvider } from '../model/Types';
import { GLM_BASE_URL, GLM_MODEL, PRESETS, ProviderPreset } from '../model/Enums';
import { SettingsRepo } from '../service/SettingsRepo';
import { VisionService, VisionError } from '../service/VisionService';
import { COLOR_BG, COLOR_CARD, COLOR_OK, COLOR_PRIMARY, COLOR_TEXT, COLOR_TEXT_SUB, COLOR_WARN, GAP, PAGE_PAD, RADIUS } from '../common/Theme';

const DOMAIN = 0x0000;

@Entry
@Component
struct AiSettings {
  /** 固定走 OpenAI 兼容协议（智谱），不需要用户选 */
  @State baseUrl: string = GLM_BASE_URL;
  @State apiKey: string = '';
  @State model: string = GLM_MODEL;
  @State showKey: boolean = false;
  @State testing: boolean = false;
  @State testResult: string = '';
  @State testOk: boolean = false;

  aboutToAppear(): void {
    const c: AiConfig = SettingsRepo.loadAiConfig();
    this.baseUrl = c.baseUrl.length > 0 ? c.baseUrl : GLM_BASE_URL;
    this.apiKey = c.apiKey;
    this.model = c.model.length > 0 ? c.model : GLM_MODEL;
  }

  private current(): AiConfig {
    return new AiConfig(AiProvider.OPENAI_COMPATIBLE, this.baseUrl.trim(), this.apiKey.trim(), this.model.trim());
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
            Text('拍照识别用的是你自己的智谱 API Key。下面填的信息只保存本机，识别时由手机直连智谱开放平台，不经过任何中间服务器。')
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
            Text('OpenAI 兼容（智谱开放平台）')
              .fontSize(14)
              .fontColor(COLOR_TEXT)
              .width('100%')
            Text('请求发往智谱的 /chat/completions 接口，API Key 只保存在本机。')
              .fontSize(11)
              .fontColor(COLOR_TEXT_SUB)
              .width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor(COLOR_CARD)
          .borderRadius(RADIUS)

          // 服务商信息（当前只支持智谱 GLM）
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

            Text('换模型不必改代码：把下面的「模型名」改成智谱平台上其它支持识图的模型即可。')
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
            this.field('接口地址', this.baseUrl, GLM_BASE_URL, false, (v: string) => {
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

              Text('在 bigmodel.cn 控制台「API Keys」里创建，形如 xxxxxxxx.yyyyyyyy')
                .fontSize(11)
                .fontColor(COLOR_TEXT_SUB)
                .width('100%')
            }
            .width('100%')

            this.field('模型名', this.model, GLM_MODEL, false, (v: string) => {
              this.model = v;
            })

            Text(`默认 ${GLM_MODEL}，是 GLM-4.6V 的免费版本，支持识图且不收费。`)
              .fontSize(11)
              .fontColor(COLOR_TEXT_SUB)
              .width('100%')
            Text('模型必须支持图片输入，纯文本模型无法识别照片。')
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
