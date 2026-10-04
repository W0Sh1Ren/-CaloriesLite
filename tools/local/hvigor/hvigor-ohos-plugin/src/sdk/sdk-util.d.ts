import { Component, OhLocalComponentLoader, PathAndApiVersion, SdkProxyInfo } from '@ohos/sdkmanager-common';
import { ProjectBuildProfile } from '../options/build/project-build-profile.js';
import { AppJson } from '../options/configure/app-json-options.js';
import { ModuleJson } from '../options/configure/module-json-options.js';
import ApiMeta = ProjectBuildProfile.ApiMeta;
import AppObj = AppJson.AppObj;
import ModuleObj = ModuleJson.ModuleObj;
interface HarModuleOpt {
    app: AppObj;
    module: ModuleObj;
}
/**
 * 根据OpenHarmony sdk目录结构规则预测是否存在相关组件
 * /${OhosSdkRoot}/${API}/${component}
 * /sdk/openharmony/10/toolchains
 *
 * @param sdkDir
 * @param version
 * @param components
 */
export declare const ohosPredict: (sdkDir: string, version: string, components: string[]) => Map<PathAndApiVersion, Component>;
/**
 * 复用sdk-manager的oh-uni-package.json的解析能力
 */
export declare class OhosParser extends OhLocalComponentLoader {
    constructor(sdkRoot: string);
    parse(packages: string[]): Component[];
}
/**
 * 解析compileSdkVersion，compatibleSdkVersion，targetSdkVersion为ApiMeta对象
 *
 * @param sdkVersion 用户在build-profile里配置的compileSdkVersion，compatibleSdkVersion，targetSdkVersion
 * @param isHarmonyOS 判断是否为HarmonyOS项目
 */
export declare const parseApiVersion: (sdkVersion: string | number, isHarmonyOS: boolean) => ProjectBuildProfile.ApiMeta;
export declare const proxyFun: () => SdkProxyInfo;
export declare const contains: (pathAndApi: string, all: Map<string, Component>) => Component | undefined;
export declare const handleSdkException: (ex: any) => void;
/**
 * 转换API版本
 * @param api ApiMeta对象
 * @returns 转换后的API版本
 */
export declare const apiTransform: (api: ApiMeta) => number;
/**
 * 转换 compatibleSdkVersion 用于比较最低兼容版本,如 26 转为 260000,6.1.1(24) 转为 240000
 * @param compatibleSdkVersion 工程的最低兼容版本
 * @returns 转换后的版本号
 */
export declare const compatibleSdkVersionTransform: (compatibleSdkVersion: {
    major: number;
    minor?: number;
    patch?: number;
}) => number;
/**
 * 转换 harMinApiVersion 用于比较最低兼容版本,如 26 转为 260000,6.1.1(24) 转为 240000
 * @param harMinApiVersion HAR模块的最低兼容版本
 * @param harModuleOpt har模块相关配置
 * @returns 转换后的版本号
 */
export declare const harMinApiVersionTransform: (harMinApiVersion: string, harModuleOpt: HarModuleOpt) => number;
export {};
