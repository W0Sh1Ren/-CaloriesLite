export declare class Spinner {
    private defaultText;
    private static instance;
    private isTTY;
    private isSpinning;
    private spinnerPrinted;
    private referenceCount;
    private activeModules;
    private frameIndex;
    private intervalId;
    private originalStdoutWrite;
    private originalStderrWrite;
    private constructor();
    /**
     *  单例模式 获取spinner单例
     */
    static getInstance(): Spinner;
    /**
     * 以模块粒度 开启spinner
     * @param moduleName
     */
    start(moduleName: string): this;
    /**
     * 为模块结束spinner  当所有模块都结束时 spinner彻底停止
     * @param moduleName
     */
    stop(moduleName: string): void;
    /**
     * hvigor 构建结束时 确保进行相应的清理
     */
    static clear(): void;
    /**
     *  多模块编译场景下 对模块名添加 共同进行展示
     *  例如entry hsp1 hsp2
     * @param moduleName
     * @param subTask
     */
    updateModule(moduleName: string, subTask?: string): this;
    /**
     *  判断是否已经启动 spinner
     *
     */
    static isSpinningActive(): boolean;
    /**
     * 清理掉终端当前行的spinner信息 并标记状态
     */
    clearSpinnerLine(): void;
    /**
     * 将logger 或 其他的输出进行保护
     * 停止spinner 信息 -> 输出原有日志 -> 回复spinner信息
     * @param writeFn
     */
    static protect(writeFn: () => void): void;
    /**
     * 暂停输出信息
     */
    pause(): void;
    /**
     *  恢复spinner打印状态
     */
    resume(): void;
    /**
     * 绘制 spinner 信息 到终端
     * @private
     */
    private render;
    /**
     * 根据编译状态 给出要输出的信息
     * @private
     */
    private getDisplayText;
    private getPersistText;
    /**
     * 包住标准输出
     * @param original
     * @param stream
     * @private
     */
    private interceptWrite;
}
