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

/**
 * DeepSeek 开放平台的接口地址。
 *
 * 注意这是**根路径**，代码里再拼 /chat/completions 得到
 * https://api.deepseek.com/chat/completions，与官方文档一致。
 * 不要填成 /v1——虽然 /v1/chat/completions 也能通，但官方写法是根路径。
 */
export const AI_BASE_URL: string = 'https://api.deepseek.com';

/**
 * 默认识图模型。
 *
 * deepseek-flash（底层 DeepSeek-V4.1-Flash）支持图像理解，1M 上下文，
 * OpenAI 兼容格式，单图最多计 1024 token。
 * 注意别写成 deepseek-v4-flash 或 deepseek-v4-flash-vision-exp：
 * 那两个名字对应的模型已下线，请求会由当前 Flash 模型承接。
 * 见 https://api-docs.deepseek.com/zh-cn/guides/vision
 */
export const AI_MODEL: string = 'deepseek-flash';

/** 当前只保留一家服务商，其余预设已移除 */
export const PRESETS: ProviderPreset[] = [
  new ProviderPreset(AiProvider.OPENAI_COMPATIBLE, 'DeepSeek', AI_BASE_URL,
    AI_MODEL, '国内直连，识别一张照片约 0.4 分钱（空闲时段减半）')
];

/**
 * 三大营养素的推荐热量占比：碳水 50%、蛋白质 30%、脂肪 20%。
 *
 * 用一个明确的配比而不是「相对比例」，是为了让进度条有确定的基准——
 * 否则只能拿三项里的最大值当分母，那种条形看不出「离推荐量还差多少」。
 */
export const MACRO_CARB_RATIO: number = 0.50;
export const MACRO_PROTEIN_RATIO: number = 0.30;
export const MACRO_FAT_RATIO: number = 0.20;

/** 每克营养素的热量（千卡） */
export const KCAL_PER_G_CARB: number = 4;
export const KCAL_PER_G_PROTEIN: number = 4;
export const KCAL_PER_G_FAT: number = 9;

/** 按每日总消耗推算三大营养素的推荐克数 */
export class MacroTarget {
  carb: number = 0;
  protein: number = 0;
  fat: number = 0;

  constructor(carb: number, protein: number, fat: number) {
    this.carb = carb;
    this.protein = protein;
    this.fat = fat;
  }
}

/**
 * 由每日总消耗算出推荐克数。
 *
 * 用实际预算而不是写死 2295：换个人、换个目标，预算就变了，
 * 写死会让用户看到自相矛盾的两个数（顶部预算 2301、营养素却按 2295 算）。
 */
export function macroTargetFor(dailyBudget: number): MacroTarget {
  const b: number = dailyBudget > 0 ? dailyBudget : 0;
  return new MacroTarget(
    Math.round(b * MACRO_CARB_RATIO / KCAL_PER_G_CARB),
    Math.round(b * MACRO_PROTEIN_RATIO / KCAL_PER_G_PROTEIN),
    Math.round(b * MACRO_FAT_RATIO / KCAL_PER_G_FAT)
  );
}
