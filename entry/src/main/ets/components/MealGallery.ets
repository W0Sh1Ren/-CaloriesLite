/**
 * 一餐的图片预览框。
 *
 * 图片挂在「餐次」这一层，不挂在每道菜上：一次识别可能拍好几张
 * （主菜、汤、饮料各一张），逐条菜各配一张图既冗余又对不上号。
 * 这里把整餐的图片汇总成一个预览框，下面再列这一餐的菜。
 *
 * 多图时左右滑动切换，点击交给父组件打开全屏预览
 * （全屏预览需要盖住整页，放在父组件的 Stack 顶层更合适）。
 */
import { RADIUS } from '../common/Theme';

@Component
export struct MealGallery {
  /** 这一餐的全部图片 */
  @Prop images: string[] = [];
  /** 预览框高度 */
  @Prop frameHeight: number = 190;
  /** 点击某张图，通知父组件打开全屏预览 */
  onZoom: (index: number) => void = () => {
  };

  /** Swiper 当前页，用于右下角页码 */
  @State index: number = 0;

  @Builder
  frame(uri: string, idx: number) {
    Image(uri)
      .width('100%')
      .height('100%')
      .objectFit(ImageFit.Cover)
      .draggable(false)
      .onClick(() => {
        this.onZoom(idx);
      })
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      if (this.images.length === 0) {
        // 没图时给一个等高的浅色占位，卡片高度才稳定
        Column() {
          Text('🍽')
            .fontSize(28)
        }
        .width('100%')
        .height(this.frameHeight)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#F1F3F5')
      } else if (this.images.length === 1) {
        this.frame(this.images[0], 0)
      } else {
        Swiper() {
          ForEach(this.images, (uri: string, idx: number) => {
            this.frame(uri, idx)
          }, (uri: string, idx: number) => `${idx}-${uri}`)
        }
        .width('100%')
        .height(this.frameHeight)
        .loop(false)
        // 用右下角页码代替圆点：图片上放圆点容易被误认为内容
        .indicator(false)
        .onChange((i: number) => {
          this.index = i;
        })
      }

      if (this.images.length > 1) {
        Text(`${this.index + 1} / ${this.images.length}`)
          .fontSize(11)
          .fontColor('#FFFFFF')
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor('#66000000')
          .borderRadius(9)
          .margin({ right: 10, bottom: 10 })
      }
    }
    .width('100%')
    .height(this.frameHeight)
    .borderRadius(RADIUS)
    .clip(true)
  }
}
