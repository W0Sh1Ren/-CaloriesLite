export declare namespace PreviewBuildConfigOptions {
    interface StageRouterConfigObj {
        contents: string[];
        paths: string[];
    }
    interface BuildConfigObj {
        deviceType?: string;
        checkEntry?: string;
        localPropertiesPath?: string;
        Path?: string;
        note?: string;
        isPreview?: string;
        hapMode?: string;
        buildMode?: string;
        img2bin?: string;
        projectProfilePath?: string;
        watchMode?: string;
        appResource?: string;
        logLevel?: string;
        port?: string;
        aceBuildJson?: string;
        aceModuleRoot?: string;
        aceSoPath?: string;
        cachePath?: string;
        aceModuleBuild?: string;
        aceSuperVisualPath?: string;
        aceModuleJsonPath?: string;
        aceProfilePath?: string;
        previewPagePath?: string;
        stageRouterConfig?: StageRouterConfigObj;
    }
}
