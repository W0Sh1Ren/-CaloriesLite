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
import {
  CARD_SHADOW, COLOR_BG, COLOR_CARD, COLOR_DIVIDER, COLOR_OK, COLOR_PRIMARY,
  COLOR_TEXT, COLOR_TEXT_SUB, COLOR_WARN, GAP, NAV_RESERVE, PAGE_PAD, RADIUS
} from '../common/Theme';

const DOMAIN = 0x0000;

@Component
export struct ProfileTab {
  @Prop refreshTick: number = 0;

  @State profile: UserProfile = SettingsRepo.loadProfile();
  @State aiReady: boolean = false;
  @State bmr: number = 0;
  @State tdee: number = 0;
  @State budget: number = 0;
  @State latestWeight: number = 0;

  aboutToAppear(): void {
    this.reload();
  }

  onDidUpdate(): void {
    this.reload();
  }

  private reload(): void {
    this.profile = SettingsRepo.loadProfile();
    this.aiReady = SettingsRepo.isAiReady();
    const effective: UserProfile = DailyService.effectiveProfile();
    this.latestWeight = effective.weightKg;
    this.bmr = Math.round(calcBmr(effective));
    this.tdee = Math.round(calcTdee(effective));
    this.budget = calcDailyBudget(effective);
  }

  private save(): void {
    SettingsRepo.saveProfile(this.profile);
    this.reload();
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
        this.metric('基础代谢', `${this.bmr}`)
        this.metric('总消耗', `${this.tdee}`)
        this.metric('BMI', `${this.bmi()}`, bmiLabel(this.bmi()))
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

  @Builder
  metric(label: string, value: string, sub: string = '') {
    Column({ space: 2 }) {
      Text(value)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_TEXT)
      Text(sub.length > 0 ? `${label} · ${sub}` : label)
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
              this.profile.gender = g;
              this.save();
            })
        }, (g: Gender) => g)
      }
      .width('100%')

      // 数值项
      this.numRow('年龄', `${this.profile.age}`, '岁', () => {
        this.profile.age = Math.max(10, this.profile.age - 1);
        this.save();
      }, () => {
        this.profile.age = Math.min(120, this.profile.age + 1);
        this.save();
      })

      this.numRow('身高', `${this.profile.heightCm}`, '厘米', () => {
        this.profile.heightCm = Math.max(100, this.profile.heightCm - 1);
        this.save();
      }, () => {
        this.profile.heightCm = Math.min(250, this.profile.heightCm + 1);
        this.save();
      })

      this.numRow('体重', `${this.profile.weightKg}`, '公斤', () => {
        this.profile.weightKg = Math.max(25, Math.round((this.profile.weightKg - 0.5) * 10) / 10);
        this.save();
      }, () => {
        this.profile.weightKg = Math.min(300, Math.round((this.profile.weightKg + 0.5) * 10) / 10);
        this.save();
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
          this.profile.activityLevel = level;
          this.save();
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
          this.profile.goal = goal;
          this.save();
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

  /** 一行「减 / 数值 / 加」的数值调节器 */
  @Builder
  numRow(label: string, value: string, unit: string,
    onMinus: () => void, onPlus: () => void) {
    Row({ space: 8 }) {
      Text(label)
        .fontSize(14)
        .fontColor(COLOR_TEXT_SUB)
        .width(56)

      Button({ type: ButtonType.Circle }) {
        Text('−').fontSize(18).fontColor(COLOR_TEXT)
      }
      .width(32).height(32).backgroundColor(COLOR_BG)
      .onClick(onMinus)

      Text(value)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_TEXT)
        .textAlign(TextAlign.Center)
        .layoutWeight(1)

      Text(unit)
        .fontSize(12)
        .fontColor(COLOR_TEXT_SUB)

      Button({ type: ButtonType.Circle }) {
        Text('+').fontSize(18).fontColor(COLOR_TEXT)
      }
      .width(32).height(32).backgroundColor(COLOR_BG)
      .onClick(onPlus)
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
        ? '使用你自己的智谱 API Key，识别结果只发往智谱开放平台'
        : '填上你的智谱 API Key 就能拍照识别食物，glm-4.6v-flash 免费；本应用不提供也不代管任何额度')
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
