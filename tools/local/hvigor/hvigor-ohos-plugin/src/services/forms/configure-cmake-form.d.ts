import { TargetTaskService } from '../../tasks/service/target-task-service.js';
import { PackageResolver } from '../../utils/native-cmake-resolver.js';
/**
 * ConfigureCmake的类调用形式实现
 */
export declare class ConfigureCmakeForm {
    private readonly targetTaskService;
    private readonly nativeOption?;
    private readonly dependencies;
    private readonly cmakeDir;
    private readonly abiList;
    protected readonly packages: PackageResolver[];
    constructor(targetTaskService: TargetTaskService);
    /**
     * 检查是否需要配置
     */
    shouldDo(): boolean;
    /**
     * 执行配置
     */
    execute(): Promise<void>;
    /**
     * 初始化CMake配置
     */
    private init;
    /**
     * 写入CMake脚本
     */
    private writeCmakeScript;
    /**
     * 生成CMake find文件
     */
    private genCmakeFindFile;
    /**
     * 判断是否为本地依赖
     */
    private isLocal;
    /**
     * 获取模块目标
     */
    private getModuleTarget;
    /**
     * 判断是否为native库
     */
    private isNativeLibrary;
}
