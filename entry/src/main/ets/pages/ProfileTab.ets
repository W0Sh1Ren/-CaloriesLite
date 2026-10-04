/**
 * 「我的」标签页：个人情况 → 基础热量，以及 AI 识别配置入口。
 */
import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

import { ActivityLevel, Gender, Goal, UserProfile } from '../model/Types';
import { ACTIVITY_ORDER, GOAL_ORDER, activityDesc, activityLabel, genderLabel, goalDesc, goalLabel } from '../model/Enums';
import { calcBmi, calcBmr, calcDailyBudget, calcTdee, bmiLabel, estimateDaysToGoal } from '../service/CalorieCalc';
import { DailyService } from '../service/DailyService';
import { SettingsRepo } from '../service/SettingsRepo';
import { AppState } from '../common/AppState';
import {
  CARD_SHADOW, COLOR_BG, COLOR_CARD, COLOR_DIVIDER, COLOR_OK, COLOR_PRIMARY,
  COLOR_TEXT, COLOR_TEXT_SUB, COLOR_WARN, GAP, NAV_RESERVE, PAGE_PAD, RADIUS
} from '../common/Theme';

const DOMAIN = 0x0000;

@Component
export struct ProfileTab {
  @Prop refreshTick: number = 0;

  /**
   * 个人档案。
   *
   * 刻意用 @State 保存整份档案，并在每次修改时**换一个新对象**：
   * ArkUI 的 @State 只比较引用，直接改 this.profile.age 不会触发重建，
   * 表现就是「改了年龄但卡片上的数字不动」。换对象才稳。
   */
  @State profile: UserProfile = SettingsRepo.loadProfile();
  @State aiReady: boolean = false;
  @State profileVersion: number = 0;
  @State bmr: number = 0;
  @State tdee: number = 0;
  @State budget: number = 0;
  @State latestWeight: number = 0;
  /** 计算用的体重取值（可能是体重记录里的最新值，未必等于档案里的值） */
  @State effectiveWeight: number = 0;

  // ---- 底部选择面板 ----
  /** 是否展示面板 */
  @State sheetShown: boolean = false;
  /** 当前在编辑哪一项：age / height / weight */
  @State editing: string = 'age';
  /** 滚轮的候选项：年龄与身高用 */
  @State pickerOptions: string[] = [];
  /** 滚轮选中的下标 */
  @State pickerIndex: number = 0;
  /** 体重输入框的值 */
  @State weightText: string = '';

  aboutToAppear(): void {
    this.reload();
  }

  onDidUpdate(): void {
    this.reload();
  }

  /** 面板标题 */
  private sheetTitle(): string {
    if (this.editing === 'age') {
      return '年龄';
    }
    return this.editing === 'height' ? '身高' : '体重';
  }

  /** 打开选择面板，并按当前值定位滚轮 */
  private openPicker(which: string): void {
    this.editing = which;
    if (which === 'weight') {
      // 体重用输入框：0.1 公斤的精度用滚轮太难拨
      this.weightText = `${this.profile.weightKg}`;
    } else {
      const from: number = which === 'age' ? 10 : 100;
      const to: number = which === 'age' ? 120 : 250;
      const cur: number = which === 'age' ? this.profile.age : this.profile.heightCm;
      const opts: string[] = [];
      for (let v = from; v <= to; v++) {
        opts.push(`${v}`);
      }
      this.pickerOptions = opts;
      const idx: number = cur - from;
      this.pickerIndex = idx >= 0 && idx < opts.length ? idx : 0;
    }
    this.sheetShown = true;
  }

  /** 确认写入 */
  private confirmPicker(): void {
    const which: string = this.editing;
    if (which === 'weight') {
      const v: number = Number.parseFloat(this.weightText);
      if (Number.isNaN(v) || v < 20 || v > 400) {
        promptAction.showToast({ message: '请输入 20-400 之间的体重' });
        return;
      }
      const rounded: number = Math.round(v * 10) / 10;
      this.apply((p: UserProfile) => {
        p.weightKg = rounded;
      });
    } else if (this.pickerOptions.length > 0) {
      const chosen: number = Number.parseInt(this.pickerOptions[this.pickerIndex]);
      if (which === 'age') {
        this.apply((p: UserProfile) => {
          p.age = chosen;
        });
      } else {
        this.apply((p: UserProfile) => {
          p.heightCm = chosen;
        });
      }
    }
    this.sheetShown = false;
  }

  private reload(): void {
    this.profile = SettingsRepo.loadProfile();
    this.aiReady = SettingsRepo.isAiReady();
    this.profileVersion++;
    const effective: UserProfile = DailyService.effectiveProfile();
    this.latestWeight = effective.weightKg;
    this.effectiveWeight = effective.weightKg;
    this.bmr = Math.round(calcBmr(effective));
    this.tdee = Math.round(calcTdee(effective));
    this.budget = calcDailyBudget(effective);
  }

  /**
   * 改一个字段并立刻生效。
   *
   * 三步缺一不可：换新对象（触发重建）→ 落盘 → 重算卡片数字。
   */
  private apply(update: (p: UserProfile) => void): void {
    const next: UserProfile = SettingsRepo.loadProfile();
    update(next);
    SettingsRepo.saveProfile(next);
    this.profile = next;
    this.profileVersion++;
    const effective: UserProfile = DailyService.effectiveProfile();
    this.latestWeight = effective.weightKg;
    this.bmr = Math.round(calcBmr(effective));
    this.tdee = Math.round(calcTdee(effective));
    this.budget = calcDailyBudget(effective);
    // 通知首页等同进程内的其它页面按新档案重算
    AppState.profileDirty = true;
  }

  private bmi(): number {
    return Math.round(calcBmi(this.latestWeight, this.profile.heightCm) * 10) / 10;
  }

  /** 目标达成预估天数，-1 表示当前目标不是减脂 */
  private goalDays(): number {
    const target: number = this.profile.gender === Gender.MALE ? 70 : 60;
    return estimateDaysToGoal(DailyService.effectiveProfile(), target);
  }

  build() {
    Scroll() {
      Column({ space: GAP }) {
        // ------------------------------------------------ 基础热量卡片
        this.budgetCard()

        // ------------------------------------------------ 个人情况
        this.profileCard()

        // ------------------------------------------------ AI 识别
        this.aiCard()

        // ------------------------------------------------ 关于与数据
        this.miscCard()

        Row().height(NAV_RESERVE)
      }
      .width('100%')
      .padding({ left: PAGE_PAD, right: PAGE_PAD, top: 8 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BG)
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
    // 底部半模态面板：改年龄/身高用滚轮，改体重用带小数点的键盘
    .bindSheet($$this.sheetShown, this.valueSheet(), {
      height: SheetSize.FIT_CONTENT,
      dragBar: true,
      backgroundColor: COLOR_CARD,
      onDisappear: () => {
        this.sheetShown = false;
      }
    })
  }

  /** 数值选择面板 */
  @Builder
  valueSheet() {
    Column({ space: 12 }) {
      Row() {
        Button({ type: ButtonType.Capsule }) {
          Text('取消').fontSize(14).fontColor(COLOR_TEXT_SUB)
        }
        .height(34)
        .backgroundColor(COLOR_BG)
        .onClick(() => {
          this.sheetShown = false;
        })

        Text(this.sheetTitle())
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_TEXT)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Button({ type: ButtonType.Capsule }) {
          Text('确定').fontSize(14).fontColor(Color.White)
        }
        .height(34)
        .backgroundColor(COLOR_PRIMARY)
        .onClick(() => {
          this.confirmPicker();
        })
      }
      .width('100%')

      if (this.editing === 'weight') {
        // 体重：直接调起数字键盘，允许一位小数
        TextInput({ text: this.weightText, placeholder: '输入体重' })
          .type(InputType.NUMBER_DECIMAL)
          .fontSize(24)
          .fontWeight(FontWeight.Medium)
          .textAlign(TextAlign.Center)
          .height(64)
          .width('100%')
          .backgroundColor(COLOR_BG)
          .borderRadius(12)
          .onChange((v: string) => {
            this.weightText = v;
          })

        Text('公斤，可精确到 0.1')
          .fontSize(11)
          .fontColor(COLOR_TEXT_SUB)
      } else {
        TextPicker({ range: this.pickerOptions, selected: this.pickerIndex })
          .width('100%')
          .height(180)
          .selectedTextStyle({ color: COLOR_PRIMARY, font: { size: 20, weight: FontWeight.Medium } })
          .onChange((value: string | string[], index: number | number[]) => {
            this.pickerIndex = typeof index === 'number' ? index : index[0];
          })
      }

      Row().height(8)
    }
    .width('100%')
    .padding({ left: PAGE_PAD, right: PAGE_PAD, top: 4 })
  }

  @Builder
  budgetCard() {
    Column({ space: 12 }) {
      Text('每日基础热量')
        .fontSize(13)
        .fontColor(COLOR_TEXT_SUB)
        .width('100%')

      Row() {
        Text(`${this.budget}`)
          .fontSize(40)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_PRIMARY)
        Text(' 千卡')
          .fontSize(14)
          .fontColor(COLOR_TEXT_SUB)
          .margin({ bottom: 6 })
      }
      .alignItems(VerticalAlign.Bottom)
      .width('100%')

      Divider().color(COLOR_DIVIDER)

      Row() {
        this.metric('基础代谢', () => `${this.bmr}`)
        this.metric('总消耗', () => `${this.tdee}`)
        this.metric('BMI', () => `${this.bmi()}`, () => bmiLabel(this.bmi()))
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      Text(`按当前体重 ${this.latestWeight} 公斤、${genderLabel(this.profile.gender)}性、${this.profile.age} 岁、${this.profile.heightCm} 厘米计算`)
        .fontSize(11)
        .fontColor(COLOR_TEXT_SUB)
        .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor(COLOR_CARD)
    .borderRadius(RADIUS)
    .shadow(CARD_SHADOW)
  }

  /**
   * 一项指标。value 与 sub 都用取值函数，理由同 numRow：
   * @Builder 参数求值一次，传值不会随状态更新。
   */
  @Builder
  metric(label: string, value: () => string, sub: () => string = () => '') {
    Column({ space: 2 }) {
      Text(value())
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_TEXT)
      Text(sub().length > 0 ? `${label} · ${sub()}` : label)
        .fontSize(11)
        .fontColor(COLOR_TEXT_SUB)
    }
    .layoutWeight(1)
  }

  @Builder
  profileCard() {
    Column({ space: 14 }) {
      Text('个人情况')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_TEXT)
        .width('100%')

      // 性别
      Row({ space: 8 }) {
        Text('性别')
          .fontSize(14)
          .fontColor(COLOR_TEXT_SUB)
          .width(56)
        ForEach([Gender.MALE, Gender.FEMALE], (g: Gender) => {
          Text(genderLabel(g))
            .fontSize(14)
            .fontColor(this.profile.gender === g ? Color.White : COLOR_TEXT)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .height(36)
            .backgroundColor(this.profile.gender === g ? COLOR_PRIMARY : COLOR_BG)
            .borderRadius(10)
            .onClick(() => {
              this.apply((p: UserProfile) => {
                p.gender = g;
              });
            })
        }, (g: Gender) => g)
      }
      .width('100%')

      // 数值项：点击弹出底部选择面板
      this.numRow('年龄', () => this.profile.age, '岁', () => {
        this.openPicker('age');
      })

      this.numRow('身高', () => this.profile.heightCm, '厘米', () => {
        this.openPicker('height');
      })

      this.numRow('体重', () => this.profile.weightKg, '公斤', () => {
        this.openPicker('weight');
      })

      Divider().color(COLOR_DIVIDER)

      // 活动水平
      Text('日常活动量')
        .fontSize(13)
        .fontColor(COLOR_TEXT_SUB)
        .width('100%')

      ForEach(ACTIVITY_ORDER, (level: ActivityLevel) => {
        Row() {
          Column({ space: 2 }) {
            Text(activityLabel(level))
              .fontSize(14)
              .fontColor(this.profile.activityLevel === level ? COLOR_PRIMARY : COLOR_TEXT)
            Text(activityDesc(level))
              .fontSize(11)
              .fontColor(COLOR_TEXT_SUB)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          if (this.profile.activityLevel === level) {
            Text('✓')
              .fontSize(16)
              .fontColor(COLOR_PRIMARY)
          }
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
        .onClick(() => {
          this.apply((p: UserProfile) => {
            p.activityLevel = level;
          });
        })
      }, (level: ActivityLevel) => level)

      Divider().color(COLOR_DIVIDER)

      // 目标
      Text('目标')
        .fontSize(13)
        .fontColor(COLOR_TEXT_SUB)
        .width('100%')

      ForEach(GOAL_ORDER, (goal: Goal) => {
        Row() {
          Column({ space: 2 }) {
            Text(goalLabel(goal))
              .fontSize(14)
              .fontColor(this.profile.goal === goal ? COLOR_PRIMARY : COLOR_TEXT)
            Text(goalDesc(goal))
              .fontSize(11)
              .fontColor(COLOR_TEXT_SUB)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          if (this.profile.goal === goal) {
            Text('✓')
              .fontSize(16)
              .fontColor(COLOR_PRIMARY)
          }
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
        .onClick(() => {
          this.apply((p: UserProfile) => {
            p.goal = goal;
          });
        })
      }, (goal: Goal) => goal)

      if (this.goalDays() > 0) {
        Text(`按当前目标，约 ${this.goalDays()} 天后可减到目标体重`)
          .fontSize(11)
          .fontColor(COLOR_TEXT_SUB)
          .width('100%')
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(COLOR_CARD)
    .borderRadius(RADIUS)
    .shadow(CARD_SHADOW)
  }

  /**
   * 一行数值项：点击数值弹出底部选择面板。
   *
   * 去掉了原来的「−」「+」小按钮——每点一次只挪一格，改 10 岁要点 10 次，
   * 而且两个按钮挤在行里让整行显得零碎。改成点数值直接调起
   * 底部半模态面板，年龄/身高用滚轮，体重用带小数点的键盘。
   *
   * value 用取值函数而不是直接传值：@Builder 的参数在容器构建时求值一次，
   * 之后状态变化不会重新求值，传值会表现为「改完数字不动」。
   */
  @Builder
  numRow(label: string, value: () => number, unit: string, onTap: () => void) {
    Row({ space: 8 }) {
      Text(label)
        .fontSize(14)
        .fontColor(COLOR_TEXT_SUB)
        .width(56)

      Blank()

      // 只有数值本身可点，热区抬到 40vp 保证好按
      Row({ space: 4 }) {
        Text(`${value()}`)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_PRIMARY)
        Text(unit)
          .fontSize(12)
          .fontColor(COLOR_TEXT_SUB)
        Text('›')
          .fontSize(14)
          .fontColor(COLOR_TEXT_SUB)
          .margin({ left: 2 })
      }
      .height(40)
      .padding({ left: 12, right: 6 })
      .backgroundColor(COLOR_BG)
      .borderRadius(10)
      .onClick(onTap)
    }
    .width('100%')
  }

  @Builder
  aiCard() {
    Column({ space: 10 }) {
      Row() {
        Text('AI 拍照识别')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_TEXT)
        Blank()
        Text(this.aiReady ? '已配置' : '未配置')
          .fontSize(12)
          .fontColor(this.aiReady ? COLOR_OK : COLOR_WARN)
      }
      .width('100%')

      Text(this.aiReady
        ? '使用你自己的 DeepSeek API Key，识别结果只发往 DeepSeek'
        : '填上你的 DeepSeek API Key 就能拍照识别食物，一张照片约 0.4 分钱；本应用不提供也不代管任何额度')
        .fontSize(12)
        .fontColor(COLOR_TEXT_SUB)
        .width('100%')

      Button({ type: ButtonType.Capsule }) {
        Text(this.aiReady ? '修改配置' : '去配置')
          .fontSize(14)
          .fontColor(Color.White)
      }
      .width('100%')
      .height(42)
      .backgroundColor(COLOR_PRIMARY)
      .onClick(() => {
        try {
          router.pushUrl({ url: 'pages/AiSettings' });
        } catch (err) {
          hilog.error(DOMAIN, 'CalorieLite', 'goAiSettings failed');
        }
      })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(COLOR_CARD)
    .borderRadius(RADIUS)
    .shadow(CARD_SHADOW)
  }

  @Builder
  miscCard() {
    Column({ space: 4 }) {
      Text('关于')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_TEXT)
        .width('100%')
        .margin({ bottom: 6 })

      Text('轻卡记 —— 只做三件事：算出你一天该吃多少、帮你记下吃了多少、告诉你今天差多少。')
        .fontSize(12)
        .fontColor(COLOR_TEXT_SUB)
        .width('100%')

      Text('所有记录只存在本机，不上传任何服务器；食物表内置，AI 识别按你自己的配置直连。')
        .fontSize(12)
        .fontColor(COLOR_TEXT_SUB)
        .width('100%')
        .margin({ top: 4 })

      Divider().color(COLOR_DIVIDER).margin({ top: 12, bottom: 8 })

      Row() {
        Text('清空全部数据')
          .fontSize(14)
          .fontColor(COLOR_WARN)
        Blank()
      }
      .width('100%')
      .padding({ top: 6, bottom: 6 })
      .onClick(() => {
        this.confirmClear();
      })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(COLOR_CARD)
    .borderRadius(RADIUS)
    .shadow(CARD_SHADOW)
  }

  private async confirmClear(): Promise<void> {
    try {
      const res = await promptAction.showDialog({
        title: '清空全部数据',
        message: '会删除所有饮食记录、体重记录和设置，且无法恢复。确定继续吗？',
        buttons: [
          { text: '取消', color: COLOR_TEXT_SUB },
          { text: '清空', color: COLOR_WARN }
        ]
      });
      if (res.index === 1) {
        SettingsRepo.clearAll();
        this.reload();
        promptAction.showToast({ message: '已清空' });
      }
    } catch (err) {
      hilog.error(DOMAIN, 'CalorieLite', 'confirmClear failed');
    }
  }
}
