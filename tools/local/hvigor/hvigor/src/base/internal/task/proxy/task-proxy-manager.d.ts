import type { TaskProxy } from './task-proxy.js';
declare class TaskProxyManager {
    private proxyCache;
    constructor();
    reset(): void;
    /**
     * 转换单个增量Task
     *
     * @return {TaskProxy}
     * @param taskPath
     * @param taskProxy
     */
    set(taskPath: string, taskProxy: TaskProxy): TaskProxy;
    /**
     * 根据Task的Path获取当前缓存的TaskProxy对象
     *
     * @param {string} taskPath
     * @return {TaskProxy | undefined}
     */
    getTaskProxy(taskPath: string): TaskProxy | undefined;
    getAllIncrementalTaskProxy(): TaskProxy[];
}
export declare const taskProxyManager: TaskProxyManager;
export {};
