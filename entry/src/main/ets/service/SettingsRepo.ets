/**
 * 设置仓库：个人基本情况与 AI 识别配置。
 */
import { Store } from '../common/Store';
import { getNum, getStr, JsonMap, parseObject, toEnum } from '../common/JsonUtil';
import { ACTIVITY_ORDER, GLM_BASE_URL, GLM_MODEL, GOAL_ORDER } from '../model/Enums';
import { ActivityLevel, AiConfig, AiProvider, Gender, Goal, UserProfile } from '../model/Types';

const KEY_PROFILE = 'user_profile';
const KEY_AI = 'ai_config';
const KEY_ONBOARDED = 'onboarded';

const ALL_GENDERS: Gender[] = [Gender.MALE, Gender.FEMALE];
const ALL_PROVIDERS: AiProvider[] = [AiProvider.OPENAI_COMPATIBLE, AiProvider.GEMINI];

/** 首次使用时的默认档案，用户填完向导后覆盖 */
function defaultProfile(): UserProfile {
  return new UserProfile('', Gender.MALE, 25, 170, 65, ActivityLevel.LIGHT, Goal.MAINTAIN);
}

function defaultAiConfig(): AiConfig {
  // 默认就填好智谱的地址和免费识图模型，用户只需再粘一个 API Key
  return new AiConfig(AiProvider.OPENAI_COMPATIBLE, GLM_BASE_URL, '', GLM_MODEL);
}

/** 已下线的旧模型名 → 现用模型名，避免老用户配置失效 */
const MODEL_MIGRATIONS: Map<string, string> = (() => {
  const m: Map<string, string> = new Map<string, string>();
  m.set('glm-4v-flash', GLM_MODEL);
  return m;
})();

export class SettingsRepo {

  /** 是否已完成首次设置向导 */
  static isOnboarded(): boolean {
    return Store.getBool(KEY_ONBOARDED, false);
  }

  static setOnboarded(value: boolean): void {
    Store.put(KEY_ONBOARDED, value);
  }

  /** 读个人档案；从未保存过则返回默认值 */
  static loadProfile(): UserProfile {
    const raw: string = Store.getString(KEY_PROFILE, '');
    if (raw.length === 0) {
      return defaultProfile();
    }
    const map: JsonMap | null = parseObject(raw);
    if (map === null) {
      return defaultProfile();
    }
    const def: UserProfile = defaultProfile();
    return new UserProfile(
      getStr(map, 'nickname', def.nickname),
      toEnum<Gender>(getStr(map, 'gender', def.gender), ALL_GENDERS, def.gender),
      getNum(map, 'age', def.age),
      getNum(map, 'heightCm', def.heightCm),
      getNum(map, 'weightKg', def.weightKg),
      toEnum<ActivityLevel>(getStr(map, 'activityLevel', def.activityLevel), ACTIVITY_ORDER, def.activityLevel),
      toEnum<Goal>(getStr(map, 'goal', def.goal), GOAL_ORDER, def.goal)
    );
  }

  static saveProfile(profile: UserProfile): void {
    Store.put(KEY_PROFILE, JSON.stringify(profile));
  }

  /** 是否已经保存过档案 */
  static hasProfile(): boolean {
    return Store.getString(KEY_PROFILE, '').length > 0;
  }

  /** 读 AI 配置 */
  static loadAiConfig(): AiConfig {
    const raw: string = Store.getString(KEY_AI, '');
    if (raw.length === 0) {
      return defaultAiConfig();
    }
    const map: JsonMap | null = parseObject(raw);
    if (map === null) {
      return defaultAiConfig();
    }
    const def: AiConfig = defaultAiConfig();

    // 旧版本存的是 glm-4v-flash，这个模型已下线，自动换成当前的免费识图模型
    let model: string = getStr(map, 'model', def.model);
    const migrated: string | undefined = MODEL_MIGRATIONS.get(model);
    if (migrated !== undefined) {
      model = migrated;
    }

    return new AiConfig(
      toEnum<AiProvider>(getStr(map, 'provider', def.provider), ALL_PROVIDERS, def.provider),
      getStr(map, 'baseUrl', def.baseUrl),
      getStr(map, 'apiKey', ''),
      model
    );
  }

  static saveAiConfig(config: AiConfig): void {
    Store.put(KEY_AI, JSON.stringify(config));
  }

  /** AI 是否已配置可用（三个字段都不能为空） */
  static isAiReady(): boolean {
    const c: AiConfig = SettingsRepo.loadAiConfig();
    return c.baseUrl.trim().length > 0 && c.apiKey.trim().length > 0 && c.model.trim().length > 0;
  }

  /** 清空全部本地数据 */
  static clearAll(): void {
    Store.clearAll();
  }
}
