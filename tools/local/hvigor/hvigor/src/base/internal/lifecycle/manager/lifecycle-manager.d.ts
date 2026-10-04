import { HookType } from '../../../../common/const/hook-const.js';
/**
 * 全局生命周期管理器
 * 提供hook执行记录的查询能力
 */
declare class LifecycleManager {
    /**
     * 已执行过的hook集合
     */
    private executedHooks;
    /**
     * 当前正在执行的hook
     */
    private executingHookType;
    /**
     * 当前正在执行的插件ID
     */
    private executingPluginId;
    constructor();
    /**
     * 记录hook已执行
     *
     * @param hookType hook类型
     */
    recordHookExecuted(hookType: HookType): void;
    setExecutingHookType(hookName: string | undefined): void;
    getExecutingHookType(): string | undefined;
    /**
     * 重置生命周期状态
     * 通常在新的构建开始时被调用
     */
    reset(): void;
    setExecutingPluginId(pluginId: string | undefined): void;
    getExecutingPluginId(): string | undefined;
    /**
     * 检查configEvaluated hook是否已被执行过
     */
    hasConfigEvaluatedHookExecuted(): boolean;
    /**
     * 检查nodesInitialized hook是否已被执行过
     */
    hasNodesInitializedHookExecuted(): boolean;
    /**
     * 检查beforeNodeEvaluate hook是否已被执行过
     * 每个node都有beforeNodeEvaluate，只要有一个node下的hook被执行就会返回True
     */
    hasBeforeNodeEvaluateHookExecuted(): boolean;
    /**
     * 检查afterNodeEvaluate hook是否已被执行过
     * 每个node都有afterNodeEvaluate，只要有一个node下的hook被执行就会返回True
     */
    hasAfterNodeEvaluateHookExecuted(): boolean;
    /**
     * 检查nodesEvaluated hook是否已被执行过
     */
    hasNodesEvaluatedHookExecuted(): boolean;
    /**
     * 检查taskGraphResolved hook是否已被执行过
     */
    hasTaskGraphResolvedHookExecuted(): boolean;
    /**
     * 检查buildFinished hook是否已被执行过
     */
    hasBuildFinishedHookExecuted(): boolean;
    /**
     * 检查指定hook是否已被执行过
     * @param hookType hook类型
     */
    hasHookExecuted(hookType: HookType): boolean;
    /**
     * 获取所有已执行的hook列表
     */
    getExecutedHooks(): HookType[];
}
export declare const lifecycleManager: LifecycleManager;
export {};
