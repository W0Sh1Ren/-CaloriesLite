/**
 * 一餐的图片预览框。
 *
 * 图片挂在「餐次」这一层，不挂在每道菜上：一次识别可能拍好几张
 * （主菜、汤、饮料各一张），逐条菜各配一张图既冗余又对不上号。
 * 这里把整餐的图片汇总成一个预览框，下面再列这一餐的菜。
 *
 * 多图时左右滑动切换，右下角显示页码。
 * 不做点击放大——图片本身已经够大（整宽 x 190vp），
 * 全屏预览在这个场景里用不上，反而多一层交互负担。
 */
import { RADIUS } from '../common/Theme';

@Component
export struct MealGallery {
  /** 这一餐的全部图片（调用方需保证已去重） */
  @Prop images: string[] = [];
  /** 预览框高度 */
  @Prop frameHeight: number = 190;

  /** Swiper 当前页，用于右下角页码 */
  @State index: number = 0;

  @Builder
  frame(uri: string) {
    Image(uri)
      .width('100%')
      .height('100%')
      .objectFit(ImageFit.Cover)
      .draggable(false)
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
        this.frame(this.images[0])
      } else {
        Swiper() {
          ForEach(this.images, (uri: string, idx: number) => {
            this.frame(uri)
          }, (uri: string, idx: number) => `${idx}-${uri}`)
        }
        .width('100%')
        .height(this.frameHeight)
        .loop(false)
        // 用右下角页码代替圆点：图片上放圆点容易被误认成内容
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
