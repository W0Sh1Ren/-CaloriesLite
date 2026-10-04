import { AdaptorErrorMessage } from '@ohos/hvigor-logger';
type ConfigPropertiesValue = string | number | boolean;
interface ConfigProperties {
    [key: string]: ConfigPropertiesValue | Record<string, ConfigPropertiesValue | object>;
}
declare class HvigorTrace {
    static readonly TRACE_KEY = "HVIGOR";
    private data;
    private configBlacklist;
    constructor();
    /**
     * 传输数据给打点管理中心并且在落盘后清理数据
     */
    transmitDataToManager(): void;
    traceTotalTime(totalTime: number): void;
    /**
     * 记录并行、增量、daemon、类型检查、分析模式的配置的值
     */
    traceBaseConfig(IS_INCREMENTAL: boolean, IS_DAEMON: boolean, IS_PARALLEL: boolean, IS_HVIGORFILE_TYPE_CHECK: boolean, OPTIMIZATION_STRATEGY: string): void;
    traceBuildAnalysisMode(BUILD_ANALYSIS_MODE: string | undefined | boolean): void;
    /**
     * 记录hvigor配置enable ohpm execution by hvigor的配置值
     * @param IS_EXECUTION_OHPM_BY_HVIGOR
     */
    traceExecutionByOhpm(IS_EXECUTION_OHPM_BY_HVIGOR: boolean): void;
    /**
     * 记录hvigor配置Enable C++ syncNative compilation的配置值
     * @param IS_SYNCNATIVE_COMPILATION
     */
    traceSyncNative(IS_SYNCNATIVE_COMPILATION: boolean | undefined): void;
    traceBuildId(buildId: string): void;
    /**
     * 记录构建的进程id
     * @param pid
     */
    traceBuildProcessPid(pid: number): void;
    traceCustomPluginTime(pluginId: string | undefined, totalTime: number): void;
    traceTaskTime(taskName: string, moduleName: string, time: number): void;
    traceCustomTaskTime(taskName: string, moduleName: string, time: number): void;
    traceErrorMessage(adaptorErrorMessage: AdaptorErrorMessage): void;
    insertUsedApi(apiName: string): void;
    traceConfigProperties(configProperties: ConfigProperties): void;
    traceExperimentFeature(name: string, value: boolean | string): void;
}
export declare const hvigorTrace: HvigorTrace;
export {};
