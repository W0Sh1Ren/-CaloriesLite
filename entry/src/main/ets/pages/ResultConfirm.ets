/**
 * 识别结果确认页。
 *
 * 识别出来的每一条都可以改名字、克重、餐次，确认后才写进记录，
 * 避免 AI 估错直接污染当天数据。
 */
import { router, promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { FoodDraft, FoodRecord, FoodSource, MealType } from '../model/Types';
import { MEAL_ORDER, mealTypeLabel } from '../model/Enums';
import { todayKey } from '../common/DateUtil';
import { makeId } from '../common/JsonUtil';
import { FoodRepo } from '../service/FoodRepo';
import { AppState, PendingResult } from '../common/AppState';
import { COLOR_BG, COLOR_CARD, COLOR_DIVIDER, COLOR_OK, COLOR_PRIMARY, COLOR_TEXT, COLOR_TEXT_SUB, COLOR_WARN, GAP, PAGE_PAD, RADIUS } from '../common/Theme';

const DOMAIN = 0x0000;

/** 可编辑的草稿行 */
@Observed
class EditableDraft {
  name: string = '';
  gramsText: string = '';
  kcal: number = 0;
  confidence: string = '';
  source: FoodSource = FoodSource.AI;
  note: string = '';
  /** 每 100 克热量，用于改克重时重算 */
  kcalPer100g: number = 0;

  constructor(draft: FoodDraft) {
    this.name = draft.name;
    this.gramsText = `${draft.grams}`;
    this.kcal = draft.kcal;
    this.confidence = draft.confidence;
    this.source = draft.source;
    this.note = draft.note;
    if (draft.grams > 0 && draft.kcal > 0) {
      this.kcalPer100g = draft.kcal / draft.grams * 100;
    }
  }

  grams(): number {
    const v: number = Number.parseFloat(this.gramsText);
    return Number.isNaN(v) || v <= 0 ? 0 : Math.round(v);
  }

  /** 改完克重后重算热量；没有基准值时保持原样 */
  recompute(): void {
    if (this.kcalPer100g > 0) {
      this.kcal = Math.round(this.kcalPer100g * this.grams() / 100);
    }
  }
}

@Entry
@Component
struct ResultConfirm {
  @State drafts: EditableDraft[] = [];
  @State imageUri: string = '';
  @State overallNote: string = '';
  @State model: string = '';
  @State meal: MealType = MealType.LUNCH;

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
    this.imageUri = pending.imageUri;
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
    const day: string = todayKey();
    const now: number = Date.now();
    const records: FoodRecord[] = [];

    for (const d of this.drafts) {
      const grams: number = d.grams();
      if (grams <= 0 || d.kcal <= 0) {
        promptAction.showToast({ message: `「${d.name}」缺少克重或热量，请补全后再保存` });
        return;
      }
      records.push(new FoodRecord(
        makeId(), day, now, this.meal, d.name, grams, d.kcal,
        0, 0, 0, d.source, this.imageUri, d.note
      ));
    }

    FoodRepo.addMany(records);
    AppState.clearPending();
    AppState.needRefreshHome = true;
    promptAction.showToast({ message: `已记录 ${records.length} 项，共 ${this.totalKcal()} 千卡` });
    router.back();
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
      .padding({ left: PAGE_PAD, right: PAGE_PAD, top: 8, bottom: 8 })

      Scroll() {
        Column({ space: GAP }) {
          // 原图 + 模型信息
          if (this.imageUri.length > 0) {
            Image(this.imageUri)
              .width('100%')
              .height(180)
              .objectFit(ImageFit.Cover)
              .borderRadius(RADIUS)
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
  }
}
