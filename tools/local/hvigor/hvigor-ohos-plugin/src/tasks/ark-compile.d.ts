import { AbstractArkCompile } from './abstract-ark-compile.js';
export declare class ArkCompile extends AbstractArkCompile {
    protected validateModuleJsonAbstract(): void;
    protected doTaskAction(): Promise<void>;
}
