/**
 * 手动添加页。
 *
 * 两条路：从内置食物表里挑一条（数值精确），或者自己填名字和热量（兜底）。
 */
import { router, promptAction } from '@kit.ArkUI';

import { FoodDraft, FoodItem, FoodRecord, FoodSource, MealType } from '../model/Types';
import { MEAL_ORDER, mealTypeLabel } from '../model/Enums';
import { FOOD_CATEGORIES } from '../model/FoodDatabase';
import { searchFoods, draftFromItem } from '../service/FoodMatcher';
import { todayKey } from '../common/DateUtil';
import { makeId } from '../common/JsonUtil';
import { FoodRepo } from '../service/FoodRepo';
import { AppState } from '../common/AppState';
import { COLOR_BG, COLOR_CARD, COLOR_DIVIDER, COLOR_PRIMARY, COLOR_TEXT, COLOR_TEXT_SUB, GAP, PAGE_PAD, RADIUS } from '../common/Theme';

@Entry
@Component
struct ManualAdd {
  @State keyword: string = '';
  @State category: string = '';
  @State results: FoodItem[] = [];
  @State selected: FoodItem | null = null;
  @State gramsText: string = '';
  @State meal: MealType = MealType.LUNCH;

  aboutToAppear(): void {
    this.results = searchFoods('', 60);
    this.meal = AppState.targetMeal;
  }

  private doSearch(): void {
    this.results = searchFoods(this.keyword, 60);
  }

  /** 选分类：再点一次取消筛选 */
  private toggleCategory(c: string): void {
    this.category = this.category === c ? '' : c;
    if (this.category.length === 0) {
      this.doSearch();
    } else {
      this.results = searchFoods(this.keyword, 200).filter((f: FoodItem) => f.category === this.category);
    }
  }

  private pick(item: FoodItem): void {
    this.selected = item;
    this.gramsText = `${item.defaultGrams}`;
  }

  /** 当前选中项的实时热量预览 */
  private preview(): FoodDraft | null {
    const item: FoodItem | null = this.selected;
    if (item === null) {
      return null;
    }
    const g: number = Number.parseFloat(this.gramsText);
    const grams: number = Number.isNaN(g) || g <= 0 ? item.defaultGrams : Math.round(g);
    return draftFromItem(item, grams);
  }

  private save(): void {
    const draft: FoodDraft | null = this.preview();
    if (draft === null) {
      promptAction.showToast({ message: '先选一个食物' });
      return;
    }
    FoodRepo.add(new FoodRecord(
      makeId(), todayKey(), Date.now(), this.meal, draft.name, draft.grams,
      draft.kcal, draft.protein, draft.fat, draft.carb,
      FoodSource.DATABASE, '', '手动从食物表添加'
    ));
    AppState.needRefreshHome = true;
    promptAction.showToast({ message: `已记录 ${draft.name} ${draft.kcal} 千卡` });
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
          router.back();
        })

        Text('手动添加')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_TEXT)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Row().width(36).height(36)
      }
      .width('100%')
      .padding({ left: PAGE_PAD, right: PAGE_PAD, top: 8, bottom: 8 })

      // 搜索
      Row({ space: 10 }) {
        TextInput({ text: this.keyword, placeholder: '搜索食物，如「米饭」「鸡胸肉」' })
          .fontSize(14)
          .height(42)
          .layoutWeight(1)
          .backgroundColor(COLOR_CARD)
          .borderRadius(10)
          .onChange((v: string) => {
            this.keyword = v;
            this.doSearch();
          })
      }
      .width('100%')
      .padding({ left: PAGE_PAD, right: PAGE_PAD, bottom: 8 })

      // 分类筛选
      Scroll() {
        Row({ space: 8 }) {
          ForEach(FOOD_CATEGORIES, (c: string) => {
            Text(c)
              .fontSize(13)
              .fontColor(this.category === c ? Color.White : COLOR_TEXT)
              .padding({ left: 14, right: 14, top: 6, bottom: 6 })
              .backgroundColor(this.category === c ? COLOR_PRIMARY : COLOR_CARD)
              .borderRadius(14)
              .onClick(() => {
                this.toggleCategory(c);
              })
          }, (c: string) => c)
        }
        .padding({ left: PAGE_PAD, right: PAGE_PAD })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .height(40)

      // 结果列表
      List({ space: 6 }) {
        ForEach(this.results, (item: FoodItem) => {
          ListItem() {
            Row() {
              Column({ space: 3 }) {
                Text(item.name)
                  .fontSize(15)
                  .fontColor(COLOR_TEXT)
                Text(`${item.category} · 每 100 克`)
                  .fontSize(11)
                  .fontColor(COLOR_TEXT_SUB)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Text(`${item.kcalPer100g}`)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.selected !== null && this.selected.name === item.name ? COLOR_PRIMARY : COLOR_TEXT)
              Text(' 千卡')
                .fontSize(11)
                .fontColor(COLOR_TEXT_SUB)
            }
            .width('100%')
            .padding(14)
            .backgroundColor(COLOR_CARD)
            .borderRadius(10)
          }
          .onClick(() => {
            this.pick(item);
          })
        }, (item: FoodItem) => item.name)

        if (this.results.length === 0) {
          ListItem() {
            Column({ space: 6 }) {
              Text('没找到这个食物')
                .fontSize(14)
                .fontColor(COLOR_TEXT)
              Text('试试换个说法，或者用拍照识别让 AI 估算')
                .fontSize(12)
                .fontColor(COLOR_TEXT_SUB)
            }
            .width('100%')
            .padding(24)
            .backgroundColor(COLOR_CARD)
            .borderRadius(RADIUS)
          }
        }

        ListItem() {
          Row().height(100)
        }
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: PAGE_PAD, right: PAGE_PAD })
      .scrollBar(BarState.Off)

      // 底部：已选食物 + 份量 + 保存
      if (this.selected !== null) {
        Column({ space: 12 }) {
          Row() {
            Column({ space: 3 }) {
              Text(this.selected.name)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(COLOR_TEXT)
              Text(this.preview() !== null
                ? `${(this.preview() as FoodDraft).kcal} 千卡 · 蛋白 ${(this.preview() as FoodDraft).protein}g / 脂肪 ${(this.preview() as FoodDraft).fat}g / 碳水 ${(this.preview() as FoodDraft).carb}g`
                : '')
                .fontSize(11)
                .fontColor(COLOR_TEXT_SUB)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Button({ type: ButtonType.Circle }) {
              Text('✕').fontSize(13).fontColor(COLOR_TEXT_SUB)
            }
            .width(28).height(28).backgroundColor(COLOR_DIVIDER)
            .onClick(() => {
              this.selected = null;
            })
          }
          .width('100%')

          Row({ space: 10 }) {
            Text('份量')
              .fontSize(13)
              .fontColor(COLOR_TEXT_SUB)
            TextInput({ text: this.gramsText })
              .type(InputType.NUMBER_DECIMAL)
              .fontSize(14)
              .height(40)
              .layoutWeight(1)
              .backgroundColor(COLOR_BG)
              .borderRadius(8)
              .onChange((v: string) => {
                this.gramsText = v;
              })
            Text('克')
              .fontSize(13)
              .fontColor(COLOR_TEXT_SUB)
          }
          .width('100%')

          Row({ space: 8 }) {
            ForEach(MEAL_ORDER, (m: MealType) => {
              Text(mealTypeLabel(m))
                .fontSize(13)
                .fontColor(this.meal === m ? Color.White : COLOR_TEXT)
                .textAlign(TextAlign.Center)
                .layoutWeight(1)
                .height(34)
                .backgroundColor(this.meal === m ? COLOR_PRIMARY : COLOR_BG)
                .borderRadius(8)
                .onClick(() => {
                  this.meal = m;
                })
            }, (m: MealType) => m)
          }
          .width('100%')

          Button({ type: ButtonType.Capsule }) {
            Text('添加到记录').fontSize(16).fontColor(Color.White)
          }
          .width('100%')
          .height(46)
          .backgroundColor(COLOR_PRIMARY)
          .onClick(() => {
            this.save();
          })
        }
        .width('100%')
        .padding(16)
        .backgroundColor(COLOR_CARD)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BG)
  }
}
