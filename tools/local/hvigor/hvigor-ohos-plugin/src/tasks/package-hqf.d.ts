import { TargetTaskService } from './service/target-task-service.js';
import { OhosHapTask } from './task/ohos-hap-task.js';
export declare class PackageHqf extends OhosHapTask {
    private readonly _log;
    constructor(targetService: TargetTaskService);
    protected doTaskAction(): Promise<void>;
    getColdReloadCommand(): string[];
    initTaskDepends(): void;
}
