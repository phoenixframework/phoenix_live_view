declare const Browser: {
    canPushState(): boolean;
    dropLocal(localStorage: any, namespace: any, subkey: any): any;
    updateLocal(localStorage: any, namespace: any, subkey: any, initial: any, func: any): any;
    getLocal(localStorage: any, namespace: any, subkey: any): any;
    updateCurrentState(callback: any): void;
    pushState(kind: "replace" | "push", meta: {
        type: string;
        scroll?: number;
        id?: string;
        position?: number;
    }, to?: string): void;
    setCookie(name: string, value: string | number, maxAgeSeconds?: number): void;
    getCookie(name: string): string;
    deleteCookie(name: string): void;
    redirect(toURL: string, flash?: string | null, navigate?: (url: string) => void): void;
    localKey(namespace: any, subkey: any): string;
    getHashTargetEl(maybeHash: any): HTMLElement;
};
export default Browser;
