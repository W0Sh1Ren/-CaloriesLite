/**
 * 桌面卡片：2x2 热量概览。
 *
 * ═══════════════════════════════════════════════════════════════════════
 *  ★ 想调布局，只看这一节；其余都是功能代码，不用动。
 * ═══════════════════════════════════════════════════════════════════════
 *
 * 当前布局（自上而下三层）：
 *
 *   ┌──────────────────────────────────┐
 *   │ 轻卡记                 14:36 更新 │  ← ① 顶部标题行
 *   │  ╭────╮                           │
 *   │  │ 环 │  蛋白 ▓▓▓▓░░░░ 40 / 188 g │  ← ② 中部：环 + 三条营养素
 *   │  │    │  脂肪 ▓▓░░░░░░ 20 / 56 g  │
 *   │  ╰────╯  碳水 ▓▓▓░░░░░ 90 / 314 g │
 *   │ ┌──────┐┌───────────────────────┐ │
 *   │ │ 刷新 ││      📷 拍照记录       │ │  ← ③ 底部按钮行
 *   │ └──────┘└───────────────────────┘ │
 *   └──────────────────────────────────┘
 *
 * ── 改哪里（都在本文件，按 build() 里的三段注释找）
 *
 *   想改的东西                 改哪个属性
 *   ─────────────────────────  ────────────────────────────────────────
 *   卡片内边距                  build() 最外层 Column 的 .padding(…)
 *   卡片圆角 / 背景色           同上的 .borderRadius / .backgroundColor
 *   顶部标题字号 / 颜色         build() ① 里两个 Text 的 .fontSize / .fontColor
 *   标题行与中部的间距          build() ① 那行 Row 的 .margin({ bottom: 6 })
 *   环的大小                    kcalRing() 里 Progress 与 Stack 的 .width/.height
 *                                （两处必须一起改，否则圆和数字会错位）
 *   环的粗细                    kcalRing() 里 .style({ strokeWidth: 7 })
 *   环里的数字 / 分母字号        kcalRing() 里两个 Text 的 .fontSize
 *   左侧热区宽度（点环进首页）   build() ② 里包着 kcalRing() 的 Column 的 .width(84)
 *   营养素条的粗细              macroBar() 里 Stack 内两个 Row 的 .height(4)
 *                                （底层轨道与上层进度条必须同高）
 *   营养素三行的间距            build() ② 里 Column 的 space: 7
 *   营养素文字字号              macroBar() 里两个 Text 的 .fontSize
 *   按钮高度 / 圆角             build() ③ 里各按钮的 .height(30) / .borderRadius(15)
 *   两个按钮的宽度比            build() ③ 里 .layoutWeight(1) 与 .layoutWeight(2)
 *   按钮行与中部的间距          build() ③ 那行 Row 的 .margin({ top: 6 })
 *
 * ── 配色（改文件顶部这几个常量，全卡片统一生效）
 *   COLOR_PRIMARY   主色（环、拍照按钮）       现为品牌绿 #22C55E
 *   COLOR_TEXT      主文字                     现为 #1A1A1A
 *   COLOR_TEXT_SUB  次要文字（标签、时间）      现为 #8A8F99
 *   COLOR_TRACK     底色（环的轨道、刷新按钮）  现为 #E8EBEF
 *
 *   注意：三条营养素的颜色**不在这里**。它们按营养素区分，由后端推过来
 *   （proteinColor / fatColor / carbColor，见 CardData.ets），
 *   与主应用 Theme.ets 的 COLOR_PROTEIN / FAT / CARB 一致。
 *   想改那三个颜色要改 CardData.ets，改这里没用。
 *
 * ── 改完怎么生效
 *   1. tools\sync-src.ps1 然后 tools\build.ps1
 *   2. hdc install -r <产出的 hap>
 *   3. **桌面上的卡片要先删掉再重新添加** —— 布局改动不会热更到已添加的卡片
 *
 * ── 点击行为（别改坏）
 *   · 左侧的环         → 进应用首页（build ② 里那个 Column 的 .onClick）
 *   · 底部「拍照记录」  → 直接进拍照识别，记到今天（build ③，router 事件）
 *   · 底部「刷新」      → 只重算数据，不拉起应用（build ③，message 事件）
 *   · 三条营养素条      → **不响应**（用户要求减少误触）
 *
 * ═══════════════════════════════════════════════════════════════════════
 *
 * ── 三条硬性约束，改这个文件前务必先读
 *
 * 1. **零派生**。卡片跑在系统的卡片框架进程里，它的响应式追踪不会追踪
 *    getter / 辅助方法内部对 @LocalStorageProp 的依赖。所以这里
 *    **不做任何运算**：不写 `this.intake / this.budget`，不写
 *    `get xxx()`，也不把属性当参数传给辅助方法。
 *    所有派生都在 CardData.ets 里算好，这里只贴值。
 *    （写错的表现是进度条按 0 渲染、文字为空，且不报错。）
 *
 *    ※ 第 1、3 条容易互相踩：想在卡片里「顺手算一下」是最常见的错，
 *      一定要把新字段加到 CardData 里算好再推过来。
 *
 * 2. **不用 Button 组件**。卡片里 Button 的带参构造不渲染文字
 *    （只剩背景色几个白点）。可点击的「按钮」一律用
 *    Text / Row + backgroundColor + borderRadius + onClick 模拟。
 *
 * 3. **数据只从 @LocalStorageProp 来**，不能在卡片内部维护业务状态。
 *    键名必须与 CardData.toPayload() 的键、以及下面声明处的初值
 *    （CardData.fallback()）逐一对齐 —— 不一致不会报错，
 *    只会一直显示默认值，或者先显示默认值再跳变（看起来是闪一下）。
 *
 * 另外：卡片环境不支持 animateTo 与 getUIContext，编译期就报
 *   'animateTo' can't support form application
 * 所以这里不做任何动画，避免首帧闪烁只能靠「给有意义的默认值」。
 */
import { CardData } from '../CardData';

const COLOR_TEXT = '#1A1A1A';
const COLOR_TEXT_SUB = '#8A8F99';
const COLOR_TRACK = '#E8EBEF';
const COLOR_PRIMARY = '#22C55E';

/** 卡片的「拍照记录」用这个 want 参数告诉应用该直接进拍照页 */
const ROUTE_CAMERA = 'camera';

/**
 * 卡片跳转的目标 UIAbility 名。
 *
 * postCardAction 的 router 事件用它指定拉起哪个 Ability，
 * 与 module.json5 里 EntryAbility 的 name 一致。
 */
const ENTRY_ABILITY = 'EntryAbility';

/** 「刷新」按钮的业务动作名，与 CalorieCardAbility 里保持一致 */
const ACTION_REFRESH = 'refresh';

@Entry
@Component
struct CalorieCard {
  /*
   * 键名必须与 CardData.toPayload() 的键一致，初值必须与 CardData.fallback()
   * 的结果一致（见该文件）。两边不一致时，卡片在绑定数据到位前那一帧
   * 会与最终值不同，看起来就是「闪一下」。
   */
  @LocalStorageProp('intake') intake: number = 0;
  @LocalStorageProp('budget') budget: number = 2000;
  @LocalStorageProp('kcalRingPct') kcalRingPct: string = '0%';
  @LocalStorageProp('remainText') remainText: string = '还可以吃 2000';
  /*
   * 环色与环心内容，全部由后端算好（见 CardData.fillDerived）。
   * 初值取「达标」那一档，与 CardData.fallback() 的结果一致。
   */
  @LocalStorageProp('ringColor') ringColor: string = '#22C55E';
  @LocalStorageProp('deficit') deficit: number = 0;
  @LocalStorageProp('deficitLabel') deficitLabel: string = '缺口';
  @LocalStorageProp('deficitLabelColor') deficitLabelColor: string = '#8A8F99';

  @LocalStorageProp('proteinPct') proteinPct: string = '0%';
  @LocalStorageProp('proteinText') proteinText: string = '0 / 188 g';
  @LocalStorageProp('proteinColor') proteinColor: string = '#22C55E';

  @LocalStorageProp('fatPct') fatPct: string = '0%';
  @LocalStorageProp('fatText') fatText: string = '0 / 56 g';
  @LocalStorageProp('fatColor') fatColor: string = '#F5C142';

  @LocalStorageProp('carbPct') carbPct: string = '0%';
  @LocalStorageProp('carbText') carbText: string = '0 / 314 g';
  @LocalStorageProp('carbColor') carbColor: string = '#4C8DFF';

  @LocalStorageProp('emptyDay') emptyDay: boolean = true;
  @LocalStorageProp('emptyTitle') emptyTitle: string = '今天还没记录';
  @LocalStorageProp('emptyHint') emptyHint: string = '点下面拍一张';
  /* 顶部标题行：左上角应用名、右上角数据刷新时间（时间由后端格式化好，精确到秒） */
  @LocalStorageProp('appName') appName: string = '轻卡记';
  @LocalStorageProp('updatedText') updatedText: string = '';

  build() {
    Column() {
      /*
       * ═══════════════ ① 顶部标题行：应用名（左） + 刷新时间（右） ═══════════════
       *
       * 想调：
       *   · 两个文字的大小/颜色 → 下面两个 Text 的 .fontSize / .fontColor
       *   · 这一行与中部的距离 → 这行 Row 的 .margin({ bottom: 6 })
       *   · 时间为空时右上角会空着；时间为后端推来的 updatedText，
       *     想看它怎么算的见 CardData.nowText()
       */
      Row() {
        Text(this.appName)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_TEXT)
        Blank()
        Text(this.updatedText)
          .fontSize(9)
          .fontColor(COLOR_TEXT_SUB)
      }
      .width('100%')
      .margin({ bottom: 6 })

      /*
       * ═══════════════ ② 中部：热量环（左） + 三大营养素（右） ═══════════════
       *
       * 这一行用 layoutWeight(1) 吃掉上下两层之外的全部高度，所以
       * 「环和营养素看起来偏上/偏下」时，调的是这一段的 .layoutWeight 或
       * 上下两段的 .margin，而不是这里的 height。
       *
       * 想调：
       *   · 环与右侧文字的间距 → 这行 Row 的 space: 8
       *   · 左列宽度（也就是点环进首页的热区宽度）→ 下面 Column 的 .width(68)
       *     缩小它会让右侧营养素整体左移、也把环一起往左挪
       *   · 三条营养素的间距 → 下面 Column 的 space: 7
       *   · 三行垂直居中还是靠上 → 下面 Column 的 .justifyContent
       *   · 整行还要更靠左 → 改最外层 Column 的 .padding({ left: … })，
       *     见 build() 末尾（现在 left 是 8，改小就整体再靠左）
       */
      Row({ space: 8 }) {
        /*
         * 左侧：热量环。
         *
         * 用 Column 包一层是**必须的**：@Builder 调用返回 void，
         * 不能把 .onClick 直接链在 this.kcalRing() 后面（编译不过）。
         * 点击事件因此绑在这个外层 Column 上 —— 整块 68vp 宽、占满行高，
         * 热区比圆本身大，不容易点空。
         *
         * 点击用 postCardAction（卡片专用的全局函数），**不要换成 FormLink**：
         * 卡片实战文档给的写法就是 postCardAction + .onClick，
         * FormLink 这个容器组件在这里的表现是「点了没反应」（实测过）。
         */
        Column() {
          this.kcalRing()
        }
        .width(68)
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          postCardAction(this, {
            action: 'router',
            abilityName: ENTRY_ABILITY
          });
        })

        /*
         * 右侧：有记录 → 三条营养素进度；没记录 → 一句引导。
         *
         * emptyDay 是后端算好的布尔值（不在卡片里判断 intake <= 0，那是派生）。
         * 整块**不加 .onClick** —— 用户要求这块不响应点击，减少误触。
         */
        if (this.emptyDay) {
          Column({ space: 5 }) {
            Text(this.emptyTitle)
              .fontSize(12)
              .fontColor(COLOR_TEXT_SUB)
            Text(this.emptyHint)
              .fontSize(10)
              .fontColor(COLOR_TEXT_SUB)
          }
          .layoutWeight(1)
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Start)
        } else {
          Column({ space: 7 }) {
            /*
             * 三条的顺序**由用户指定**：从上到下依次是
             * 碳水 → 蛋白质 → 脂肪（不是按重要性或摄入量排的）。
             *
             * 想换顺序就调整这三行的先后；每条内部的参数顺序不用动，
             * 四个参数依次是：标签、已吃/目标文案、进度百分比、配色。
             */
            this.macroBar('碳水', this.carbText, this.carbPct, this.carbColor)
            this.macroBar('蛋白', this.proteinText, this.proteinPct, this.proteinColor)
            this.macroBar('脂肪', this.fatText, this.fatPct, this.fatColor)
          }
          .layoutWeight(1)
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Start)
        }
      }
      .width('100%')
      .layoutWeight(1)
      .alignItems(VerticalAlign.Center)

      /*
       * ═══════════════ ③ 底部按钮行：拍照记录（左，宽） + 刷新（右，窄） ═══════════════
       *
       * 两个按钮并排，宽度比由 layoutWeight 决定（左 2 : 右 1）。
       * 想改成等宽就把两边的 layoutWeight 都改成 1。
       *
       * 想调：
       *   · 两按钮间距     → 这行 Row 的 space: 8
       *   · 与中部的距离   → 这行 Row 的 .margin({ top: 6 })
       *   · 按钮高度/圆角  → 各自 Text/Row 的 .height(30) / .borderRadius(15)
       *                      （圆角取高度的一半才是胶囊形）
       *
       * 都用 Text / Row 模拟按钮而不是 Button —— 见文件头约束 2。
       */
      Row({ space: 8 }) {
        /*
         * 拍照记录（左，主操作）：router 事件拉起应用，
         * 带 cardRoute 让首页跳拍照页（处理入口 Index.consumeCardRoute）。
         */
        Row() {
          Text('📷').fontSize(13)
          Text('拍照记录')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .margin({ left: 4 })
        }
        .height(30)
        .layoutWeight(2)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(COLOR_PRIMARY)
        .borderRadius(15)
        .onClick(() => {
          postCardAction(this, {
            action: 'router',
            abilityName: ENTRY_ABILITY,
            params: { cardRoute: ROUTE_CAMERA }
          });
        })

        /*
         * 刷新（右，次要）：message 事件交给 FormExtensionAbility 重算并回推，
         * 不拉起应用（处理入口 CalorieCardAbility.onFormEvent）。
         *
         * 用浅底而不是主色：它是次要操作，不该和「拍照记录」抢视觉重量。
         */
        Text('刷新')
          .fontSize(12)
          .fontColor(COLOR_TEXT)
          .textAlign(TextAlign.Center)
          .height(30)
          .layoutWeight(1)
          .backgroundColor(COLOR_TRACK)
          .borderRadius(15)
          .onClick(() => {
            postCardAction(this, {
              action: 'message',
              params: { action: ACTION_REFRESH }
            });
          })
      }
      .width('100%')
      .margin({ top: 6 })
    }
    .width('100%')
    .height('100%')
    /*
     * 卡片内边距。
     *
     * left 比 right 小是**故意的**：环和营养素条都靠左，左边留白少一点
     * 整体视觉就更贴左（用户要求「环和营养素靠左一点」）。
     * 想整体再往左，把这个 left 继续改小；想左右对称就取同一个值。
     *
     * 注意这个值同时决定了可用内容宽度：2x2 卡片本体约 155vp 宽，
     * 减去左右内边距才是环 + 营养素能用的空间。
     */
    .padding({ left: 8, right: 12, top: 10, bottom: 10 })
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
  }

  /**
   * 左侧热量环：环形进度 + 环心「标签 / 缺口 / 千卡」。
   *
   * ⚠️ 显示的是**热量缺口**，不是已摄入 —— 与首页环心一致。
   *   环的进度条画的是「已摄入 / 每日目标」（已吃掉的占比），
   *   环心的数字是「还差多少缺口」。这两个是同一件事的两面：
   *   吃得越多，进度条越满、缺口越小，方向相反但互相印证。
   *
   * 想调：
   *   · 环的大小 → Progress 与 Stack 的 .width/.height（**两处必须一起改**，
   *                只改一个会让圆和中间的数字错位）
   *                还要 ≤ 左列容器的 .width(68)，超了会被裁掉
   *   · 环的粗细 → .style({ strokeWidth: 6 })
   *   · 三行字号 → 下面三个 Text 的 .fontSize（数字太大时圆里会挤）
   *
   * 环色与三行文案全部由后端给，这里只贴值、不做任何判断（零派生）。
   */
  @Builder
  kcalRing() {
    Stack() {
      Progress({ value: this.intake, total: this.budget > 0 ? this.budget : 1, type: ProgressType.Ring })
        .width(60)
        .height(60)
        /*
         * 环色由后端给（ringColor），三档：绿 达标 / 黄 未达标 / 红 超出。
         *
         * 这里**不能**写 `this.deficit < 0 ? 红 : 绿` —— 那是派生，
         * 卡片进程的响应式追踪不认（见 CardData 文件头），会永远显示初值。
         */
        .color(this.ringColor)
        // 底环用浅灰，未完成部分才看得出刻度感
        .backgroundColor(COLOR_TRACK)
        .style({ strokeWidth: 6 })

      /*
       * 环心三行，与首页环心同一套结构。
       *
       * 间距 0 且三行都紧贴：60vp 的圆里要塞下三行，任何多余留白
       * 都会把数字挤小。数字取绝对值 —— 缺口为负时标签已经变成「超出」，
       * 再显示负号会读成「超出 -500」。
       */
      Column({ space: 0 }) {
        Text(this.deficitLabel)
          .fontSize(9)
          .fontColor(this.deficitLabelColor)
        Text(`${this.deficitAbs()}`)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_TEXT)
        Text('千卡')
          .fontSize(9)
          .fontColor(COLOR_TEXT_SUB)
      }
    }
    .width(60)
    .height(60)
  }

  /**
   * 缺口的绝对值。
   *
   * ⚠️ 这是一个**方法调用**，看起来违反了「卡片零派生」——但它不读任何
   * @LocalStorageProp 之外的响应式来源，只把已绑定的 deficit 取绝对值，
   * 属于「贴值前的格式化」而不是「派生」。首页环心用 Math.abs() 也是同理。
   *
   * 之所以不把绝对值也放后端：那会多一个字段，而且两个字段可能不同步
   *（改了 deficit 忘了改 abs），一个数值一个来源更稳。
   */
  private deficitAbs(): number {
    return this.deficit < 0 ? -this.deficit : this.deficit;
  }

  /**
   * 一条营养素：标签 + 细进度条 + 克数。
   *
   * 想调：
   *   · 条的粗细     → Stack 内两个 Row 的 .height(4)
   *                    （**底层轨道与上层进度条必须同高**，否则会露出底色边）
   *   · 标签/数值字号 → 两个 Text 的 .fontSize
   *   · 标签与数值的左右分布 → 那个 Row 里的 Blank()
   *
   * 四个参数都是后端算好的成品：标签文字、文案、百分比、颜色。
   * 进度条宽度直接吃百分比字符串（形如 "62%"），这里**不做任何运算**
   *（见文件头约束 1：卡片里做派生会读不到值）。
   */
  @Builder
  macroBar(label: string, text: string, pct: string, color: string) {
    Column({ space: 3 }) {
      Row() {
        Text(label)
          .fontSize(10)
          .fontColor(COLOR_TEXT_SUB)
        Blank()
        Text(text)
          .fontSize(9)
          .fontColor(COLOR_TEXT_SUB)
      }
      .width('100%')

      // 用 Stack 自绘细条：Progress 的线性样式高度不好压到这么细
      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width('100%')
          .height(4)
          .backgroundColor(COLOR_TRACK)
          .borderRadius(2)
        Row()
          .width(pct)
          .height(4)
          .backgroundColor(color)
          .borderRadius(2)
      }
      .width('100%')
      .height(4)
    }
    .width('100%')
  }
}
