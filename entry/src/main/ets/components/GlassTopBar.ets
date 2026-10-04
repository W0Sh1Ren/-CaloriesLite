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
  /** 左上角按钮文字（如 '‹'）。为空则不显示 */
  @Prop leadingGlyph: string = '';
  onLeading: () => void = () => {
  };
  /** 右上角一组步进按钮的文字（如 ['‹','›']）。空数组则不显示 */
  @Prop trailingGlyphs: string[] = [];
  onTrailing: (index: number) => void = () => {
  };
  /** 右上角按钮是否可用（如「今天」时不能再往后翻） */
  @Prop trailingEnabled: boolean[] = [];

  /** 右上角一组按钮的总宽度，用于让标题保持居中 */
  private trailingWidth(): number {
    if (this.trailingGlyphs.length === 0) {
      return 0;
    }
    // 每个 32 + 间距 8，末尾不留间距
    return this.trailingGlyphs.length * 32 + (this.trailingGlyphs.length - 1) * 8;
  }

  build() {
    Column() {
      // 状态栏占位：让标题不会顶到系统时间
      Row().height(AppState.topInset)

      Row({ space: 8 }) {
        if (this.leadingGlyph.length > 0) {
          Button({ type: ButtonType.Circle }) {
            Text(this.leadingGlyph)
              .fontSize(20)
              .fontColor(COLOR_TEXT)
          }
          .width(36)
          .height(36)
          .backgroundColor('#F2FFFFFF')
          .onClick(() => {
            this.onLeading();
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
        .alignItems(this.leadingGlyph.length > 0 ? HorizontalAlign.Center : HorizontalAlign.Start)
        .layoutWeight(1)

        // 右上角步进按钮（首页用它切换日期）
        if (this.trailingGlyphs.length > 0) {
          Row({ space: 8 }) {
            ForEach(this.trailingGlyphs, (glyph: string, index: number) => {
              Button({ type: ButtonType.Circle }) {
                Text(glyph)
                  .fontSize(18)
                  .fontColor(this.isTrailingEnabled(index) ? COLOR_TEXT : '#33000000')
              }
              .width(32)
              .height(32)
              .backgroundColor('#F2FFFFFF')
              .enabled(this.isTrailingEnabled(index))
              .onClick(() => {
                this.onTrailing(index);
              })
            }, (glyph: string, index: number) => `${index}-${glyph}`)
          }
          .width(this.trailingWidth())
        }
      }
      .width('100%')
      .height(TOP_BAR_BODY)
      .padding({ left: PAGE_PAD, right: PAGE_PAD })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    /*
     * 毛玻璃。
     *
     * 用 backdropBlur 而不是 backgroundBlurStyle：后者会按 BlurStyle 档位
     * 一并施加亮度/饱和度调整，在浅色页面上会把整条压成灰板
     * （实测顶栏和底部导航都因此发灰）。backdropBlur 只做背景模糊，
     * 亮度完全由底色决定，这里给 70% 白 → 干净通透的磨砂白。
     */
    .backgroundColor('#B3FFFFFF')
    .backdropBlur(24)
    // 底缘极淡的投影，把顶栏和内容分开但不显生硬
    .shadow({ radius: 12, color: 'rgba(0,0,0,0.03)', offsetX: 0, offsetY: 4 })
  }

  /** 第 index 个右侧按钮是否可用；没传就默认可用 */
  private isTrailingEnabled(index: number): boolean {
    return index < this.trailingEnabled.length ? this.trailingEnabled[index] : true;
  }
}
