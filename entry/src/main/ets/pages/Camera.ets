/**
 * 拍照识别页。
 *
 * 流程：拍照/选图 → 压缩 → 调 AI 视觉识别 → 查表折算 → 跳结果确认页。
 * 全程在本地压缩后才上传，图片不会以原图尺寸发出去。
 */
import { router, promptAction, KeyboardAvoidMode } from '@kit.ArkUI';
import { HdsNavigation, HdsNavigationTitleMode, ScrollEffectType, hdsMaterial } from '@kit.UIDesignKit';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { AiConfig, MealType } from '../model/Types';
import { guessMealType } from '../model/Enums';
import { hourOf } from '../common/DateUtil';
import { SettingsRepo } from '../service/SettingsRepo';
import { ImageService, PreparedImage, ImageError } from '../service/ImageService';
import { VisionService, VisionResult, VisionError } from '../service/VisionService';
import { PermissionUtil } from '../common/PermissionUtil';
import { AppState, PendingResult } from '../common/AppState';
import { CARD_SHADOW, COLOR_BG, COLOR_CARD, COLOR_DIVIDER, COLOR_PRIMARY, COLOR_TEXT, COLOR_TEXT_SUB, COLOR_WARN, DUR_MEAL_EXPAND, GAP, INPUT_PLACEHOLDER, INPUT_TEXT, PAGE_PAD, RADIUS  } from '../common/Theme';

const DOMAIN = 0x0000;

/** 空状态引导区的完整高度（vp），收起时插值到 0 */
const HINT_FULL_H: number = 180;

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
   * 上一次进入本页时选中的餐次。
   *
   * 从记录页给某一天补记时，AppState.targetMeal 会先被设成那一天的餐次；
   * 这里用它做初值，让「补记」也能落在正确的餐次上，
   * 而不是靠当前时间猜（猜出来的默认值对补记场景没有意义）。
   * 识别成功后会按识别时刻的真实餐次覆盖它。
   */
  @State meal: MealType = MealType.LUNCH;

  /**
   * 空状态图片区的高度与透明度（vp）。
   *
   * 输入时在 180 ↔ 0 之间插值，配合透明度做淡出淡入。
   * 不能靠条件渲染切换：那样没有中间帧、观感是硬闪
   *（详见 docs/展开动画3.0.md 的结论）。
   */
  @State hintH: number = HINT_FULL_H;
  @State hintAlpha: number = 1;

  aboutToAppear(): void {
    // 进来就把目标日期固定下来：供识别结果页与返回首页使用
    this.meal = AppState.targetMeal;
    hilog.info(DOMAIN, 'CalorieLite', 'camera for day=%{public}s meal=%{public}d',
      AppState.effectiveTargetDay(), this.meal);
    /*
     * 键盘避让改成 RESIZE（页面**重新排版**），默认的 OFFSET 是整体上移。
     *
     * 用户反馈「输入法把估算热量按钮挡住」。实测根因：
     * OFFSET 模式下系统只把 WindowScene 压扁（2832 → 1733），
     * 但页面内部仍按原高度排版 —— 底栏被算在 y=2685，落在键盘后面。
     * 换成 RESIZE 后页面按新高度重新排版，底栏自然回到可视区底部。
     *
     * 顺带说明：参考记录页的体重输入框之所以没这个问题，
     * 是因为那里输入框在长滚动区中部，OFFSET 上移后本来就在键盘上方。
     */
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
  }

  private uiContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  /**
   * 输入状态切换时，带动画地收起 / 展开上方的空状态引导。
   *
   * 高度与透明度在同一个 animateTo 里插值，两端都是数字，
   * 所以有中间帧；时长与缓动沿用项目里餐次折叠那套（DUR_MEAL_EXPAND + EaseInOut），
   * 手感保持一致。
   */
  private setTyping(on: boolean): void {
    this.getUIContext().animateTo({
      duration: DUR_MEAL_EXPAND,
      curve: Curve.EaseInOut
    }, () => {
      this.hintH = on ? 0 : HINT_FULL_H;
      this.hintAlpha = on ? 0 : 1;
    });
  }

  /**
   * 离开本页：如果用户没走完识别流程（直接返回），
   * 就把「要记到哪一天」清掉，避免影响下一次正常拍照记录。
   * 走完流程时确认页已经消费过它，这里清掉也无害。
   */
  aboutToDisappear(): void {
    /*
     * 还原成系统默认的 OFFSET，避免影响其它页面。
     * 键盘避让模式是「页」级的全局设置，不回退的话，
     * 从这一页返回后首页也会变成 RESIZE。
     */
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.OFFSET);
    if (AppState.pending === null) {
      AppState.clearTargetDay();
    }
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
    HdsNavigation() {
    Column() {
      Scroll() {
        Column({ space: GAP }) {
          // ------------------------------------------------ 图片区
          if (this.imageUris.length === 0) {
            /*
             * 空状态引导区：**始终挂载**，只动高度与透明度。
             *
             * 不要用 if (typing) 条件渲染 —— 那样高度是瞬间从 180 跳到 0，
             * 观感是硬闪（本项目在餐次折叠、个人情况展开上都踩过这个坑，
             * 见 docs/展开动画3.0.md）。
             * 始终挂载 + .height() 在数字之间插值，才有中间帧。
             * clip(true) 负责把超出的内容裁掉，视觉上就是「收起来」。
             *
             * 收起它是因为：键盘弹起后可视高度只剩约 450vp，
             * 这块 180vp 的引导会把输入框和「估算热量」一起挤出视野。
             */
            Column({ space: 8 }) {
              Text('📷')
                .fontSize(44)
              Text('拍照识别，或直接写吃了什么')
                .fontSize(13)
                .fontColor(COLOR_TEXT_SUB())
                .textAlign(TextAlign.Center)
              Text(`照片可选，最多 ${MAX_IMAGES} 张；同一餐多拍几张，模型会合并判断`)
                .fontSize(11)
                .fontColor(COLOR_TEXT_SUB())
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .height(this.hintH)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(COLOR_CARD())
            .borderRadius(RADIUS)
            .shadow(CARD_SHADOW)
            .clip(true)
            .opacity(this.hintAlpha)
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
                    Text('+').fontSize(28).fontColor(COLOR_TEXT_SUB())
                    Text('再加一张').fontSize(11).fontColor(COLOR_TEXT_SUB())
                  }
                  .width(150)
                  .height(150)
                  .justifyContent(FlexAlign.Center)
                  .backgroundColor(COLOR_CARD())
                  .borderRadius(14)
                  .border({ width: 1, color: COLOR_DIVIDER(), style: BorderStyle.Dashed })
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
                .fontColor(COLOR_TEXT_SUB())
              Blank()
              Text(`${this.notes.length}/100`)
                .fontSize(11)
                .fontColor(COLOR_TEXT_SUB())
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
              .backgroundColor(COLOR_BG())
              .borderRadius(10)
              .maxLength(100)
              .onChange((v: string) => {
                this.notes = v;
              })
              // 聚焦/失焦：带动画地收起或展开上方那块空状态引导
              .onFocus(() => {
                this.setTyping(true);
              })
              .onBlur(() => {
                this.setTyping(false);
              })
          }
          .width('100%')
          .padding(14)
          .backgroundColor(COLOR_CARD())
          .borderRadius(RADIUS)
          .shadow(CARD_SHADOW)

          /*
           * ── 操作按钮：紧跟输入卡片，中间不隔任何东西
           *
           * 曾经把这一组放在滚动区之外的固定底栏，结果键盘弹起时
           * 底栏**压住了输入框**（用户截图反馈）。
           * 现在放回滚动流、紧贴输入卡片：按钮和输入框是一体的，
           * 键盘弹起时整页一起动（配合 RESIZE 避让模式重新排版），
           * 两者始终相邻、互不遮挡。
           * 错误提示与加载状态挪到按钮**之后**，避免把输入框和按钮隔开。
           */
          Row({ space: 10 }) {
            Button({ type: ButtonType.Capsule }) {
              Text('拍照').fontSize(16).fontColor(COLOR_TEXT())
            }
            .layoutWeight(1)
            .height(48)
            .backgroundColor(COLOR_CARD())
            .enabled(!this.busy)
            .onClick(() => {
              this.onTakePhoto();
            })

            Button({ type: ButtonType.Capsule }) {
              Text('相册').fontSize(16).fontColor(COLOR_TEXT())
            }
            .layoutWeight(1)
            .height(48)
            .backgroundColor(COLOR_CARD())
            .enabled(!this.busy)
            .onClick(() => {
              this.onPickGallery();
            })
          }
          .width('100%')

          Button({ type: ButtonType.Capsule }) {
            Text(this.primaryLabel())
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
          }
          .width('100%')
          .height(50)
          .backgroundColor(COLOR_PRIMARY())
          // 有照片**或**有描述即可（纯文字也要能记录）
          .enabled(!this.busy && this.canSubmit())
          .opacity(!this.busy && this.canSubmit() ? 1 : 0.5)
          .onClick(() => {
            this.analyze();
          })

          // 错误提示
          if (this.errorText.length > 0) {
            Row({ space: 8 }) {
              Text('!')
                .fontSize(14)
                .fontColor(COLOR_WARN())
                .fontWeight(FontWeight.Bold)
              Text(this.errorText)
                .fontSize(13)
                .fontColor(COLOR_WARN())
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
                .color(COLOR_PRIMARY())
              Text(this.statusText)
                .fontSize(13)
                .fontColor(COLOR_TEXT_SUB())
                .layoutWeight(1)
            }
            .width('100%')
            .padding(14)
            .backgroundColor(COLOR_CARD())
            .borderRadius(RADIUS)
          }

          // ------------------------------------------------ 说明 / 配置提示
          if (!SettingsRepo.isAiReady()) {
            Column({ space: 8 }) {
              Text('识别功能还没配置')
                .fontSize(14)
                .fontColor(COLOR_TEXT())
              Text('需要填入你自己的 AI 接口地址、API Key 和模型名才能识别')
                .fontSize(12)
                .fontColor(COLOR_TEXT_SUB())
              Button({ type: ButtonType.Capsule }) {
                Text('去配置').fontSize(14).fontColor(Color.White)
              }
              .height(38)
              .backgroundColor(COLOR_PRIMARY())
              .onClick(() => {
                this.goAiSettings();
              })
            }
            .width('100%')
            .padding(16)
            .backgroundColor(COLOR_CARD())
            .borderRadius(RADIUS)
            .alignItems(HorizontalAlign.Start)
          } else {
            Column({ space: 6 }) {
              Text(`当前模型：${SettingsRepo.loadAiConfig().model}`)
                .fontSize(12)
                .fontColor(COLOR_TEXT_SUB())
                .width('100%')
              Text('照片只会在本机压缩后发送到 DeepSeek')
                .fontSize(12)
                .fontColor(COLOR_TEXT_SUB())
                .width('100%')
            }
            .width('100%')
          }

          Row().height(16)
        }
        .width('100%')
        .padding({ left: PAGE_PAD, right: PAGE_PAD, top: AppState.contentTopOffset, bottom: 16 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      // 滑到顶/底后继续滑会拉出空白并回弹 —— 与首页同一套手感
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BG())
    }
    .titleBar({
      content: {
        title: { mainTitle: '拍照识别' },
        backIcon: {
          icon: $r('sys.symbol.chevron_backward'),
          label: '返回',
          action: () => {
            router.back();
          }
        }
      },
      style: {
        scrollEffectOpts: {
          // 关掉「随滚动动态生效」，让标题栏恒定透明（与首页口径一致）
          enableScrollEffect: false,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      },
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: false
    })
    .hideBackButton(false)
    .titleMode(HdsNavigationTitleMode.MINI)
    .width('100%')
    .height('100%')
  }
}
