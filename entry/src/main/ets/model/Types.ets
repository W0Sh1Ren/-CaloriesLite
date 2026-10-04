/**
 * 全局类型定义。
 *
 * 本文件只放纯类型/枚举/常量，不放副作用代码，便于各层共享。
 * 注意：ArkTS 严格模式下不支持 any / 结构类型随意赋值，所有字段都显式声明。
 */

/** 生理性别 —— 用于 BMR 公式（男女公式系数不同） */
export enum Gender {
  MALE = 'male',
  FEMALE = 'female'
}

/** 日常活动水平 —— 决定 TDEE = BMR × 活动系数 */
export enum ActivityLevel {
  SEDENTARY = 'sedentary',
  LIGHT = 'light',
  MODERATE = 'moderate',
  ACTIVE = 'active',
  VERY_ACTIVE = 'very_active'
}

/** 目标 —— 决定每日预算相对 TDEE 的增减 */
export enum Goal {
  LOSE_FAST = 'lose_fast',
  LOSE = 'lose',
  MAINTAIN = 'maintain',
  GAIN = 'gain'
}

/** 一餐的分类 */
export enum MealType {
  BREAKFAST = 'breakfast',
  LUNCH = 'lunch',
  DINNER = 'dinner',
  SNACK = 'snack'
}

/** 一条食物记录的来源，用于区分「查表命中」和「AI 估算」 */
export enum FoodSource {
  /** 命中内置食物表 */
  DATABASE = 'database',
  /** AI 视觉估算 */
  AI = 'ai',
  /** 用户手动填写 */
  MANUAL = 'manual'
}

/** 识别服务商 */
export enum AiProvider {
  /** OpenAI 兼容的 /v1/chat/completions 接口（智谱、通义、Kimi、DeepSeek、硅基流动、中转站等） */
  OPENAI_COMPATIBLE = 'openai_compatible',
  /** Google Gemini */
  GEMINI = 'gemini'
}

/** 用户个人基本情况 —— 用于推算基础热量 */
export class UserProfile {
  /** 昵称，仅用于展示 */
  nickname: string = '';
  gender: Gender = Gender.MALE;
  /** 年龄（岁） */
  age: number = 25;
  /** 身高（厘米） */
  heightCm: number = 170;
  /** 体重（公斤） */
  weightKg: number = 65;
  activityLevel: ActivityLevel = ActivityLevel.LIGHT;
  goal: Goal = Goal.MAINTAIN;

  constructor(nickname: string, gender: Gender, age: number, heightCm: number, weightKg: number,
    activityLevel: ActivityLevel, goal: Goal) {
    this.nickname = nickname;
    this.gender = gender;
    this.age = age;
    this.heightCm = heightCm;
    this.weightKg = weightKg;
    this.activityLevel = activityLevel;
    this.goal = goal;
  }
}

/** AI 识别配置 —— 用户自备 API */
export class AiConfig {
  provider: AiProvider = AiProvider.OPENAI_COMPATIBLE;
  /** 形如 https://api.openai.com/v1 ，不带结尾斜杠 */
  baseUrl: string = '';
  apiKey: string = '';
  /** 模型名，如 gpt-4o-mini / glm-4v-flash / gemini-2.0-flash */
  model: string = '';

  constructor(provider: AiProvider, baseUrl: string, apiKey: string, model: string) {
    this.provider = provider;
    this.baseUrl = baseUrl;
    this.apiKey = apiKey;
    this.model = model;
  }
}

/** 内置食物表的条目 —— 营养值统一按每 100 克计 */
export class FoodItem {
  /** 食物名（中文） */
  name: string;
  /** 别名，用于模糊匹配，如「土豆」=「马铃薯」 */
  alias: string;
  /** 分类：主食/肉蛋/蔬菜/水果/零食/饮品/菜肴 */
  category: string;
  /** 每 100 克热量（千卡） */
  kcalPer100g: number;
  /** 每 100 克蛋白质（克） */
  proteinPer100g: number;
  /** 每 100 克脂肪（克） */
  fatPer100g: number;
  /** 每 100 克碳水化合物（克） */
  carbPer100g: number;
  /** 常见一份的默认克重，用于快速录入 */
  defaultGrams: number;

  constructor(name: string, alias: string, category: string, kcalPer100g: number,
    proteinPer100g: number, fatPer100g: number, carbPer100g: number, defaultGrams: number) {
    this.name = name;
    this.alias = alias;
    this.category = category;
    this.kcalPer100g = kcalPer100g;
    this.proteinPer100g = proteinPer100g;
    this.fatPer100g = fatPer100g;
    this.carbPer100g = carbPer100g;
    this.defaultGrams = defaultGrams;
  }
}

/** 一条进食记录 */
export class FoodRecord {
  /** 唯一 id，用时间戳 + 随机数生成 */
  id: string = '';
  /** 归属日期，格式 YYYY-MM-DD */
  dayKey: string = '';
  /** 记录时刻，毫秒时间戳 */
  timestamp: number = 0;
  mealType: MealType = MealType.LUNCH;
  /** 食物名 */
  name: string = '';
  /** 份量（克） */
  grams: number = 0;
  /** 这条记录最终计入的热量（千卡） */
  kcal: number = 0;
  protein: number = 0;
  fat: number = 0;
  carb: number = 0;
  source: FoodSource = FoodSource.MANUAL;
  /** 拍照识别的原图 uri，可为空 */
  imageUri: string = '';
  /** AI 给出的识别说明，便于用户判断是否可信 */
  note: string = '';

  constructor(id: string, dayKey: string, timestamp: number, mealType: MealType, name: string,
    grams: number, kcal: number, protein: number, fat: number, carb: number,
    source: FoodSource, imageUri: string, note: string) {
    this.id = id;
    this.dayKey = dayKey;
    this.timestamp = timestamp;
    this.mealType = mealType;
    this.name = name;
    this.grams = grams;
    this.kcal = kcal;
    this.protein = protein;
    this.fat = fat;
    this.carb = carb;
    this.source = source;
    this.imageUri = imageUri;
    this.note = note;
  }
}

/** 体重记录 */
export class WeightRecord {
  /** 归属日期 YYYY-MM-DD，同一天只保留一条 */
  dayKey: string = '';
  /** 体重（公斤） */
  weightKg: number = 0;
  timestamp: number = 0;

  constructor(dayKey: string, weightKg: number, timestamp: number) {
    this.dayKey = dayKey;
    this.weightKg = weightKg;
    this.timestamp = timestamp;
  }
}

/** 运动消耗记录 */
export class ExerciseRecord {
  id: string = '';
  dayKey: string = '';
  timestamp: number = 0;
  /** 运动名，如「跑步」「快走」 */
  name: string = '';
  /** 消耗热量（千卡） */
  kcal: number = 0;
  /** 时长（分钟），0 表示未记录 */
  minutes: number = 0;
  /** 数据来源：manual = 手动录入，health = 华为运动健康同步 */
  origin: string = 'manual';

  constructor(id: string, dayKey: string, timestamp: number, name: string, kcal: number,
    minutes: number, origin: string) {
    this.id = id;
    this.dayKey = dayKey;
    this.timestamp = timestamp;
    this.name = name;
    this.kcal = kcal;
    this.minutes = minutes;
    this.origin = origin;
  }
}

/**
 * 一天的热量结算结果。
 *
 * 热量缺口（deficit）的定义：
 *   缺口 = 每日预算（TDEE，已按目标调整） + 运动消耗 - 摄入
 * 正数表示还有余量（缺口），负数表示超标。
 */
export class DailySummary {
  /** 日期 YYYY-MM-DD */
  dayKey: string = '';
  /** 当天总摄入（千卡） */
  intake: number = 0;
  /** 每天的基础热量预算（千卡）—— BMR 按活动系数与目标调整后的结果 */
  budget: number = 0;
  /** 运动额外消耗（千卡） */
  exerciseKcal: number = 0;
  /** 热量缺口 = budget + exerciseKcal - intake，正数为缺口 */
  deficit: number = 0;
  protein: number = 0;
  fat: number = 0;
  carb: number = 0;
  /** 当天记录条数 */
  recordCount: number = 0;

  constructor(dayKey: string, intake: number, budget: number, exerciseKcal: number,
    protein: number, fat: number, carb: number, recordCount: number) {
    this.dayKey = dayKey;
    this.intake = intake;
    this.budget = budget;
    this.exerciseKcal = exerciseKcal;
    this.deficit = budget + exerciseKcal - intake;
    this.protein = protein;
    this.fat = fat;
    this.carb = carb;
    this.recordCount = recordCount;
  }
}

/** 食物记录草稿 —— AI 识别或查表后，提交给用户确认前的中间结构 */
export class FoodDraft {
  name: string = '';
  grams: number = 0;
  kcal: number = 0;
  protein: number = 0;
  fat: number = 0;
  carb: number = 0;
  confidence: string = '';
  source: FoodSource = FoodSource.AI;
  note: string = '';

  constructor(name: string, grams: number, kcal: number, protein: number, fat: number,
    carb: number, confidence: string, source: FoodSource, note: string) {
    this.name = name;
    this.grams = grams;
    this.kcal = kcal;
    this.protein = protein;
    this.fat = fat;
    this.carb = carb;
    this.confidence = confidence;
    this.source = source;
    this.note = note;
  }
}
