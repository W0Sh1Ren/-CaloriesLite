import { DurationEvent } from '@ohos/hvigor';
import { TargetTaskService } from '../../tasks/service/target-task-service.js';
import { AbstractBuildNativeForms } from './abstract-build-native-form.js';
/**
 * BuildNativeWithCmake的类调用形式实现
 */
export declare class BuildNativeWithCmakeForm extends AbstractBuildNativeForms {
    private _log;
    private static readonly sanAbilitySet;
    private readonly targetTaskService;
    constructor(targetTaskService: TargetTaskService);
    /**
     * 检查是否需要构建
     */
    shouldDo(): boolean;
    /**
     * 执行构建
     */
    execute(parentEvent?: DurationEvent): Promise<void>;
    /**
     * 准备构建环境
     */
    private prepareBuildEnvironment;
    /**
     * 执行native构建流程
     */
    private performNativeBuild;
    /**
     * 为指定ABI执行构建
     */
    private buildForAbi;
    /**
     * 构建命令
     */
    private buildCommand;
    /**
     * 确保命令文件存在
     */
    private ensureCommandFile;
    /**
     * 获取cmake回调函数
     */
    private getCmakeCallback;
    /**
     * 获取输入文件列表
     */
    private getInputFiles;
    private getOptionalOutputFiles;
    private getRequiredOutputFiles;
    private getHardOutputFiles;
    private getToolchainFile;
    private getTestCoverageArg;
    private isEnableCppIncrementalBuildArg;
    private addCppIncrementalBuildArg;
    private addNativeArgs;
    private checkSanArgsSupported;
    private checkExclusiveSan;
}
