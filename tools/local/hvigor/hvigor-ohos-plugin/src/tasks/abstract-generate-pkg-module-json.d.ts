import { TargetTaskService } from './service/target-task-service.js';
import { OhosHapTask } from './task/ohos-hap-task.js';
export declare abstract class AbstractGeneratePkgModuleJson extends OhosHapTask {
    protected readonly jsonPath: string;
    protected readonly packageHapJsonPath: string;
    private readonly preloadSoJsonPath;
    private readonly librarySupportDirectory;
    private readonly enableSoDirCollection;
    private shouldDeduplicateHar;
    private getLibrarySupportDirectory;
    protected getUseNormalizedOHMUrl(): boolean;
    protected abstract getJsonPath(): string;
    constructor(taskService: TargetTaskService);
    private ensureAppStartup;
    /**
     * har包去重时hsp的module.json中添加deduplicateHar字段来标识去重
     */
    private writeDeduplicateHarField;
    protected doTaskAction(): Promise<void>;
    private addLibrarySupportDirectory;
    /**
     * 转化skillProfile中的srcEntries
     * 示例："srcEntries": ["../../skills/my-skill/scripts/Main.ets"]
     * 1、useNormalizedOHMUrl为true时，转化为："@normalized:N&&&entry/skills/my-skill/scripts/Main&"
     * 2、useNormalizedOHMUrl为false时，转化为："skills/my-skill/scripts/Main.ets"
     *
     * @param moduleJson
     * @private
     */
    private translateSkillSrcEntries;
    initTaskDepends(): void;
}
