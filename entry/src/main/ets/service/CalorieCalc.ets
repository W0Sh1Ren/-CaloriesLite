/**
 * 热量计算引擎。
 *
 * 推算链条：
 *   1. BMR（基础代谢率）—— 用 Mifflin-St Jeor 公式，比 Harris-Benedict 更贴近现代人群
 *        男性：BMR = 10×体重(kg) + 6.25×身高(cm) − 5×年龄 + 5
 *        女性：BMR = 10×体重(kg) + 6.25×身高(cm) − 5×年龄 − 161
 *   2. TDEE（每日总消耗）= BMR × 活动系数
 *   3. 每日热量预算 = TDEE + 目标调整量（减脂为负、增重为正）
 *
 * 热量缺口 = 每日预算 + 运动消耗 − 当日摄入
 */
import { activityFactor, goalAdjust } from '../model/Enums';
import { Gender, UserProfile } from '../model/Types';

/** 安全下限，避免用户瞎填导致预算为负或离谱 */
const MIN_WEIGHT_KG = 25;
const MIN_HEIGHT_CM = 100;
const MAX_AGE = 120;
/** 无论怎么算，每日预算不低于这个值（低于基础代谢太多不健康） */
const FLOOR_BMR_RATIO = 1.0;

/** 计算 BMR（基础代谢率，千卡/天） */
export function calcBmr(profile: UserProfile): number {
  const weight: number = clamp(profile.weightKg, MIN_WEIGHT_KG, 300);
  const height: number = clamp(profile.heightCm, MIN_HEIGHT_CM, 250);
  const age: number = clamp(profile.age, 10, MAX_AGE);

  const base: number = 10 * weight + 6.25 * height - 5 * age;
  const genderOffset: number = profile.gender === Gender.MALE ? 5 : -161;
  return Math.max(600, base + genderOffset);
}

/** 计算 TDEE（每日总消耗，千卡/天）= BMR × 活动系数 */
export function calcTdee(profile: UserProfile): number {
  return calcBmr(profile) * activityFactor(profile.activityLevel);
}

/**
 * 每日热量目标的**安全地板**（千卡）。
 *
 * 减脂时目标不会低于 BMR —— 避免用户把目标设得比基础代谢还低。
 * 这是医学上的常见建议，但**它会让用户选的目标失效**，
 * 所以界面上必须能看出「地板生效了」（见 isBudgetFloored）。
 */
export function budgetFloor(profile: UserProfile): number {
  return calcBmr(profile) * FLOOR_BMR_RATIO;
}

/**
 * 按目标调整后、**尚未受地板限制**的每日目标（千卡）。
 *
 * 即 `TDEE + 目标调整`。增重时为正、快速减脂时为负调整。
 * 单独暴露出来是为了在界面上对比「用户想要的」与「实际生效的」。
 */
export function requestedBudget(profile: UserProfile): number {
  return Math.round(calcTdee(profile) + goalAdjust(profile.goal));
}

/**
 * 每日热量目标是否被 BMR 地板抬高了。
 *
 * 为 true 表示：用户选的目标（如快速减脂 −500）**没有生效**，
 * 实际目标被定在了 BMR。界面应当提示，否则用户以为自己在按目标执行。
 */
export function isBudgetFloored(profile: UserProfile): boolean {
  return requestedBudget(profile) < Math.round(budgetFloor(profile));
}

/**
 * 每日热量预算。
 *
 * 减脂时不会低于 BMR，避免用户把预算设得比基础代谢还低。
 */
export function calcDailyBudget(profile: UserProfile): number {
  const tdee: number = calcTdee(profile);
  const adjusted: number = tdee + goalAdjust(profile.goal);
  const floor: number = calcBmr(profile) * FLOOR_BMR_RATIO;
  return Math.round(Math.max(adjusted, floor));
}

/** 按当前体重与目标体重，估算达到目标需要多少天（按每公斤脂肪约 7700 千卡） */
export function estimateDaysToGoal(profile: UserProfile, targetWeightKg: number): number {
  const budget: number = calcDailyBudget(profile);
  const tdee: number = calcTdee(profile);
  const dailyGap: number = tdee - budget;
  if (dailyGap <= 0) {
    return -1; // 当前目标不是减脂，或预算未形成缺口
  }
  const deltaKg: number = profile.weightKg - targetWeightKg;
  if (deltaKg <= 0) {
    return 0; // 已经达标
  }
  return Math.ceil(deltaKg * 7700 / dailyGap);
}

/** 按体重算出 BMI */
export function calcBmi(weightKg: number, heightCm: number): number {
  if (heightCm <= 0) {
    return 0;
  }
  const h: number = heightCm / 100;
  return weightKg / (h * h);
}

/** BMI 对应的中文分级 */
export function bmiLabel(bmi: number): string {
  if (bmi <= 0) {
    return '';
  }
  if (bmi < 18.5) {
    return '偏瘦';
  }
  if (bmi < 24) {
    return '正常';
  }
  if (bmi < 28) {
    return '超重';
  }
  return '肥胖';
}

/**
 * 按体重估算运动消耗（千卡）。
 *
 * 用 MET 值：消耗 = MET × 体重(kg) × 时长(小时)
 * 这是运动医学通用公式，比「按分钟拍脑袋」准得多。
 */
export function calcExerciseKcal(met: number, weightKg: number, minutes: number): number {
  const hours: number = minutes / 60;
  return Math.round(met * weightKg * hours);
}

/** 常见运动的 MET 值表 */
export class MetItem {
  name: string;
  met: number;

  constructor(name: string, met: number) {
    this.name = name;
    this.met = met;
  }
}

export const MET_TABLE: MetItem[] = [
  new MetItem('慢走', 2.8),
  new MetItem('快走', 4.3),
  new MetItem('慢跑', 7.0),
  new MetItem('跑步 8km/h', 8.3),
  new MetItem('跑步 10km/h', 9.8),
  new MetItem('骑行', 6.8),
  new MetItem('游泳', 7.0),
  new MetItem('跳绳', 11.0),
  new MetItem('力量训练', 5.0),
  new MetItem('瑜伽', 2.5),
  new MetItem('篮球', 6.5),
  new MetItem('羽毛球', 5.5),
  new MetItem('足球', 7.0),
  new MetItem('爬楼梯', 8.8),
  new MetItem('跳操/HIIT', 8.0)
];

function clamp(value: number, min: number, max: number): number {
  if (Number.isNaN(value)) {
    return min;
  }
  return Math.min(Math.max(value, min), max);
}
