/**
 * 每日结算服务。
 *
 * 把「预算、摄入、运动」三块数据汇成一天的结算结果，是首页与日历的数据来源。
 */
import { MealType, ExerciseRecord, FoodRecord, DailySummary, UserProfile, WeightRecord } from '../model/Types';
import { mealTypeLabel } from '../model/Enums';
import { todayKey, shiftDay, fromDayKey, toDayKey } from '../common/DateUtil';
import { calcDailyBudget, calcTdee, calcBmr, isBudgetFloored, requestedBudget } from './CalorieCalc';
import { ExerciseRepo } from './ExerciseRepo';
import { FoodRepo } from './FoodRepo';
import { BodyRepo } from './BodyRepo';
import { SettingsRepo } from './SettingsRepo';

/** 首页需要的全部数据，一次算完交给 UI */
export class HomeData {
  summary: DailySummary = new DailySummary('', 0, 0, 0, 0, 0, 0, 0, 0);
  records: FoodRecord[] = [];
  exercises: ExerciseRecord[] = [];
  /** 连续「达标」天数：从今天往回数，每天缺口 >= 0 才算达标 */
  streak: number = 0;
  /** 最近 7 天的缺口，从旧到新，用于首页迷你柱状图 */
  weekDeficits: number[] = [];
  /** 最近 7 天的 dayKey，与 weekDeficits 一一对应 */
  weekDays: string[] = [];
  bmr: number = 0;
  tdee: number = 0;
  /**
   * BMR 安全地板是否抬高了每日目标。
   *
   * 当「TDEE + 目标调整」低于 BMR 时会触发（`calcDailyBudget`）。
   * 触发意味着**用户选的目标没能生效**，界面上必须说明，
   * 否则用户会以为自己在按 −500 执行，实际不是。
   */
  floorApplied: boolean = false;
  /**
   * 没有被地板修正时，用户目标本来会得到的每日目标。
   *
   * 仅用于在地板生效时告诉用户「你原本要的是多少、现在被定成了多少」。
   * 地板未生效时它等于 budget。
   */
  requestedBudget: number = 0;
}

export class DailyService {

  /**
   * 取当前生效的档案。
   *
   * 体重以最新一条体重记录为准 —— 用户开始记体重后，
   * 基础热量会随体重真实变化，而不是一直用设置里那个初始值。
   */
  static effectiveProfile(): UserProfile {
    const profile: UserProfile = SettingsRepo.loadProfile();
    const latest: number = DailyService.latestWeight();
    if (latest > 0) {
      profile.weightKg = latest;
    }
    return profile;
  }

  /** 最新体重：优先体重记录，其次档案里的初始体重 */
  static latestWeight(): number {
    const latest: WeightRecord | null = BodyRepo.latest();
    if (latest !== null && latest.weightKg > 0) {
      return latest.weightKg;
    }
    return SettingsRepo.loadProfile().weightKg;
  }

  /** 每日热量预算 */
  static budget(): number {
    return calcDailyBudget(DailyService.effectiveProfile());
  }

  /** 组装某一天的结算结果 */
  static summaryOf(dayKey: string): DailySummary {
    const profile: UserProfile = DailyService.effectiveProfile();
    const budget: number = calcDailyBudget(profile);
    // 缺口要用 TDEE 而不是 budget 来算（budget 可能被 BMR 地板抬高）。
    // 理由见 DailySummary 的类注释。
    const tdee: number = Math.round(calcTdee(profile));
    const records: FoodRecord[] = FoodRepo.loadDay(dayKey);

    let intake: number = 0;
    let protein: number = 0;
    let fat: number = 0;
    let carb: number = 0;
    for (const r of records) {
      intake += r.kcal;
      protein += r.protein;
      fat += r.fat;
      carb += r.carb;
    }

    const exerciseKcal: number = ExerciseRepo.kcalOfDay(dayKey);

    return new DailySummary(
      dayKey,
      Math.round(intake),
      budget,
      tdee,
      exerciseKcal,
      Math.round(protein * 10) / 10,
      Math.round(fat * 10) / 10,
      Math.round(carb * 10) / 10,
      records.length
    );
  }

  /** 首页一次性取全所需数据 */
  static homeData(dayKey: string): HomeData {
    const data: HomeData = new HomeData();
    const profile: UserProfile = DailyService.effectiveProfile();

    data.summary = DailyService.summaryOf(dayKey);
    data.records = FoodRepo.loadDay(dayKey);
    data.exercises = ExerciseRepo.loadDay(dayKey);
    data.bmr = Math.round(calcBmr(profile));
    data.tdee = Math.round(calcTdee(profile));
    data.streak = DailyService.calcStreak();

    // 地板是否把用户选的目标顶掉了（首页需要据此提示）
    data.floorApplied = isBudgetFloored(profile);
    data.requestedBudget = requestedBudget(profile);

    const days: string[] = [];
    const deficits: number[] = [];
    for (let i = 6; i >= 0; i--) {
      const d: string = shiftDay(dayKey, -i);
      days.push(d);
      // 未来的日期不参与统计
      if (fromDayKey(d) > Date.now()) {
        deficits.push(0);
      } else {
        deficits.push(DailyService.summaryOf(d).deficit);
      }
    }
    data.weekDays = days;
    data.weekDeficits = deficits;
    return data;
  }

  /**
   * 连续达标天数。
   *
   * 达标 = 当天有记录 且 缺口 >= 0（没超预算）。
   * 从今天往前数，今天还没记录不算断档。
   */
  static calcStreak(): number {
    let streak: number = 0;
    let cursor: string = todayKey();

    // 今天若还没记录，从昨天开始数，避免早上打开 APP 就显示断档
    const todayRecords: FoodRecord[] = FoodRepo.loadDay(cursor);
    if (todayRecords.length === 0) {
      cursor = shiftDay(cursor, -1);
    }

    // 最多回看一年，防止极端数据造成死循环
    for (let i = 0; i < 365; i++) {
      const records: FoodRecord[] = FoodRepo.loadDay(cursor);
      if (records.length === 0) {
        break;
      }
      const s: DailySummary = DailyService.summaryOf(cursor);
      if (s.deficit < 0) {
        break;
      }
      streak++;
      cursor = shiftDay(cursor, -1);
    }
    return streak;
  }

  /** 某天的缺口（供日历使用） */
  static deficitOf(dayKey: string): number {
    return DailyService.summaryOf(dayKey).deficit;
  }

  /**
   * 某个月的热量缺口合计（供记录页的「本月缺口」使用）。
   *
   * 累加的是**实际缺口**（`DailySummary.deficit` = TDEE + 运动 − 摄入），
   * 不是「相对每日目标的余量」。两者的差别：
   *   每日目标本身已经含了「计划要减的那部分」（例如 TDEE − 500），
   *   所以「相对目标的余量」在按计划吃的那天会显示 0，
   *   而实际缺口应该是 500 —— 那才是身体真正亏掉的能量。
   *
   * **只统计有记录的天数**（用户要求）：没记录的那天不算 0 缺口，
   * 而是直接跳过 —— 否则会把「没吃也没记」误算成「刚好达标」，
   * 一个月的合计会被大量空白天数摊薄。
   *
   * 参数 year / month0 是「视图正在看的月份」（取自日历的 viewYear / viewMonth0），
   * 所以翻月份时这个数字会跟着变。
   * 统计到「今天」为止：未来不可能有记录。
   */
  static monthDeficit(year: number, month0: number): number {
    const today: string = todayKey();
    const daysInMonth: number = new Date(year, month0 + 1, 0).getDate();
    let sum: number = 0;
    for (let day = 1; day <= daysInMonth; day++) {
      // 用本地时区构造当天 0 点，再交给 toDayKey 统一格式化，
      // 避免自己拼字符串时漏掉前导零
      const key: string = toDayKey(new Date(year, month0, day).getTime());
      if (key > today) {
        break;
      }
      if (FoodRepo.loadDay(key).length === 0) {
        continue;
      }
      sum += DailyService.summaryOf(key).deficit;
    }
    return Math.round(sum);
  }

  /** 按餐次分组某天的记录 */
  static recordsByMeal(dayKey: string): Map<MealType, FoodRecord[]> {
    return FoodRepo.groupByMeal(FoodRepo.loadDay(dayKey));
  }

  /** 从一个已有的记录数组里筛出某餐次的条目，避免 UI 里重复写 filter */
  static recordsOf(records: FoodRecord[], meal: MealType): FoodRecord[] {
    return records.filter((r: FoodRecord) => r.mealType === meal);
  }

  /** 生成一句结算评语，首页展示 */
  static verdict(summary: DailySummary): string {
    if (summary.recordCount === 0) {
      return '今天还没有记录，拍张照开始吧';
    }
    if (summary.deficit < -300) {
      return `超出预算 ${-summary.deficit} 千卡`;
    }
    if (summary.deficit < 0) {
      return `略微超出 ${-summary.deficit} 千卡，明天注意`;
    }
    if (summary.deficit <= 200) {
      return '刚好卡在预算线内，很稳';
    }
    if (summary.deficit <= 600) {
      return `还有 ${summary.deficit} 千卡余量，缺口健康`;
    }
    return `缺口 ${summary.deficit} 千卡，吃得偏少，注意别饿着`;
  }

  /** 餐次中文名的便捷转发，避免页面各处重复 import */
  static mealName(type: MealType): string {
    return mealTypeLabel(type);
  }
}
