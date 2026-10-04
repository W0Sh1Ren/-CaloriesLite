/**
 * 配置默认打印堆栈的错误码。
 * 这些错误码即使未开启 --stacktrace，也会默认打印堆栈信息以便快速定位问题。
 */
export declare const DEFAULT_STACKTRACE_ERROR_CODES: string[];
/**
 * 检查是否需要打印堆栈信息。
 * 当用户开启 --stacktrace 或者错误码属于默认需要打印堆栈的错误码时，返回 true。
 * @returns 是否需要打印堆栈
 * @param errorCodeList
 */
export declare function shouldPrintStackTrace(errorCodeList: (string | undefined)[] | undefined): boolean;
