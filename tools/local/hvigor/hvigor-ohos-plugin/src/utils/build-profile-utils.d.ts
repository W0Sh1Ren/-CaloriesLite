import { TaskInputValue } from '@ohos/hvigor';
import { RuntimeOnlyObj } from '../options/build/build-opt.js';
import { ModuleTargetData } from '../tasks/data/hap-task-target-data.js';
import { OhosLogger } from './log/ohos-logger.js';
/**
 * 生成buildProfile.ets文件
 *
 * @param buildProfileData
 * @param targetData
 * @param _log
 */
export declare const normalizedFileData: (buildProfileData: Record<string, unknown>, targetData: ModuleTargetData, _log: OhosLogger) => string;
export declare const generateConstVariable: (buildProfileData: Record<string, unknown>, targetData: ModuleTargetData, _log: OhosLogger) => string;
export declare const generateExportClass: (buildProfileData: Record<string, unknown>) => string;
export declare const getRuntimeOnlyObjMap: (modulePath: string, runtimeOnlyObj: RuntimeOnlyObj | undefined, unionDependencyList: string[], suffix?: number | string) => Map<string, TaskInputValue>;
export declare const getCustomTypePathIfExists: (modulePath: string, type: string) => string | undefined;
