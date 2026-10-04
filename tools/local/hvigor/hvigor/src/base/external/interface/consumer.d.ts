/**
 * 定义的入参是一个参数的方法接口
 */
export interface Consumer<T> {
    (arg: T): Promise<void> | void;
    _internalHookType?: string;
    _hookSource?: HookSource;
}
/**
 * hook调用来源追踪信息
 * key为hook类型，value包含调用位置列表和当前索引
 */
export type HookSource = Record<string, {
    index: number;
    stackLineList: string[];
}>;
