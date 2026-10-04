/**
 * 树型结构
 */
export declare class TreeNode<T> {
    key: string;
    value: T;
    children: TreeNode<T>[];
    constructor(key: string, value: T);
}
export declare class Tree<T> {
    root: TreeNode<T>;
    constructor(key: string, value: T);
    findNodeByKeyBFS(key: string): TreeNode<T> | undefined;
    findParentNodeByKey(key: string): TreeNode<T> | undefined;
    addNode(key: string, value: T, parentKey: string): boolean;
}
