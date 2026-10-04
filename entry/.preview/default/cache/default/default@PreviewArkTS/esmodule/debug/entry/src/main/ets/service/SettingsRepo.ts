import { Store } from "@normalized:N&&&entry/src/main/ets/common/Store&";
import { getBool, getNum, getStr, parseObject, toEnum } from "@normalized:N&&&entry/src/main/ets/common/JsonUtil&";
import type { JsonMap } from "@normalized:N&&&entry/src/main/ets/common/JsonUtil&";
import { ACTIVITY_ORDER, AI_BASE_URL, AI_MODEL, GOAL_ORDER } from "@normalized:N&&&entry/src/main/ets/model/Enums&";
import { ActivityLevel, AiConfig, AiProvider, Gender, Goal, UserProfile } from "@normalized:N&&&entry/src/main/ets/model/Types&";
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
    // 默认填好地址与模型，用户只需再粘一个 API Key
    return new AiConfig(AiProvider.OPENAI_COMPATIBLE, AI_BASE_URL, '', AI_MODEL);
}
/**
 * 模型名/地址迁移表。
 *
 * 服务商换过一轮（智谱 → DeepSeek），老用户存的是智谱的地址与模型名，
 * 直接沿用会 404。这里按旧模型名把地址和模型名一起换成新服务商的。
 */
class AiMigration {
    model: string;
    baseUrl: string;
    constructor(model: string, baseUrl: string) {
        this.model = model;
        this.baseUrl = baseUrl;
    }
}
const AI_MIGRATIONS: Map<string, AiMigration> = (() => {
    const m: Map<string, AiMigration> = new Map<string, AiMigration>();
    // 智谱的两个模型名，都迁到当前的 DeepSeek 配置
    m.set('glm-4v-flash', new AiMigration(AI_MODEL, AI_BASE_URL));
    m.set('glm-4.6v-flash', new AiMigration(AI_MODEL, AI_BASE_URL));
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
        return new UserProfile(getStr(map, 'nickname', def.nickname), toEnum<Gender>(getStr(map, 'gender', def.gender), ALL_GENDERS, def.gender), getNum(map, 'age', def.age), getNum(map, 'heightCm', def.heightCm), getNum(map, 'weightKg', def.weightKg), toEnum<ActivityLevel>(getStr(map, 'activityLevel', def.activityLevel), ACTIVITY_ORDER, def.activityLevel), toEnum<Goal>(getStr(map, 'goal', def.goal), GOAL_ORDER, def.goal));
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
        // 老配置存的是智谱的模型名与地址，这里整组迁到当前服务商，
        // 否则沿用旧地址会直接 404。
        let model: string = getStr(map, 'model', def.model);
        let baseUrl: string = getStr(map, 'baseUrl', def.baseUrl);
        let apiKey: string = getStr(map, 'apiKey', '');
        const migrated: AiMigration | undefined = AI_MIGRATIONS.get(model);
        if (migrated !== undefined) {
            model = migrated.model;
            baseUrl = migrated.baseUrl;
            // Key 是跟着服务商走的，换了服务商旧 Key 必然无效（会直接 401）。
            // 与其让用户对着一个「已配置」却报错的界面，不如清掉，
            // 让「未配置」的状态如实反映需要重新填 Key。
            apiKey = '';
        }
        return new AiConfig(toEnum<AiProvider>(getStr(map, 'provider', def.provider), ALL_PROVIDERS, def.provider), baseUrl, apiKey, model, getBool(map, 'thinking', def.thinking));
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
