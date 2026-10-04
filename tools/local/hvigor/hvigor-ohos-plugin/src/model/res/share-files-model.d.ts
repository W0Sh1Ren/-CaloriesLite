type Permission = 'r' | 'r+w';
export interface Scope {
    path: string;
    permission: Permission;
}
interface ShareFilesModel {
    scopes?: Scope[];
    sharingOSPath?: string;
    sharingOSSubpath?: string;
    sharingOSPermission?: Permission;
}
export interface ShareConfig {
    share_files?: ShareFilesModel;
}
export {};
