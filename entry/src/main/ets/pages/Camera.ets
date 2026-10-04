/**
 * 拍照识别页。
 *
 * 流程：拍照/选图 → 压缩 → 调 AI 视觉识别 → 查表折算 → 跳结果确认页。
 * 全程在本地压缩后才上传，图片不会以原图尺寸发出去。
 */
import { router, promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { AiConfig } from '../model/Types';
import { guessMealType } from '../model/Enums';
import { hourOf } from '../common/DateUtil';
import { SettingsRepo } from '../service/SettingsRepo';
import { ImageService, PreparedImage, ImageError } from '../service/ImageService';
import { VisionService, VisionResult, VisionError } from '../service/VisionService';
import { PermissionUtil } from '../common/PermissionUtil';
import { AppState, PendingResult } from '../common/AppState';
import { CARD_SHADOW, COLOR_BG, COLOR_CARD, COLOR_DIVIDER, COLOR_PRIMARY, COLOR_TEXT, COLOR_TEXT_SUB, COLOR_WARN, GAP, INPUT_PLACEHOLDER, INPUT_TEXT, PAGE_PAD, RADIUS } from '../common/Theme';

const DOMAIN = 0x0000;

/** 一次最多几张照片 */
const MAX_IMAGES: number = 4;

@Entry
@Component
struct CameraPage {
  /** 已选/已拍的图片 uri 列表，可多张 */
  @State imageUris: string[] = [];
  /** 用户手写的补充说明，会随请求发给模型 */
  @State notes: string = '';
  @State busy: boolean = false;
  @State statusText: string = '';
  @State errorText: string = '';

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
    } catch (err) {
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
    } catch (err) {
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

      AppState.pending = new PendingResult(
        localUris,
        result.drafts,
        result.overallNote,
        result.model,
        this.notes.trim()
      );
      AppState.needRefreshHome = true;
      AppState.targetMeal = guessMealType(hourOf(Date.now()));

      router.pushUrl({ url: 'pages/ResultConfirm' });
    } catch (err) {
      this.handleError(err);
    } finally {
      this.busy = false;
      this.statusText = '';
    }
  }

  private handleError(err: Object): void {
    let msg: string = '出了点问题，再试一次';
    if (err instanceof VisionError) {
      msg = (err as VisionError).message;
    } else if (err instanceof ImageError) {
      msg = (err as ImageError).message;
    } else {
      const e: Error = err as Error;
      msg = e.message.length > 0 ? e.message : msg;
    }
    this.errorText = msg;
    hilog.error(DOMAIN, 'CalorieLite', 'camera page error: %{public}s', msg);
  }

  private goAiSettings(): void {
    router.pushUrl({ url: 'pages/AiSettings' });
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

        Text('拍照识别')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_TEXT)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        // 占位，保持标题居中
        Row().width(36).height(36)
      }
      .width('100%')
      /*
       * 顶部安全距离，口径与其它页面一致（DayDetail / 主界面）：
       * 用 AppState.topInset（EntryAbility 实测的 avoid area 高度）。
       * 这一页是普通页，窗口仍会延伸到状态栏区域，
       * 只留 8vp 的话顶栏会压在系统时间上（实测反馈）。
       */
      .padding({ left: PAGE_PAD, right: PAGE_PAD, top: AppState.topInset + 8, bottom: 8 })

      Scroll() {
        Column({ space: GAP }) {
          // ------------------------------------------------ 图片区
          if (this.imageUris.length === 0) {
            Column({ space: 8 }) {
              Text('📷')
                .fontSize(44)
              Text(`拍一张或从相册选几张，最多 ${MAX_IMAGES} 张`)
                .fontSize(13)
                .fontColor(COLOR_TEXT_SUB)
                .textAlign(TextAlign.Center)
              Text('同一餐的多张照片一起发送，模型会合并判断，比逐张识别更准')
                .fontSize(11)
                .fontColor(COLOR_TEXT_SUB)
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .height(200)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(COLOR_CARD)
            .borderRadius(RADIUS)
            .shadow(CARD_SHADOW)
          } else {
            // 缩略图横向排列，每张右上角带删除
            Scroll() {
              Row({ space: 10 }) {
                ForEach(this.imageUris, (uri: string, index: number) => {
                  Stack({ alignContent: Alignment.TopEnd }) {
                    Image(uri)
                      .width(150)
                      .height(150)
                      .objectFit(ImageFit.Cover)
                      .borderRadius(14)

                    Button({ type: ButtonType.Circle }) {
                      Text('✕').fontSize(12).fontColor(Color.White)
                    }
                    .width(24)
                    .height(24)
                    .backgroundColor('#99000000')
                    .margin({ top: 6, right: 6 })
                    .onClick(() => {
                      this.removeImage(index);
                    })
                  }
                  .width(150)
                  .height(150)
                }, (uri: string, index: number) => `${index}-${uri}`)

                // 末尾的「再加一张」入口
                if (this.imageUris.length < MAX_IMAGES) {
                  Column({ space: 4 }) {
                    Text('+').fontSize(28).fontColor(COLOR_TEXT_SUB)
                    Text('再加一张').fontSize(11).fontColor(COLOR_TEXT_SUB)
                  }
                  .width(150)
                  .height(150)
                  .justifyContent(FlexAlign.Center)
                  .backgroundColor(COLOR_CARD)
                  .borderRadius(14)
                  .border({ width: 1, color: COLOR_DIVIDER, style: BorderStyle.Dashed })
                  .onClick(() => {
                    this.onPickGallery();
                  })
                }
              }
              .padding({ right: 4 })
            }
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
            .width('100%')
          }

          // ------------------------------------------------ 补充说明
          Column({ space: 6 }) {
            Row() {
              Text('补充说明')
                .fontSize(13)
                .fontColor(COLOR_TEXT_SUB)
              Blank()
              Text(`${this.notes.length}/100`)
                .fontSize(11)
                .fontColor(COLOR_TEXT_SUB)
            }
            .width('100%')

            TextArea({
              text: this.notes,
              placeholder: '可选。例如「这碗面只吃了一半」「米饭是小半碗」，模型会据此调整份量'
            })
              .fontSize(14)
              .height(80)
              .width('100%')
              .fontColor(INPUT_TEXT)
              .placeholderColor(INPUT_PLACEHOLDER)
              .backgroundColor(COLOR_BG)
              .borderRadius(10)
              .maxLength(100)
              .onChange((v: string) => {
                this.notes = v;
              })
          }
          .width('100%')
          .padding(14)
          .backgroundColor(COLOR_CARD)
          .borderRadius(RADIUS)
          .shadow(CARD_SHADOW)

          // 错误提示
          if (this.errorText.length > 0) {
            Row({ space: 8 }) {
              Text('!')
                .fontSize(14)
                .fontColor(COLOR_WARN)
                .fontWeight(FontWeight.Bold)
              Text(this.errorText)
                .fontSize(13)
                .fontColor(COLOR_WARN)
                .layoutWeight(1)
            }
            .width('100%')
            .padding(12)
            .backgroundColor('#FFF1EF')
            .borderRadius(10)
          }

          // 忙碌状态
          if (this.busy) {
            Row({ space: 10 }) {
              LoadingProgress()
                .width(22)
                .height(22)
                .color(COLOR_PRIMARY)
              Text(this.statusText)
                .fontSize(13)
                .fontColor(COLOR_TEXT_SUB)
                .layoutWeight(1)
            }
            .width('100%')
            .padding(14)
            .backgroundColor(COLOR_CARD)
            .borderRadius(RADIUS)
          }

          // ------------------------------------------------ 操作
          Row({ space: 10 }) {
            Button({ type: ButtonType.Capsule }) {
              Text('拍照').fontSize(16).fontColor(COLOR_TEXT)
            }
            .layoutWeight(1)
            .height(48)
            .backgroundColor(COLOR_CARD)
            .enabled(!this.busy)
            .onClick(() => {
              this.onTakePhoto();
            })

            Button({ type: ButtonType.Capsule }) {
              Text('相册').fontSize(16).fontColor(COLOR_TEXT)
            }
            .layoutWeight(1)
            .height(48)
            .backgroundColor(COLOR_CARD)
            .enabled(!this.busy)
            .onClick(() => {
              this.onPickGallery();
            })
          }
          .width('100%')

          // 主操作：开始识别
          Button({ type: ButtonType.Capsule }) {
            Text(this.busy ? '识别中…' : '开始识别')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
          }
          .width('100%')
          .height(50)
          .backgroundColor(COLOR_PRIMARY)
          .enabled(!this.busy && this.imageUris.length > 0)
          .opacity(!this.busy && this.imageUris.length > 0 ? 1 : 0.5)
          .onClick(() => {
            this.analyze();
          })

          // 配置提示
          if (!SettingsRepo.isAiReady()) {
            Column({ space: 8 }) {
              Text('识别功能还没配置')
                .fontSize(14)
                .fontColor(COLOR_TEXT)
              Text('需要填入你自己的 AI 接口地址、API Key 和模型名才能识别')
                .fontSize(12)
                .fontColor(COLOR_TEXT_SUB)
              Button({ type: ButtonType.Capsule }) {
                Text('去配置').fontSize(14).fontColor(Color.White)
              }
              .height(38)
              .backgroundColor(COLOR_PRIMARY)
              .onClick(() => {
                this.goAiSettings();
              })
            }
            .width('100%')
            .padding(16)
            .backgroundColor(COLOR_CARD)
            .borderRadius(RADIUS)
            .alignItems(HorizontalAlign.Start)
          } else {
            Column({ space: 6 }) {
              Text(`当前模型：${SettingsRepo.loadAiConfig().model}`)
                .fontSize(12)
                .fontColor(COLOR_TEXT_SUB)
                .width('100%')
              Text('照片只会在本机压缩后发送到 DeepSeek')
                .fontSize(12)
                .fontColor(COLOR_TEXT_SUB)
                .width('100%')
            }
            .width('100%')
          }

          Row().height(16)
        }
        .width('100%')
        .padding({ left: PAGE_PAD, right: PAGE_PAD, top: 8, bottom: 16 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BG)
  }
}
