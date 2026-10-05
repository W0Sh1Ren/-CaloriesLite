/**
 * 拍照识别页。
 *
 * 流程：拍照/选图 → 压缩 → 调 AI 视觉识别 → 查表折算 → 跳结果确认页。
 * 全程在本地压缩后才上传，图片不会以原图尺寸发出去。
 */
import { router, promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { window, display } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { AiConfig, MealType } from '../model/Types';
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
  /**
   * 键盘占用的高度（vp），0 表示键盘没弹起。
   *
   * 用来给滚动区补一段等高空白，避免底部的主按钮被键盘挡住。
   */
  @State keyboardVp: number = 0;

  /**
   * 上一次进入本页时选中的餐次。
   *
   * 从记录页给某一天补记时，AppState.targetMeal 会先被设成那一天的餐次；
   * 这里用它做初值，让「补记」也能落在正确的餐次上，
   * 而不是靠当前时间猜（猜出来的默认值对补记场景没有意义）。
   * 识别成功后会按识别时刻的真实餐次覆盖它。
   */
  @State meal: MealType = MealType.LUNCH;

  aboutToAppear(): void {
    // 进来就把目标日期固定下来：供识别结果页与返回首页使用
    this.meal = AppState.targetMeal;
    hilog.info(DOMAIN, 'CalorieLite', 'camera for day=%{public}s meal=%{public}d',
      AppState.effectiveTargetDay(), this.meal);
    this.watchKeyboard();
  }

  /**
   * 监听键盘高度，换算成 vp 存进 keyboardVp。
   *
   * 回调给的是 px，而页面布局用 vp，所以要除以屏幕密度
   *（这台机器 density 是 3.5，直接当 vp 用会大 3 倍）。
   */
  private watchKeyboard(): void {
    const handler: Callback<number> = (heightPx: number) => {
      const density: number = display.getDefaultDisplaySync().densityPixels;
      const safeDensity: number = density > 0 ? density : 1;
      this.keyboardVp = heightPx > 0 ? Math.round(heightPx / safeDensity) : 0;
    };
    this.keyboardHandler = handler;
    window.getLastWindow(this.uiContext())
      .then((hostWin: window.Window) => {
        this.hostWindow = hostWin;
        // 显式标出事件名与回调类型：Window 上的 on 是重载集合，
        // 传字面量时编译器可能匹配不到正确的那一个
        hostWin.on('keyboardHeightChange', handler);
      })
      .catch((e: Error) => {
        hilog.warn(DOMAIN, 'CalorieLite', 'watchKeyboard failed: %{public}s', e.message);
      });
  }

  private uiContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  /**
   * 离开本页：如果用户没走完识别流程（直接返回），
   * 就把「要记到哪一天」清掉，避免影响下一次正常拍照记录。
   * 走完流程时确认页已经消费过它，这里清掉也无害。
   */
  aboutToDisappear(): void {
    if (this.hostWindow !== null && this.keyboardHandler !== null) {
      try {
        this.hostWindow.off('keyboardHeightChange', this.keyboardHandler);
      } catch (err) {
        // 解绑失败不影响退出
      }
      this.hostWindow = null;
      this.keyboardHandler = null;
    }
    if (AppState.pending === null) {
      AppState.clearTargetDay();
    }
  }

  /** 持有窗口与键盘回调，离开时必须解绑 */
  private hostWindow: window.Window | null = null;
  private keyboardHandler: Callback<number> | null = null;

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

  /**
   * 发起识别。
   *
   * 两条路径（用户要求「现在是不上传照片就不能记录，改成纯文字也能记录」）：
   *   · 有照片  → 走识图，文字说明作为补充（原有的路径）
   *   · 没照片  → 走纯文字识别，把用户的描述当唯一依据
   * 两者都要求「至少有照片或有描述」，否则没有可判断的信息。
   */
  private async analyze(): Promise<void> {
    const notes: string = this.notes.trim();
    const hasImages: boolean = this.imageUris.length > 0;
    if (!hasImages && notes.length === 0) {
      this.errorText = '拍一张照片，或者写一句吃了什么';
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

      if (hasImages) {
        for (let i = 0; i < this.imageUris.length; i++) {
          this.statusText = this.imageUris.length > 1
            ? `正在压缩第 ${i + 1}/${this.imageUris.length} 张…`
            : '正在压缩图片…';
          const prepared: PreparedImage = await ImageService.prepare(this.imageUris[i], ctx);
          bases.push(prepared.base64);
          localUris.push(prepared.localUri.length > 0 ? prepared.localUri : this.imageUris[i]);
        }
        this.statusText = `正在用 ${config.model} 识别…`;
      } else {
        // 纯文字：没有图片可压缩，直接说明在做什么
        this.statusText = `正在用 ${config.model} 估算热量…`;
      }

      // 多张图一次发过去，热量与三大营养素同一次返回；
      // 纯文字时由 recognizeText 走文字专用提示词
      const result: VisionResult = hasImages
        ? await VisionService.recognize(config, bases, notes)
        : await VisionService.recognizeText(config, notes);

      AppState.pending = new PendingResult(
        localUris,
        result.drafts,
        result.overallNote,
        result.model,
        notes
      );
      AppState.needRefreshHome = true;
      AppState.targetMeal = guessMealType(hourOf(Date.now()));

      /*
       * 用 replaceUrl 而不是 pushUrl。
       *
       * pushUrl 会把拍照页留在栈里，于是确认页退回一层只到拍照页
       *（用户确认完却回到拍照页，实测反馈）。
       * 拍照页在拍完之后没有再留在栈里的意义 —— 用户不会想「返回照片选择」，
       * 替换掉它，确认页退回一层就是首页，问题从根上消失。
       */
      router.replaceUrl({ url: 'pages/ResultConfirm' });
    } catch (err) {
      this.handleError(err);
    } finally {
      this.busy = false;
      this.statusText = '';
    }
  }

  /**
   * 是否可以提交。
   *
   * 有照片、或有文字描述，任一即可 —— 这是「纯文字也能记录」的判定点。
   * 两者都空时没有可判断的信息，按钮置灰。
   */
  private canSubmit(): boolean {
    return this.imageUris.length > 0 || this.notes.trim().length > 0;
  }

  /** 主按钮文案：有照片是「识别」，纯文字是「估算」，忙碌时统一显示进度 */
  private primaryLabel(): string {
    if (this.busy) {
      return this.imageUris.length > 0 ? '识别中…' : '估算中…';
    }
    return this.imageUris.length > 0 ? '开始识别' : '估算热量';
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
              Text('拍照识别，或直接写吃了什么')
                .fontSize(13)
                .fontColor(COLOR_TEXT_SUB)
                .textAlign(TextAlign.Center)
              Text(`照片可选，最多 ${MAX_IMAGES} 张；同一餐多拍几张，模型会合并判断`)
                .fontSize(11)
                .fontColor(COLOR_TEXT_SUB)
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .height(180)
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

          // ------------------------------------------------ 吃了什么（照片可选）
          Column({ space: 6 }) {
            Row() {
              Text('吃了什么')
                .fontSize(13)
                .fontColor(COLOR_TEXT_SUB)
              Blank()
              Text(`${this.notes.length}/100`)
                .fontSize(11)
                .fontColor(COLOR_TEXT_SUB)
            }
            .width('100%')

            /*
             * 这段文字现在既可以是「补充说明」，也可以是**唯一依据**：
             * 不拍照、只写一句吃了什么，也能记录（用户要求）。
             * 所以占位提示先说清「不拍照也行」，再举补充说明的例子。
             */
            TextArea({
              text: this.notes,
              placeholder: '不拍照也能记：直接写吃了什么，例如「一碗牛肉面」。\n有照片时这里是补充说明，例如「这碗面只吃了一半」'
            })
              .fontSize(14)
              .height(88)
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

          // 主操作：开始识别 / 估算
          Button({ type: ButtonType.Capsule }) {
            Text(this.primaryLabel())
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
          }
          .width('100%')
          .height(50)
          .backgroundColor(COLOR_PRIMARY)
          // 有照片**或**有描述即可（纯文字也要能记录）
          .enabled(!this.busy && this.canSubmit())
          .opacity(!this.busy && this.canSubmit() ? 1 : 0.5)
          .onClick(() => {
            this.analyze();
          })

          /*
           * 键盘补偿占位。
           *
           * 用户反馈：第一次在「吃了什么」里输入时，键盘会把「估算热量」
           * 这个主按钮挡住 —— 它在滚动区最底部，而键盘弹出后可视高度变小，
           * 按钮正好落在键盘下面。
           * 这里按键盘高度补一段等高空白，把按钮顶到键盘上方。
           */
          if (this.keyboardVp > 0) {
            Row().height(this.keyboardVp)
          }

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
