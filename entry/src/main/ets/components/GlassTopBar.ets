/**
 * 沉浸式毛玻璃顶栏。
 *
 * 用法：页面根节点用 Stack({ alignContent: Alignment.Top })，
 * 底层放 Scroll（内容顶部留出 topReserve() 的空白），
 * 顶层放本组件并加 .zIndex(1)。这样内容向上滚动经过顶栏时会被模糊掉，
 * 而标题与操作按钮始终清晰。
 *
 * ── 关于模糊强度 ──
 * backgroundBlurStyle 的第二个参数是 BackgroundBlurStyleOptions，
 * 它的字段只有 colorMode / adaptiveColor / scale / blurOptions /
 * policy / inactiveColor —— **没有 blurRadius**
 *（blurRadius 是前景 blur() 的入参）。
 * 所以模糊强度只能选 BlurStyle 档位，BACKGROUND_ULTRA_THICK 就是
 * 系统提供的最厚一档，即「拉满」。
 *
 * ── 关于安全区 ──
 * 状态栏高度由 EntryAbility 在启动时用 window.getWindowAvoidArea 量好，
 * 存进 AppState.topInset（窗口设为全屏布局后必须自行避让）。
 */
import { AppState } from '../common/AppState';
import { CARD_SHADOW, COLOR_TEXT, COLOR_TEXT_SUB, DUR_FAST, PAGE_PAD } from '../common/Theme';

/** 顶栏除掉状态栏之后的自身高度，用于给内容留出避让空间 */
export const TOP_BAR_BODY: number = 62;

/** 内容区顶部需要预留的高度（状态栏 + 顶栏本体） */
export function topReserve(): number {
  return AppState.topInset + TOP_BAR_BODY;
}

@Component
export struct GlassTopBar {
  /** 主标题，如「今天」「记录」 */
  @Prop title: string = '';
  /** 副标题，可为空 */
  @Prop subtitle: string = '';
  /** 左侧返回按钮的文字（如 '‹'）。为空则不显示 */
  @Prop backGlyph: string = '';
  onBack: () => void = () => {
  };
  /** 右侧额外内容的高度占位，保证标题居中 */
  @Prop rightWidth: number = 0;

  build() {
    Column() {
      // 状态栏占位：让标题不会顶到系统时间
      Row().height(AppState.topInset)

      Row() {
        if (this.backGlyph.length > 0) {
          Button({ type: ButtonType.Circle }) {
            Text(this.backGlyph)
              .fontSize(20)
              .fontColor(COLOR_TEXT)
          }
          .width(36)
          .height(36)
          .backgroundColor('#FFFFFF')
          .shadow(CARD_SHADOW)
          .onClick(() => {
            this.onBack();
          })
        }

        Column({ space: 2 }) {
          Text(this.title)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLOR_TEXT)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.subtitle.length > 0) {
            Text(this.subtitle)
              .fontSize(12)
              .fontColor(COLOR_TEXT_SUB)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .alignItems(this.backGlyph.length > 0 ? HorizontalAlign.Center : HorizontalAlign.Start)
        .layoutWeight(1)

        // 右侧对称占位，避免标题因左侧按钮而偏移
        if (this.backGlyph.length > 0) {
          Row().width(36).height(36)
        }
      }
      .width('100%')
      .height(TOP_BAR_BODY)
      .padding({ left: PAGE_PAD, right: PAGE_PAD })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    // 半透明底 + 最厚一档背景模糊 = 毛玻璃
    .backgroundColor('#99FFFFFF')
    .backgroundBlurStyle(BlurStyle.BACKGROUND_ULTRA_THICK, {
      colorMode: ThemeColorMode.LIGHT,
      adaptiveColor: AdaptiveColor.DEFAULT,
      scale: 1.0
    })
    // 底缘极淡的投影，把顶栏和内容分开但不显生硬
    .shadow({ radius: 12, color: 'rgba(0,0,0,0.03)', offsetX: 0, offsetY: 4 })
  }
}
