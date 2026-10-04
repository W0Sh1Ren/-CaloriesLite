/**
 * 同步保险钩子，支持批量清理所有实例的监听器
 */
export declare class SyncBailHook {
    private static instances;
    private taps;
    constructor();
    /**
     * 注册监听函数
     * @param fn  返回非 undefined 即短路
     */
    tap(fn: (...args: unknown[]) => unknown): void;
    /**
     * 触发钩子
     * @returns 第一个非 undefined 返回值，否则 undefined
     */
    call(...args: unknown[]): unknown;
    /**
     * 清空当前钩子的监听器（保留实例）
     */
    clear(): void;
    /**
     * 销毁当前钩子：清空监听器并从注册表中移除
     */
    dispose(): void;
    /**
     * 静态方法：清空所有存活钩子实例的监听器
     */
    static dispose(): void;
}
export declare const shouldPackageHapHook: SyncBailHook;
export declare const shouldIncrementalExecutionHook: SyncBailHook;
