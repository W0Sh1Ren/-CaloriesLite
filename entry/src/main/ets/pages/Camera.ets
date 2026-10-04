/**
 * 拍照识别页。
 *
 * 流程：拍照/选图 → 压缩 → 调 AI 视觉识别 → 查表折算 → 跳结果确认页。
 * 全程在本地压缩后才上传，图片不会以原图尺寸发出去。
 */
import { router, promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { AiConfig, FoodDraft } from '../model/Types';
import { guessMealType } from '../model/Enums';
import { hourOf } from '../common/DateUtil';
import { SettingsRepo } from '../service/SettingsRepo';
import { ImageService, PreparedImage, ImageError } from '../service/ImageService';
import { VisionService, VisionResult, VisionError } from '../service/VisionService';
import { PermissionUtil } from '../common/PermissionUtil';
import { AppState, PendingResult } from '../common/AppState';
import { COLOR_BG, COLOR_CARD, COLOR_DIVIDER, COLOR_PRIMARY, COLOR_TEXT, COLOR_TEXT_SUB, COLOR_WARN, GAP, PAGE_PAD, RADIUS } from '../common/Theme';

const DOMAIN = 0x0000;

@Entry
@Component
struct CameraPage {
  @State imageUri: string = '';
  @State busy: boolean = false;
  @State statusText: string = '';
  @State errorText: string = '';

  private uiContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  /** 拍一张 */
  private async onTakePhoto(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.errorText = '';
    try {
      await PermissionUtil.ensureCamera(this.uiContext());
      const uri: string = await ImageService.takePhoto(this.uiContext());
      if (uri.length === 0) {
        return; // 用户取消
      }
      this.imageUri = uri;
      await this.analyze(uri);
    } catch (err) {
      this.handleError(err);
    }
  }

  /** 从相册选一张 */
  private async onPickGallery(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.errorText = '';
    try {
      await PermissionUtil.ensurePhotoRead(this.uiContext());
      const uri: string = await ImageService.pickFromGallery();
      if (uri.length === 0) {
        return; // 用户取消
      }
      this.imageUri = uri;
      await this.analyze(uri);
    } catch (err) {
      this.handleError(err);
    }
  }

  /** 压缩 + 识别 */
  private async analyze(uri: string): Promise<void> {
    this.busy = true;
    this.statusText = '正在压缩图片…';
    try {
      const config: AiConfig = SettingsRepo.loadAiConfig();
      VisionService.validate(config);

      const prepared: PreparedImage = await ImageService.prepare(uri, this.uiContext());

      this.statusText = `正在用 ${config.model} 识别…`;
      const result: VisionResult = await VisionService.recognize(config, prepared.base64, prepared.mimeType);

      // 食物表里没有的条目，再补问一次营养值
      const missing: FoodDraft[] = result.drafts.filter((d: FoodDraft) => d.kcal <= 0);
      if (missing.length > 0) {
        this.statusText = '正在估算热量…';
        result.drafts = await VisionService.estimateNutrition(config, result.drafts);
      }

      AppState.pending = new PendingResult(
        prepared.localUri.length > 0 ? prepared.localUri : uri,
        result.drafts,
        result.overallNote,
        result.model
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
      .padding({ left: PAGE_PAD, right: PAGE_PAD, top: 8, bottom: 8 })

      Scroll() {
        Column({ space: GAP }) {
          // 预览区
          Column() {
            if (this.imageUri.length > 0) {
              Image(this.imageUri)
                .width('100%')
                .height(280)
                .objectFit(ImageFit.Cover)
                .borderRadius(RADIUS)
            } else {
              Column({ space: 8 }) {
                Text('📷')
                  .fontSize(44)
                Text('拍一张食物照片，或从相册选一张')
                  .fontSize(13)
                  .fontColor(COLOR_TEXT_SUB)
                  .textAlign(TextAlign.Center)
              }
              .width('100%')
              .height(280)
              .justifyContent(FlexAlign.Center)
              .backgroundColor(COLOR_CARD)
              .borderRadius(RADIUS)
            }
          }
          .width('100%')

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

          // 操作按钮
          Row({ space: 10 }) {
            Button({ type: ButtonType.Capsule }) {
              Text('拍照').fontSize(16).fontColor(Color.White)
            }
            .layoutWeight(1)
            .height(48)
            .backgroundColor(COLOR_PRIMARY)
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
              Text('照片只会在本机压缩后发送到智谱开放平台')
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
