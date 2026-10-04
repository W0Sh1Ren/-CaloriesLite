import { CopyOptions } from '../tasks/worker/copy-job.js';
export interface CopyConfig {
    /**
     * 是否为预览模式
     */
    isPreview?: boolean;
    /**
     * 当前编译任务所属模块到ets目录的路径,例如：entry/src/main/ets
     */
    aceModuleRoot: string;
    /**
     * 当前编译任务的build目录
     */
    aceModuleBuild?: string;
    /**
     * 当前编译任务的abilityType，仅限fa模型存在
     */
    abilityType?: string;
    /**
     * 当前编译任务的manifest.json的路径
     */
    aceManifestPath?: string;
    /**
     * 编译任务缓存的路径
     */
    cachePath?: string;
    /**
     * resourceTable.txt的路径
     */
    appResource?: string;
    /**
     * copyCodeResource: 用户配置的静态资源复制文件使能以及过滤规则
     */
    copyCodeResourceEnable?: boolean;
    copyCodeResourceExcludes?: string[];
    copyCodeResourceIncludes?: string[];
}
export declare function getCopyOptions(copyConfig: CopyConfig): CopyOptions;
export declare function toUnixPath(data: string): string;
/**
 * 将路径转化为Posix路径，与toUnixPath区别在于：
 * 1、toUnixPath在Unix平台，对路径不作不转化，直接使用
 * 2、toPosixPath在Unix平台，对路径也会转化，能解决windows路径在Unix平台使用问题
 * @param dir 路径
 * @return string
 */
export declare function toPosixPath(dir: string): string;
