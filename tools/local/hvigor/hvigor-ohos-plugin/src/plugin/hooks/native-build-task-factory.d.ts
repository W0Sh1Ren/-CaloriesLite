import { HvigorCoreNode } from '@ohos/hvigor';
import { TargetTaskService } from '../../tasks/service/target-task-service.js';
/**
 * Native构建任务工厂
 */
export declare class NativeBuildTaskFactory {
    /**
     * 创建并执行ConfigureCmake任务（类调用形式）
     */
    static createAndExecuteConfigureCmake(targetTaskService: TargetTaskService, moduleName: string): Promise<void>;
    /**
     * 创建并执行BuildNativeWithCmake任务（类调用形式）
     */
    static createAndExecuteBuildNativeWithCmake(targetTaskService: TargetTaskService, moduleName: string): Promise<void>;
    /**
     * 处理 compile_commands.json 文件
     * 成功时复制到 tools 目录，失败时删除 tools 目录中的文件
     */
    private static handleCompileCommandsJson;
    /**
     * 删除 tools 目录中的 compile_commands.json 文件（构建失败时调用）
     */
    private static deleteCompileCommandsJson;
    /**
     * 执行单个模块的完整native构建流程（串行）
     */
    static executeModuleNativeBuildChain(module: HvigorCoreNode, targetTaskService: TargetTaskService): Promise<void>;
    /**
     * 判断是否需要执行native构建任务
     */
    private static shouldDoNative;
    /**
     * 获取当前 target 中的 abiFilters
     */
    private static getAbiFilters;
}
