import { HookJSCommands } from "./js_commands";
import LiveSocket from "./live_socket";
import View from "./view";
export type OnReply = (reply: any, ref: number) => any;
export type CallbackRef = {
    event: string;
    callback: (payload: any) => any;
};
export type PhxTarget = string | number | HTMLElement;
/**
 * Defines the lifecycle callbacks and custom methods for a LiveView hook.
 *
 * @category JavaScript Hooks
 */
export interface HookInterface<E extends HTMLElement = HTMLElement> {
    /**
     * The DOM element that the hook is attached to.
     */
    el: E;
    /**
     * The LiveSocket instance that the hook is attached to.
     */
    liveSocket: LiveSocket;
    /**
     * The mounted callback.
     *
     * Called when the element has been added to the DOM and its server LiveView has finished mounting.
     */
    mounted?: () => void;
    /**
     * The beforeUpdate callback.
     *
     * Called when the element is about to be updated in the DOM.
     * Note: any call here must be synchronous as the operation cannot be deferred or cancelled.
     */
    beforeUpdate?: () => void;
    /**
     * The updated callback.
     *
     * Called when the element has been updated in the DOM by the server.
     */
    updated?: () => void;
    /**
     * The destroyed callback.
     *
     * Called when the element has been removed from the page, either by a parent update, or by the parent being removed entirely.
     */
    destroyed?: () => void;
    /**
     * The disconnected callback.
     *
     * Called when the element's parent LiveView has disconnected from the server.
     */
    disconnected?: () => void;
    /**
     * The reconnected callback.
     *
     * Called when the element's parent LiveView has reconnected to the server.
     */
    reconnected?: () => void;
    /**
     * Returns an object with methods to manipulate the DOM and execute JavaScript.
     * The applied changes integrate with server DOM patching.
     */
    js(): HookJSCommands;
    /**
     * Pushes an event to the server and invokes a callback with the server's reply.
     *
     * **Note:** this version silently ignores push errors.
     * Use the {@link pushEvent | promise-returning version} to handle errors.
     *
     * @param event - The event name.
     * @param payload - The payload to send to the server. Must be a serializable
     * value (typically JSON-serializable, depends on the Socket configuration).
     * Defaults to an empty object.
     * @param onReply - A callback to handle the server's reply.
     */
    pushEvent(event: string, payload: unknown, onReply: OnReply): void;
    /**
     * Pushes an event to the server and returns a Promise that resolves with the server's reply.
     *
     * The promise will be rejected in case of errors
     * such as a disconnected state, timeout, or the server rejecting the event.
     *
     * @param event - The event name.
     * @param [payload] - The payload to send to the server. Must be a serializable
     * value (typically JSON-serializable, depends on the Socket configuration).
     * Defaults to an empty object.
     * @returns A promise that fulfills or rejects with the server's reply.
     */
    pushEvent(event: string, payload?: unknown): Promise<any>;
    /**
     * Pushes a targeted event to the server and invokes a callback with the server's reply.
     *
     * It sends the event to the LiveComponent or LiveView the `selectorOrTarget` is defined in,
     * where its value can be either a query selector, an actual DOM element, or a CID (component id)
     * returned by the `@myself` assign.
     *
     * If the selector matches multiple elements, the event is sent to all of them,
     * even if they belong to the same LiveComponent or LiveView.
     *
     * **Note:** this version silently ignores push errors.
     * Use the {@link pushEventTo | promise-returning version} to handle errors.
     *
     * @param selectorOrTarget - The selector, element, or CID to target.
     * @param event - The event name.
     * @param payload - The payload to send to the server. Must be a serializable
     * value (typically JSON-serializable, depends on the Socket configuration).
     * Defaults to an empty object.
     * @param onReply - A callback to handle the server's reply.
     */
    pushEventTo(selectorOrTarget: PhxTarget, event: string, payload: unknown, onReply: OnReply): void;
    /**
     * Pushes a targeted event to the server and returns a Promise that resolves with the server's reply.
     *
     * It sends the event to the LiveComponent or LiveView the `selectorOrTarget` is defined in,
     * where its value can be either a query selector, an actual DOM element, or a CID (component id)
     * returned by the `@myself` assign.
     *
     * If the selector matches multiple elements, the event is sent to all of them,
     * even if they belong to the same LiveComponent or LiveView.
     * Because of this, it returns a single promise that matches the return value of
     * [`Promise.allSettled()`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise/allSettled#return_value).
     * Individual fulfilled values are of the format `{ reply, ref }`, where `reply` is the server's reply.
     *
     * The individual promises will be rejected in case of errors
     * such as a disconnected state, timeout, or the server rejecting the event.
     *
     * @param selectorOrTarget - The selector, element, or CID to target.
     * @param event - The event name.
     * @param [payload] - The payload to send to the server. Must be a serializable
     * value (typically JSON-serializable, depends on the Socket configuration).
     * Defaults to an empty object.
     * @returns A promise that resolves when the event has been handled by all targets.
     */
    pushEventTo(selectorOrTarget: PhxTarget, event: string, payload?: unknown): Promise<PromiseSettledResult<{
        reply: any;
        ref: number;
    }>[]>;
    /**
     * Allows to register a callback to be called when an event is received from the server.
     *
     * This is used to handle `pushEvent` calls from the server. The callback is called with the payload from the server.
     *
     * @param event - The event name.
     * @param callback - The callback to call when the event is received.
     *
     * @returns A reference to the callback, which can be used in `removeHandleEvent` to remove the callback.
     */
    handleEvent(event: string, callback: (payload: any) => any): CallbackRef;
    /**
     * Removes a callback registered with `handleEvent`.
     *
     * @param ref - The reference to the callback to remove.
     */
    removeHandleEvent(ref: CallbackRef): void;
    /**
     * Allows to trigger a live file upload.
     *
     * @param name - The upload name corresponding to the `Phoenix.LiveView.allow_upload/3` call.
     * @param files - The files to upload.
     */
    upload(name: any, files: any): any;
    /**
     * Allows to trigger a live file upload to a specific target.
     *
     * @param selectorOrTarget - The target to upload the files to.
     * @param name - The upload name corresponding to the `Phoenix.LiveView.allow_upload/3` call.
     * @param files - The files to upload.
     */
    uploadTo(selectorOrTarget: PhxTarget, name: any, files: any): any;
    [key: PropertyKey]: any;
}
/**
 * Defines the lifecycle callbacks and custom methods for a LiveView hook.
 *
 * @category JavaScript Hooks
 */
export interface Hook<T = object, E extends HTMLElement = HTMLElement> {
    /**
     * The mounted callback.
     *
     * Called when the element has been added to the DOM and its server LiveView has finished mounting.
     */
    mounted?: (this: T & HookInterface<E>) => void;
    /**
     * The beforeUpdate callback.
     *
     * Called when the element is about to be updated in the DOM.
     * Note: any call here must be synchronous as the operation cannot be deferred or cancelled.
     */
    beforeUpdate?: (this: T & HookInterface<E>) => void;
    /**
     * The updated callback.
     *
     * Called when the element has been updated in the DOM by the server.
     */
    updated?: (this: T & HookInterface<E>) => void;
    /**
     * The destroyed callback.
     *
     * Called when the element has been removed from the page, either by a parent update, or by the parent being removed entirely.
     */
    destroyed?: (this: T & HookInterface<E>) => void;
    /**
     * The disconnected callback.
     *
     * Called when the element's parent LiveView has disconnected from the server.
     */
    disconnected?: (this: T & HookInterface<E>) => void;
    /**
     * The reconnected callback.
     *
     * Called when the element's parent LiveView has reconnected to the server.
     */
    reconnected?: (this: T & HookInterface<E>) => void;
    [key: PropertyKey]: any;
}
/**
 * Base class for LiveView hooks. Users extend this class to define their hooks.
 *
 * Example:
 * ```typescript
 * class MyCustomHook extends ViewHook {
 *   myState = "initial";
 *
 *   mounted() {
 *     console.log("Hook mounted on element:", this.el);
 *     this.el.addEventListener("click", () => {
 *       this.pushEvent("element-clicked", { state: this.myState });
 *     });
 *   }
 *
 *   updated() {
 *     console.log("Hook updated", this.el.id);
 *   }
 *
 *   myCustomMethod(someArg: string) {
 *     console.log("myCustomMethod called with:", someArg, "Current state:", this.myState);
 *   }
 * }
 * ```
 *
 * The `this` context within the hook methods (mounted, updated, custom methods, etc.)
 * will refer to the hook instance, providing access to `this.el`, `this.liveSocket`,
 * `this.pushEvent()`, etc., as well as any properties or methods defined on the subclass.
 *
 * @category JavaScript Hooks
 */
export declare class ViewHook<E extends HTMLElement = HTMLElement> implements HookInterface<E> {
    el: E;
    private __listeners;
    private __isDisconnected;
    private __view;
    private __liveSocket;
    get liveSocket(): LiveSocket;
    /** @internal */
    static makeID(): number;
    /** @internal */
    static elementID(el: HTMLElement): any;
    /** @internal */
    static deadHook(el: HTMLElement): boolean;
    /** @internal */
    constructor(view: View | null, el: E, callbacks?: Hook);
    /** @internal */
    __attachView(view: View | null): void;
    mounted(): void;
    beforeUpdate(): void;
    updated(): void;
    destroyed(): void;
    disconnected(): void;
    reconnected(): void;
    /** @internal */
    __mounted(): void;
    /** @internal */
    __updated(): void;
    /** @internal */
    __beforeUpdate(): void;
    /** @internal */
    __destroyed(): void;
    /** @internal */
    __reconnected(): void;
    /** @internal */
    __disconnected(): void;
    js(): HookJSCommands;
    pushEvent(event: string, payload: unknown, onReply: OnReply): void;
    pushEvent(event: string, payload?: unknown): Promise<any>;
    pushEventTo(selectorOrTarget: PhxTarget, event: string, payload: unknown, onReply: OnReply): void;
    pushEventTo(selectorOrTarget: PhxTarget, event: string, payload?: unknown): Promise<PromiseSettledResult<{
        reply: any;
        ref: number;
    }>[]>;
    handleEvent(event: string, callback: (payload: any) => any): CallbackRef;
    removeHandleEvent(ref: CallbackRef): void;
    upload(name: string, files: FileList): any;
    uploadTo(selectorOrTarget: PhxTarget, name: string, files: FileList): any;
    /** @internal */
    __cleanup__(): void;
}
/**
 * @category JavaScript Hooks
 */
export type HooksOptions = Record<string, typeof ViewHook | Hook<any, any>>;
export default ViewHook;
