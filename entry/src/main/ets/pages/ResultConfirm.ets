/**
 * 识别结果确认页。
 *
 * 识别出来的每一条都可以改名字、克重、餐次，确认后才写进记录，
 * 避免 AI 估错直接污染当天数据。
 */
import { router, promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { inputMethod } from '@kit.IMEKit';

import { AiConfig, FoodDraft, FoodRecord, FoodSource, MealType } from '../model/Types';
import { MEAL_ORDER, mealTypeLabel } from '../model/Enums';
import { todayKey } from '../common/DateUtil';
import { makeId } from '../common/JsonUtil';
import { FoodRepo } from '../service/FoodRepo';
import { DailyService } from '../service/DailyService';
import { SettingsRepo } from '../service/SettingsRepo';
import { VisionService, VisionResult } from '../service/VisionService';
import { AppState, PendingResult } from '../common/AppState';
import { CARD_SHADOW, COLOR_BG, COLOR_CARD, COLOR_DIVIDER, COLOR_OK, COLOR_PRIMARY, COLOR_TEXT, COLOR_TEXT_SUB, COLOR_WARN, GAP, INPUT_PLACEHOLDER, INPUT_TEXT, PAGE_PAD, RADIUS } from '../common/Theme';

const DOMAIN = 0x0000;

/** 一轮对话：用户说了什么、模型回了什么 */
class ChatTurn {
  ask: string = '';
  reply: string = '';

  constructor(ask: string, reply: string) {
    this.ask = ask;
    this.reply = reply;
  }
}

/** 可编辑的草稿行 */
@Observed
class EditableDraft {
  name: string = '';
  gramsText: string = '';
  kcal: number = 0;
  protein: number = 0;
  fat: number = 0;
  carb: number = 0;
  confidence: string = '';
  source: FoodSource = FoodSource.AI;
  note: string = '';
  /** 每 100 克的营养密度，用于改克重时按比例重算 */
  kcalPer100g: number = 0;
  proteinPer100g: number = 0;
  fatPer100g: number = 0;
  carbPer100g: number = 0;

  constructor(draft: FoodDraft) {
    this.name = draft.name;
    this.gramsText = `${draft.grams}`;
    this.kcal = draft.kcal;
    this.protein = draft.protein;
    this.fat = draft.fat;
    this.carb = draft.carb;
    this.confidence = draft.confidence;
    this.source = draft.source;
    this.note = draft.note;
    if (draft.grams > 0) {
      const ratio: number = 100 / draft.grams;
      this.kcalPer100g = draft.kcal * ratio;
      this.proteinPer100g = draft.protein * ratio;
      this.fatPer100g = draft.fat * ratio;
      this.carbPer100g = draft.carb * ratio;
    }
  }

  grams(): number {
    const v: number = Number.parseFloat(this.gramsText);
    return Number.isNaN(v) || v <= 0 ? 0 : Math.round(v);
  }

  /** 改完克重后按比例重算全部营养值；没有基准值时保持原样 */
  recompute(): void {
    if (this.kcalPer100g <= 0) {
      return;
    }
    const ratio: number = this.grams() / 100;
    this.kcal = Math.round(this.kcalPer100g * ratio);
    this.protein = round1(this.proteinPer100g * ratio);
    this.fat = round1(this.fatPer100g * ratio);
    this.carb = round1(this.carbPer100g * ratio);
  }
}

/** 保留一位小数 */
function round1(v: number): number {
  return Math.round(v * 10) / 10;
}

@Entry
@Component
struct ResultConfirm {
  @State drafts: EditableDraft[] = [];
  @State imageUris: string[] = [];
  /** 用户手写的补充说明（已随请求发给模型），结果页回显供核对 */
  @State userNotes: string = '';
  @State overallNote: string = '';
  @State model: string = '';
  @State meal: MealType = MealType.LUNCH;

  /*
   * ── 对话调整（用户要求：上传之后给用户和模型聊天的机会，实时调整热量）
   *
   * chatLog 只存「聊了什么」，用于显示；
   * 真正的依据始终是 drafts —— 每次模型返回都整体替换 drafts，
   * 于是合计热量、卡片内容会当帧刷新。
   */
  @State chatLog: ChatTurn[] = [];
  @State askText: string = '';
  @State revising: boolean = false;

  aboutToAppear(): void {
    const pending: PendingResult | null = AppState.pending;
    if (pending === null) {
      // 没有待确认数据（例如异常返回），直接退回上一页
      promptAction.showToast({ message: '没有待确认的识别结果' });
      router.back();
      return;
    }
    const rows: EditableDraft[] = [];
    for (const d of pending.drafts) {
      rows.push(new EditableDraft(d));
    }
    this.drafts = rows;
    this.imageUris = pending.imageUris;
    this.userNotes = pending.userNotes;
    this.overallNote = pending.overallNote;
    this.model = pending.model;
    this.meal = AppState.targetMeal;
  }

  private totalKcal(): number {
    let sum: number = 0;
    for (const d of this.drafts) {
      sum += d.kcal;
    }
    return Math.round(sum);
  }

  /** 把当前明细回写成 FoodDraft[]，供 revise 作为上下文发给模型 */
  private currentDrafts(): FoodDraft[] {
    const out: FoodDraft[] = [];
    for (const d of this.drafts) {
      out.push(new FoodDraft(
        d.name, this.gramsOf(d), d.kcal, d.protein, d.fat, d.carb,
        d.confidence, d.source, d.note
      ));
    }
    return out;
  }

  /** 克重文本框转数字；非法输入按 0 处理（保存前另有校验） */
  private gramsOf(d: EditableDraft): number {
    const v: number = Number.parseFloat(d.gramsText);
    return Number.isNaN(v) ? 0 : v;
  }

  /**
   * 把用户这句话发给模型，按返回结果刷新明细。
   *
   * 实时性来自这里：模型返回后**整体替换 drafts**，
   * 于是合计热量、逐条卡片、营养素当帧就变，不需要用户手动改。
   * 同时把新明细写回 AppState.pending，返回再进来不会丢。
   */
  private async ask(): Promise<void> {
    const text: string = this.askText.trim();
    if (text.length === 0 || this.revising) {
      return;
    }
    /*
     * 不要求 drafts 非空：条目被删光后仍要能聊天
     *（用户要求「记录删完了也可以聊天，不局限于修改，也可以添加」）。
     * 空列表发给模型时上下文是「（当前没有任何条目）」，
     * 模型据此新增即可。
     */
    this.revising = true;
    /*
     * 关键：**发请求之前**就收起输入法与焦点。
     *
     * 放在 await 之后是错的（上一版就是这样）：模型要一秒到十几秒才回，
     * 这期间焦点一直留在聊天输入框上、键盘也一直弹着，
     * 用户看到的就是「点了发送，焦点还在菜品/聊天框，等回复才收起」。
     */
    this.hideKeyboard();
    try {
      const config: AiConfig = SettingsRepo.loadAiConfig();
      const result: VisionResult =
        await VisionService.revise(config, this.currentDrafts(), text);

      const rows: EditableDraft[] = [];
      for (const d of result.drafts) {
        rows.push(new EditableDraft(d));
      }
      this.drafts = rows;
      // 回写，保证返回再进来看到的是改过之后的内容
      const pending: PendingResult | null = AppState.pending;
      if (pending !== null) {
        pending.drafts = result.drafts;
        pending.overallNote = result.overallNote;
      }
      this.overallNote = result.overallNote;

      const next: ChatTurn[] = this.chatLog.slice();
      next.push(new ChatTurn(text, result.overallNote));
      this.chatLog = next;
      this.askText = '';
    } catch (err) {
      const e: Error = err as Error;
      const msg: string = e.message.length > 0 ? e.message : '调整失败，再试一次';
      promptAction.showToast({ message: msg });
      hilog.error(DOMAIN, 'CalorieLite', 'revise failed: %{public}s', msg);
    } finally {
      this.revising = false;
    }
  }

  /**
   * 收起键盘并取消焦点。
   *
   * 点发送时立刻调用（在发请求之前，不能等回复 —— 模型要几秒才回，
   * 那期间键盘一直挡着）。
   *
   * 两步：requestFocus(null) 取消焦点，结束输入会话把键盘收下去。
   * 之前试过把焦点转到别的节点，会让框架再挪到下一个输入框、键盘重弹，
   * 直接取消焦点最干净。
   *
   * 失败只记日志：这是体验优化，不该影响主流程。
   */
  private hideKeyboard(): void {
    try {
      // focusControl 是全局命名空间（SDK 里 declare namespace），不能 import
      focusControl.requestFocus(null);
    } catch (err) {
      hilog.warn(DOMAIN, 'CalorieLite', 'requestFocus(null) failed');
    }
    try {
      inputMethod.getController().stopInputSession()
        .catch((e: Error) => {
          hilog.warn(DOMAIN, 'CalorieLite', 'stopInputSession failed: %{public}s', e.message);
        });
    } catch (err) {
      hilog.warn(DOMAIN, 'CalorieLite', 'inputMethod unavailable');
    }
  }

  /** 置信度对应的提示色与文案 */
  private confidenceLabel(level: string): string {
    if (level === 'high') {
      return '较可信';
    }
    if (level === 'medium') {
      return '一般';
    }
    return '不确定';
  }

  private confidenceColor(level: string): string {
    if (level === 'high') {
      return COLOR_OK;
    }
    if (level === 'medium') {
      return COLOR_PRIMARY;
    }
    return COLOR_WARN;
  }

  /** 删除某一行 */
  private removeRow(index: number): void {
    const next: EditableDraft[] = [];
    for (let i = 0; i < this.drafts.length; i++) {
      if (i !== index) {
        next.push(this.drafts[i]);
      }
    }
    this.drafts = next;
  }

  /** 全部写入记录 */
  private confirm(): void {
    if (this.drafts.length === 0) {
      promptAction.showToast({ message: '没有可保存的条目' });
      return;
    }
    /*
     * 记到「本次的目标日期」而不是今天。
     *
     * 从记录页给某一天补记时，AppState.targetDay 已被设为那一天；
     * 平时（首页直接拍照）它是空串，等价于今天。
     * 原来这里写死 todayKey()，导致不管从哪天进去补记都记到当天（用户反馈的 bug）。
     */
    const day: string = AppState.effectiveTargetDay();
    const now: number = Date.now();
    // 整组图片写进每条记录：详情页要支持一餐多图滑动浏览，
    // 只留第一张的话其余照片就白拍了。
    const images: string[] = this.imageUris.slice();
    const records: FoodRecord[] = [];

    for (const d of this.drafts) {
      const grams: number = d.grams();
      if (grams <= 0 || d.kcal <= 0) {
        promptAction.showToast({ message: `「${d.name}」缺少克重或热量，请补全后再保存` });
        return;
      }
      const rec: FoodRecord = new FoodRecord(
        makeId(), day, now, this.meal, d.name, grams, d.kcal,
        d.protein, d.fat, d.carb, d.source, images.length > 0 ? images[0] : '', d.note
      );
      rec.imageUris = images;
      records.push(rec);
    }

    FoodRepo.addMany(records);
    AppState.clearPending();
    AppState.needRefreshHome = true;
    // 显式通知全局：首页/记录页绑定的汇总值当帧就会更新，
    // 不用等页面生命周期回调（这正是「必须退出重进才显示」的根因）
    AppState.mirrorToday(DailyService.summaryOf(day));
    AppState.notifyDataChanged();
    promptAction.showToast({ message: `已记录 ${records.length} 项，共 ${this.totalKcal()} 千卡` });

    /*
     * 退回一层即可回首页。
     *
     * 关键在 Camera 那边改用了 replaceUrl：页面栈由
     *   [Index, Camera, ResultConfirm]
     * 变成
     *   [Index, ResultConfirm]
     * 所以一次普通的 back() 就落到 Index 上。
     *
     * 之前试过三个「一次退两层」的写法，全部无效，记下来避免重走：
     *   back(2)                      —— index 语义不是「退几层」，实测无效
     *   back({ url: 'pages/Index' }) —— 目标 URL 不在栈里时不执行任何操作
     *   back({ url: '/' })           —— 同样匹配不到，也是不执行任何操作
     * 结论：与其想办法「退两层」，不如让栈里根本不需要退两层。
     */
    router.back();
  }

  /**
   * 对话调整面板。
   *
   * 放在明细下面：先看清模型给了什么，再决定要不要改。
   * 所有返回都会整体替换 drafts，所以这里的回复与上面的卡片是联动的。
   */
  @Builder
  chatPanel() {
    Column({ space: 10 }) {
      Row({ space: 6 }) {
        Text('和模型聊聊')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_TEXT)
        Text('可以改，也可以直接加')
          .fontSize(11)
          .fontColor(COLOR_TEXT_SUB)
          .layoutWeight(1)
      }
      .width('100%')

      // 历史对话：只回显，不参与计算
      if (this.chatLog.length > 0) {
        Column({ space: 10 }) {
          ForEach(this.chatLog, (t: ChatTurn, i: number) => {
            Column({ space: 6 }) {
              // 用户的话：靠右、浅绿底
              Row() {
                Blank()
                Text(t.ask)
                  .fontSize(13)
                  .fontColor(COLOR_TEXT)
                  .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                  .backgroundColor('#1A22C55E')
                  .borderRadius(10)
                  .constraintSize({ maxWidth: '80%' })
              }
              .width('100%')

              // 模型的回答：靠左、浅灰底
              if (t.reply.length > 0) {
                Row() {
                  Text(t.reply)
                    .fontSize(12)
                    .fontColor(COLOR_TEXT_SUB)
                    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                    .backgroundColor(COLOR_BG)
                    .borderRadius(10)
                    .constraintSize({ maxWidth: '80%' })
                  Blank()
                }
                .width('100%')
              }
            }
            .width('100%')
          }, (t: ChatTurn, i: number) => `${i}-${t.ask}`)
        }
        .width('100%')
      }

      /*
       * 条目被删光后的引导。
       *
       * 这里刻意不挡住输入：删完了仍然可以继续聊
       *（「再加一碗米饭」），只是给一句提示说明现在的状态。
       */
      if (this.drafts.length === 0) {
        Text('当前没有条目了。可以直接让模型加，例如「再加一碗米饭」')
          .fontSize(11)
          .fontColor(COLOR_TEXT_SUB)
          .width('100%')
      }

      // 输入行
      Row({ space: 8 }) {
        TextInput({ text: this.askText, placeholder: '例如：米饭其实是两碗' })
          .fontSize(14)
          .height(42)
          .layoutWeight(1)
          .fontColor(INPUT_TEXT)
          .placeholderColor(INPUT_PLACEHOLDER)
          .backgroundColor(COLOR_BG)
          .borderRadius(10)
          .enabled(!this.revising)
          .onChange((v: string) => {
            this.askText = v;
          })
          .onSubmit(() => {
            this.ask();
          })

        // 与体重记录按钮一致：矩形 + 圆角 10，和左侧输入框成一组
        Button({ type: ButtonType.Normal }) {
          Text(this.revising ? '…' : '发送').fontSize(14).fontColor(Color.White)
        }
        .width(72)
        .height(42)
        .backgroundColor(COLOR_PRIMARY)
        .borderRadius(10)
        // 只要有话说就能发送：不再要求还有条目（删光了也能加）
        .enabled(!this.revising && this.askText.trim().length > 0)
        .opacity(!this.revising && this.askText.trim().length > 0 ? 1 : 0.5)
        .onClick(() => {
          this.ask();
        })
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor(COLOR_CARD)
    .borderRadius(RADIUS)
    .shadow(CARD_SHADOW)
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
          AppState.clearPending();
          // 点返回也是退回上一步（拍照页）——用户是要改照片/重新拍，
          // 与「确认记录后回首页」是两件事，所以这里仍然只退一层。
          router.back();
        })

        Text('确认识别结果')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_TEXT)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Row().width(36).height(36)
      }
      .width('100%')
      // 顶部安全距离，口径与其它页面一致：普通页的窗口仍延伸到状态栏区域，
      // 只留 8vp 会让顶栏压在系统时间上（见 AppState.topInset）
      .padding({ left: PAGE_PAD, right: PAGE_PAD, top: AppState.topInset + 8, bottom: 8 })

      Scroll() {
        Column({ space: GAP }) {
          // 送出去识别的原图（可能多张）+ 模型信息
          if (this.imageUris.length > 0) {
            Scroll() {
              Row({ space: 10 }) {
                ForEach(this.imageUris, (uri: string, index: number) => {
                  Image(uri)
                    .width(this.imageUris.length > 1 ? 120 : '100%')
                    .height(this.imageUris.length > 1 ? 120 : 180)
                    .objectFit(ImageFit.Cover)
                    .borderRadius(RADIUS)
                }, (uri: string, index: number) => `${index}-${uri}`)
              }
            }
            .scrollable(this.imageUris.length > 1 ? ScrollDirection.Horizontal : ScrollDirection.Vertical)
            .scrollBar(BarState.Off)
            .width('100%')
          }

          // 回显用户自己写的补充说明，方便核对模型有没有照做
          if (this.userNotes.length > 0) {
            Row({ space: 8 }) {
              Text('你的说明')
                .fontSize(11)
                .fontColor(COLOR_TEXT_SUB)
              Text(this.userNotes)
                .fontSize(12)
                .fontColor(COLOR_TEXT)
                .layoutWeight(1)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')
            .padding(12)
            .backgroundColor(COLOR_CARD)
            .borderRadius(RADIUS)
            .shadow(CARD_SHADOW)
          }

          Row() {
            Text(`识别模型：${this.model}`)
              .fontSize(11)
              .fontColor(COLOR_TEXT_SUB)
          }
          .width('100%')
          .padding({ left: 4 })

          if (this.overallNote.length > 0) {
            Row() {
              Text(this.overallNote)
                .fontSize(12)
                .fontColor(COLOR_TEXT_SUB)
                .layoutWeight(1)
            }
            .width('100%')
            .padding(12)
            .backgroundColor(COLOR_CARD)
            .borderRadius(10)
          }

          // 餐次选择
          Column({ space: 8 }) {
            Text('记到哪一餐')
              .fontSize(13)
              .fontColor(COLOR_TEXT_SUB)
              .width('100%')

            Row({ space: 8 }) {
              ForEach(MEAL_ORDER, (m: MealType) => {
                Text(mealTypeLabel(m))
                  .fontSize(14)
                  .fontColor(this.meal === m ? Color.White : COLOR_TEXT)
                  .textAlign(TextAlign.Center)
                  .layoutWeight(1)
                  .height(38)
                  .backgroundColor(this.meal === m ? COLOR_PRIMARY : COLOR_CARD)
                  .borderRadius(10)
                  .onClick(() => {
                    this.meal = m;
                  })
              }, (m: MealType) => m)
            }
            .width('100%')
          }
          .width('100%')

          // 逐条确认
          ForEach(this.drafts, (item: EditableDraft, index: number) => {
            this.draftCard(item, index)
          }, (item: EditableDraft, index: number) => `${index}-${item.name}`)

          /*
           * 和模型聊聊：对结果不满意时用一句话修正
           *（「米饭其实是两碗」「还喝了一碗汤」「这个不要了」）。
           * 每次返回都会整体替换上面的明细，热量合计当帧刷新。
           */
          this.chatPanel()

          Row().height(80)
        }
        .width('100%')
        .padding({ left: PAGE_PAD, right: PAGE_PAD, top: 8, bottom: 16 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)

      // 底部合计与保存
      Row({ space: 12 }) {
        Column({ space: 2 }) {
          Text('合计')
            .fontSize(11)
            .fontColor(COLOR_TEXT_SUB)
          Text(`${this.totalKcal()} 千卡`)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLOR_TEXT)
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Button({ type: ButtonType.Capsule }) {
          Text('确认记录').fontSize(16).fontColor(Color.White)
        }
        .height(46)
        .width(140)
        .backgroundColor(COLOR_PRIMARY)
        .onClick(() => {
          this.confirm();
        })
      }
      .width('100%')
      .padding({ left: PAGE_PAD, right: PAGE_PAD, top: 10, bottom: 10 })
      .backgroundColor(COLOR_CARD)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BG)
  }

  @Builder
  draftCard(item: EditableDraft, index: number) {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        TextInput({ text: item.name })
          .fontSize(15)
          .height(40)
          .layoutWeight(1)
          .fontColor(INPUT_TEXT)
          .placeholderColor(INPUT_PLACEHOLDER)
          .backgroundColor(COLOR_BG)
          .borderRadius(8)
          .onChange((v: string) => {
            item.name = v;
          })

        Button({ type: ButtonType.Circle }) {
          Text('✕').fontSize(13).fontColor(COLOR_TEXT_SUB)
        }
        .width(30).height(30).backgroundColor(COLOR_DIVIDER)
        .onClick(() => {
          this.removeRow(index);
        })
      }
      .width('100%')

      Row({ space: 8 }) {
        TextInput({ text: item.gramsText, placeholder: '克重' })
          .type(InputType.NUMBER_DECIMAL)
          .fontSize(14)
          .height(40)
          .layoutWeight(1)
          .fontColor(INPUT_TEXT)
          .placeholderColor(INPUT_PLACEHOLDER)
          .backgroundColor(COLOR_BG)
          .borderRadius(8)
          .onChange((v: string) => {
            item.gramsText = v;
            item.recompute();
            // 触发列表重建，让热量数字刷新
            this.drafts = this.drafts.slice();
          })

        Text('克')
          .fontSize(13)
          .fontColor(COLOR_TEXT_SUB)

        Text(`${item.kcal} 千卡`)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_TEXT)
          .width(78)
          .textAlign(TextAlign.End)
      }
      .width('100%')

      // 三大营养素：让用户当场看到 AI 估了什么，而不是只看到一个热量
      Row({ space: 12 }) {
        this.macroTag('蛋白', item.protein)
        this.macroTag('脂肪', item.fat)
        this.macroTag('碳水', item.carb)
      }
      .width('100%')

      Row({ space: 8 }) {
        Text(this.confidenceLabel(item.confidence))
          .fontSize(11)
          .fontColor(this.confidenceColor(item.confidence))
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .backgroundColor(COLOR_BG)
          .borderRadius(4)

        Text(item.source === FoodSource.DATABASE ? '查表数值' : 'AI 估算')
          .fontSize(11)
          .fontColor(COLOR_TEXT_SUB)

        Text(item.note)
          .fontSize(11)
          .fontColor(COLOR_TEXT_SUB)
          .layoutWeight(1)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor(COLOR_CARD)
    .borderRadius(RADIUS)
    .shadow(CARD_SHADOW)
  }

  /** 一个营养素小标签 */
  @Builder
  macroTag(label: string, grams: number) {
    Row({ space: 3 }) {
      Text(label)
        .fontSize(11)
        .fontColor(COLOR_TEXT_SUB)
      Text(`${grams} g`)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_TEXT)
    }
  }
}
