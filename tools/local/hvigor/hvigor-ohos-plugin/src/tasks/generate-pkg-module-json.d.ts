import { AbstractGeneratePkgModuleJson } from './abstract-generate-pkg-module-json.js';
import { TargetTaskService } from './service/target-task-service.js';
export declare class GeneratePkgModuleJson extends AbstractGeneratePkgModuleJson {
    protected getJsonPath(): string;
    constructor(taskService: TargetTaskService);
}
