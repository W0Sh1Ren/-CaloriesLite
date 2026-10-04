/**
 * 枚举值 ↔ 界面文案 / 系数的映射，集中放这里，避免各页面散落魔法字符串。
 */
import { ActivityLevel, AiProvider, FoodSource, Gender, Goal, MealType } from './Types';

/** 活动系数（乘在 BMR 上得到 TDEE），采用 Harris-Benedict 活动分级惯例 */
export function activityFactor(level: ActivityLevel): number {
  switch (level) {
    case ActivityLevel.SEDENTARY:
      return 1.2;
    case ActivityLevel.LIGHT:
      return 1.375;
    case ActivityLevel.MODERATE:
      return 1.55;
    case ActivityLevel.ACTIVE:
      return 1.725;
    case ActivityLevel.VERY_ACTIVE:
      return 1.9;
    default:
      return 1.375;
  }
}

export function activityLabel(level: ActivityLevel): string {
  switch (level) {
    case ActivityLevel.SEDENTARY:
      return '久坐';
    case ActivityLevel.LIGHT:
      return '轻度活动';
    case ActivityLevel.MODERATE:
      return '中度活动';
    case ActivityLevel.ACTIVE:
      return '高度活动';
    case ActivityLevel.VERY_ACTIVE:
      return '极高强度';
    default:
      return '轻度活动';
  }
}

export function activityDesc(level: ActivityLevel): string {
  switch (level) {
    case ActivityLevel.SEDENTARY:
      return '几乎不运动，久坐办公';
    case ActivityLevel.LIGHT:
      return '每周运动 1-3 天';
    case ActivityLevel.MODERATE:
      return '每周运动 3-5 天';
    case ActivityLevel.ACTIVE:
      return '每周运动 6-7 天';
    case ActivityLevel.VERY_ACTIVE:
      return '体力劳动或每天高强度训练';
    default:
      return '';
  }
}

/** 所有活动水平的固定顺序，供选择器渲染 */
export const ACTIVITY_ORDER: ActivityLevel[] = [
  ActivityLevel.SEDENTARY,
  ActivityLevel.LIGHT,
  ActivityLevel.MODERATE,
  ActivityLevel.ACTIVE,
  ActivityLevel.VERY_ACTIVE
];

/**
 * 目标对应的每日热量调整量（千卡）。
 * 采用常见做法：减脂在 TDEE 上扣减，增重在 TDEE 上增加。
 */
export function goalAdjust(goal: Goal): number {
  switch (goal) {
    case Goal.LOSE_FAST:
      return -500;
    case Goal.LOSE:
      return -300;
    case Goal.MAINTAIN:
      return 0;
    case Goal.GAIN:
      return 300;
    default:
      return 0;
  }
}

export function goalLabel(goal: Goal): string {
  switch (goal) {
    case Goal.LOSE_FAST:
      return '快速减脂';
    case Goal.LOSE:
      return '平稳减脂';
    case Goal.MAINTAIN:
      return '保持体重';
    case Goal.GAIN:
      return '增重增肌';
    default:
      return '保持体重';
  }
}

export function goalDesc(goal: Goal): string {
  switch (goal) {
    case Goal.LOSE_FAST:
      return '每日约 -500 千卡，每周约减 0.5 公斤';
    case Goal.LOSE:
      return '每日约 -300 千卡，每周约减 0.3 公斤';
    case Goal.MAINTAIN:
      return '收支平衡，维持当前体重';
    case Goal.GAIN:
      return '每日约 +300 千卡，配合力量训练';
    default:
      return '';
  }
}

/** 所有目标的固定顺序 */
export const GOAL_ORDER: Goal[] = [Goal.LOSE_FAST, Goal.LOSE, Goal.MAINTAIN, Goal.GAIN];

export function genderLabel(gender: Gender): string {
  return gender === Gender.MALE ? '男' : '女';
}

export function mealTypeLabel(type: MealType): string {
  switch (type) {
    case MealType.BREAKFAST:
      return '早餐';
    case MealType.LUNCH:
      return '午餐';
    case MealType.DINNER:
      return '晚餐';
    case MealType.SNACK:
      return '加餐';
    default:
      return '加餐';
  }
}

/** 四餐固定顺序，供分组渲染 */
export const MEAL_ORDER: MealType[] = [MealType.BREAKFAST, MealType.LUNCH, MealType.DINNER, MealType.SNACK];

/** 按当前时间猜一个默认餐次，减少用户操作 */
export function guessMealType(hour: number): MealType {
  if (hour < 10) {
    return MealType.BREAKFAST;
  }
  if (hour < 15) {
    return MealType.LUNCH;
  }
  if (hour < 21) {
    return MealType.DINNER;
  }
  return MealType.SNACK;
}

export function foodSourceLabel(source: FoodSource): string {
  switch (source) {
    case FoodSource.DATABASE:
      return '食物表';
    case FoodSource.AI:
      return 'AI 估算';
    case FoodSource.MANUAL:
      return '手动';
    default:
      return '';
  }
}

export function providerLabel(provider: AiProvider): string {
  switch (provider) {
    case AiProvider.OPENAI_COMPATIBLE:
      return 'OpenAI 兼容接口';
    case AiProvider.GEMINI:
      return 'Google Gemini';
    default:
      return '';
  }
}

/** 识别服务商的预置模板，方便用户一键填入 */
export class ProviderPreset {
  provider: AiProvider;
  title: string;
  baseUrl: string;
  model: string;
  hint: string;

  constructor(provider: AiProvider, title: string, baseUrl: string, model: string, hint: string) {
    this.provider = provider;
    this.title = title;
    this.baseUrl = baseUrl;
    this.model = model;
    this.hint = hint;
  }
}

/** 常见服务商预设。baseUrl 一律填到 /v1 这一层，代码里再拼具体路径。 */
export const PRESETS: ProviderPreset[] = [
  new ProviderPreset(AiProvider.OPENAI_COMPATIBLE, '智谱 GLM', 'https://open.bigmodel.cn/api/paas/v4',
    'glm-4v-flash', '国内直连，免费模型 glm-4v-flash 可识图'),
  new ProviderPreset(AiProvider.OPENAI_COMPATIBLE, '通义千问', 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    'qwen-vl-plus', '国内直连，需在阿里云百炼开通'),
  new ProviderPreset(AiProvider.OPENAI_COMPATIBLE, '硅基流动', 'https://api.siliconflow.cn/v1',
    'Qwen/Qwen2.5-VL-72B-Instruct', '国内直连，聚合多家模型'),
  new ProviderPreset(AiProvider.OPENAI_COMPATIBLE, 'OpenAI', 'https://api.openai.com/v1',
    'gpt-4o-mini', '需要海外网络'),
  new ProviderPreset(AiProvider.GEMINI, 'Google Gemini', 'https://generativelanguage.googleapis.com',
    'gemini-2.0-flash', '官方有免费额度，需要海外网络')
];
