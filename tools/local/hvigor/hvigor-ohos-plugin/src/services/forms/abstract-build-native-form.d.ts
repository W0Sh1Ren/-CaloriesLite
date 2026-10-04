import { CacheStoreManager } from '@ohos/hvigor';
import { ExternalNativeOpt } from '../../options/build/build-opt.js';
import { TargetTaskService } from '../../tasks/service/target-task-service.js';
type NativeExecutionArgs = {
    commandLine: string[];
    logFolder: string;
};
/**
 * BuildNativeWithNinja和BuildNativeWithCmake的抽象父类
 *
 * @since 2026/4/29
 */
export declare abstract class AbstractBuildNativeForms {
    protected readonly _nativeOption?: ExternalNativeOpt;
    protected constructor(targetService: TargetTaskService);
    /**
     * 执行编译命令
     *
     * @param commandLine 命令行
     * @param dir
     * @param callback 回调函数
     * @param callbackInput 回调函数的输入
     * @param subDurationEvent 子事件
     */
    protected executeCommand(commandLine: string[], dir: string, callback: (...args: unknown[]) => Promise<void> | void, callbackInput: unknown[]): Promise<void>;
}
export declare const nativeExecution: (args: NativeExecutionArgs, workerCacheManager?: CacheStoreManager) => Promise<void>;
export {};
