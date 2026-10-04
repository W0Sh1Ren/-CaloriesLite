/**
 * 桌面卡片：2x2 热量概览。
 *
 * 布局：
 *   ┌──────────────────────────┐
 *   │   ╭───╮   蛋白 ▓▓▓░░ 40/56│
 *   │   │环 │   脂肪 ▓▓░░░ 20/56│
 *   │   ╰───╯   碳水 ▓▓▓▓░ 90/200│
 *   ├──────────────────────────┤
 *   │        拍照记录           │
 *   └──────────────────────────┘
 *
 * 点击「拍照记录」→ 直接进应用的拍照识别；点其它位置 → 只进首页。
 *
 * 数据来自 CalorieCardAbility 的 formBindingData：卡片进程会把其中的
 * 键值写进 LocalStorage，UI 用 @LocalStorageProp 按**同名键**读取。
 * 所以下面的属性名必须与 ability 里 data['...'] 的键名一一对应，
 * 改名要两边同时改（键名不一致时不会报错，只会一直显示默认值）。
 *
 * 卡片里**不做**任何存储读取：卡片 UI 每次刷新都会重建，
 * 在里面读不到就整块空白，兜底统一放在 ability 里。
 */

const COLOR_PRIMARY = '#22C55E';
const COLOR_TEXT = '#1A1A1A';
const COLOR_TEXT_SUB = '#8A8F99';
const COLOR_TRACK = '#E8EBEF';
const COLOR_BG = '#F5F8F6';

/** 卡片的「拍照记录」用这个 want 参数告诉应用该直接进拍照页 */
const ROUTE_CAMERA = 'camera';

@Entry
@Component
struct CalorieCard {
  /*
   * 键名必须与 CalorieCardAbility.buildData() 里的键一致。
   *
   * 默认值刻意与 ability 的兜底值保持一致（预算 2000、营养素目标按
   * macroTargetFor(2000) 算出来），不要全填 0：
   * 绑定数据到位前会先渲染一帧，填 0 的话用户看到的是「闪一下 0 / 0」。
   */
  @LocalStorageProp('intake') intake: number = 0;
  @LocalStorageProp('budget') budget: number = 2000;
  @LocalStorageProp('protein') protein: number = 0;
  @LocalStorageProp('fat') fat: number = 0;
  @LocalStorageProp('carb') carb: number = 0;
  @LocalStorageProp('proteinTarget') proteinTarget: number = 188;
  @LocalStorageProp('fatTarget') fatTarget: number = 56;
  @LocalStorageProp('carbTarget') carbTarget: number = 314;

  /*
   * 这里**不能**做首帧淡入（本来想用 opacity + animateTo 盖住默认值那一帧）：
   * 卡片环境不支持 animateTo 与 getUIContext，编译期就报
   *   'animateTo' can't support form application
   *   'getUIContext' can't support form application
   * 所以避免闪烁只能靠「给有意义的默认值」——
   * 见上面各字段的初值与 CalorieCardAbility 的 DEFAULT_BUDGET。
   */

  /** 完成比例 0~1，用于环形与营养条 */
  private static ratio(now: number, target: number): number {
    if (target <= 0) {
      return 0;
    }
    const r: number = now / target;
    return r > 1 ? 1 : r;
  }

  build() {
    Column() {
      // ------------------------------------------------ 上半：环 + 三大营养素
      Row({ space: 10 }) {
        this.ring()

        Column({ space: 9 }) {
          this.macroBar('蛋白', this.protein, this.proteinTarget)
          this.macroBar('脂肪', this.fat, this.fatTarget)
          this.macroBar('碳水', this.carb, this.carbTarget)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .layoutWeight(1)
      .alignItems(VerticalAlign.Center)

      Divider().color(COLOR_TRACK).margin({ top: 6, bottom: 6 })

      // ------------------------------------------------ 下半：拍照记录
      /*
       * FormLink 是卡片专用的跳转组件（普通 router 在卡片里不可用）。
       * 带 params.cardRoute='camera'，EntryAbility 读到后会让首页跳拍照页；
       * 卡片其它区域不带参数，落到首页即可。
       */
      FormLink({
        action: 'router',
        abilityName: 'EntryAbility',
        params: { cardRoute: ROUTE_CAMERA }
      }) {
        Row() {
          Text('📷').fontSize(13)
          Text('拍照记录')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .margin({ left: 5 })
        }
        .width('100%')
        .height(32)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(COLOR_PRIMARY)
        .borderRadius(10)
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding(12)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
  }

  /** 左侧热量环：环形进度 + 中心数字 */
  @Builder
  ring() {
    Stack() {
      Progress({ value: this.intake, total: this.budget > 0 ? this.budget : 1, type: ProgressType.Ring })
        .width(74)
        .height(74)
        .color(COLOR_PRIMARY)
        // 底环用浅灰，未完成部分才看得出刻度感
        .backgroundColor(COLOR_TRACK)
        .style({ strokeWidth: 7 })

      Column({ space: 1 }) {
        Text(`${this.intake}`)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_TEXT)
        Text(`/ ${this.budget}`)
          .fontSize(9)
          .fontColor(COLOR_TEXT_SUB)
      }
    }
    .width(74)
    .height(74)
  }

  /** 一条营养素：标签 + 细进度条 + 克数 */
  @Builder
  macroBar(label: string, now: number, target: number) {
    Column({ space: 3 }) {
      Row() {
        Text(label)
          .fontSize(10)
          .fontColor(COLOR_TEXT_SUB)
        Blank()
        Text(`${now} / ${target} g`)
          .fontSize(9)
          .fontColor(COLOR_TEXT_SUB)
      }
      .width('100%')

      // 用 Stack 自绘细条：Progress 的线性样式高度不好压到这么细
      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(4)
          .backgroundColor(COLOR_BG)
          .borderRadius(2)
        Row()
          .width(`${CalorieCard.ratio(now, target) * 100}%`)
          .height(4)
          .backgroundColor(COLOR_PRIMARY)
          .borderRadius(2)
      }
      .width('100%')
      .height(4)
    }
    .width('100%')
  }
}
