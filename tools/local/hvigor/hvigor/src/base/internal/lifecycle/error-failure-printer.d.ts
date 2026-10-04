/**
 * 错误项，用于汇总打印。
 */
export interface ErrorItem {
    message: string;
    error: Error;
    delimiter: string;
    type: 'arkts' | 'cpp';
    code?: string;
}
export declare class ErrorFailurePrinter {
    private errorItems;
    /**
     * 收集错误信息，用于最后汇总打印。
     * 只收集 ArkTS 和 C++ 构建相关的错误。
     * @param error 错误对象
     * @param errorText 格式化后的错误文本
     * @param trySuggestion 建议操作提示
     * @param taskName 任务名称
     * @param errorCode 错误码
     */
    collectError(error: Error, errorText: string, trySuggestion: string, taskName?: string, errorCode?: string): void;
    /**
     * 格式化 ArkTS 错误信息。
     * @param trySug 建议操作提示
     * @param taskName 任务名称
     * @returns 格式化后的错误信息
     */
    private formatArkTsMessage;
    /**
     * 汇总打印所有收集的错误信息。
     */
    printSummary(): void;
    /**
     * 清空已收集的错误信息。
     */
    clear(): void;
}
export declare const errorFailurePrinter: ErrorFailurePrinter;
