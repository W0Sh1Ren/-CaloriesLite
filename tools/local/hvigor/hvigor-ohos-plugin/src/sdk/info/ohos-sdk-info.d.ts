import { Component, PathAndApiVersion } from '@ohos/sdkmanager-common';
import { ProjectBuildProfile } from '../../options/build/project-build-profile.js';
import { CommonSdkInfo } from './common-sdk-info.js';
import ApiMeta = ProjectBuildProfile.ApiMeta;
export declare class OhosSdkInfo extends CommonSdkInfo {
    private readonly ohComponents;
    private ohosLocalComponents;
    constructor(requireComponents: string[], sdkVersion: ApiMeta, sdkDir: string);
    setOhosMetaCompileSdkVersion(): void;
    setup(): Promise<void>;
    contains(pathAndApi: PathAndApiVersion, all: Map<PathAndApiVersion, Component>): Component | undefined;
    getLibimageTranscoderShared(): string;
    getHosToolchainsLibDir(): string;
    getSystemThemeSchema(): string;
    getShareFilesSchema(): string;
    getSdkPermissionInfoPath(): string;
    getArkDataSchema(): string;
    /**
     * 确认在JDK25的情况下API23的OH项目的SDK是否为错误版本
     *
     */
    checkOHSDKValid(): void;
    private isJava25;
    private isApi22;
    private isApi23WithOldToolchains;
    private isApi24WithOldToolchains;
    getJavaVersion(): string;
}
