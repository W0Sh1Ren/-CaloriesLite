import { HookSource } from '../external/interface/consumer.js';
import { DurationEvent } from './event/duration-event.js';
/**
 * Hvigor生命周期性能打点装饰器
 * 针对外部暴露的API
 * 用于追踪 API 调用位置（文件名、行号、列号）
 */
export declare function TrackHookAPI(target: object, propertyKey: string, descriptor: PropertyDescriptor): PropertyDescriptor;
/**
 * Hvigor生命周期性能打点装饰器
 * 针对hvigor内部使用的API
 */
export declare function TrackInternalHookAPI(target: object, propertyKey: string, descriptor: PropertyDescriptor): PropertyDescriptor;
export declare function getStackLine(hookType?: string, hookSource?: HookSource): string | undefined;
export declare function executeWithTracking(callback: () => Promise<void>, hookType?: string, hookSource?: HookSource, parentEvent?: DurationEvent): Promise<void>;
