import jsCommands, { HookJSCommands } from "./js_commands";
import DOM from "./dom";
import LiveSocket from "./live_socket";
import View from "./view";

const HOOK_ID = "hookId";
let viewHookID = 1;

export type OnReply = (reply: any, ref: number) => any;
export type CallbackRef = { event: string; callback: (payload: any) => any };

export type PhxTarget = string | number | HTMLElement;

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
   * Called when the element has been updated in the DOM by the server
   */
  updated?: () => void;

  /**
   * The destroyed callback.
   *
   * Called when the element has been removed from the page, either by a parent update, or by the parent being removed entirely
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
   * Returns an object with methods to manipluate the DOM and execute JavaScript.
   * The applied changes integrate with server DOM patching.
   */
  js(): HookJSCommands;

  /**
   * Pushes an event to the server.
   *
   * @param event - The event name.
   * @param [payload] - The payload to send to the server. Defaults to an empty object.
   * @param [onReply] - A callback to handle the server's reply.
   *
   * When onReply is not provided, the method returns a Promise that
   * When onReply is provided, the method returns void.
   */
  pushEvent(event: string, payload: any, onReply: OnReply): void;
  pushEvent(event: string, payload?: any): Promise<any>;

  /**
   * Pushed a targeted event to the server.
   *
   * It sends the event to the LiveComponent or LiveView the `selectorOrTarget` is defined in,
   * where its value can be either a query selector, an actual DOM element, or a CID (component id)
   * returned by the `@myself` assign.
   *
   * If the query selector returns more than one element it will send the event to all of them,
   * even if all the elements are in the same LiveComponent or LiveView. Because of this,
   * if no callback is passed, a promise is returned that matches the return value of
   * [`Promise.allSettled()`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise/allSettled#return_value).
   * Individual fulfilled values are of the format `{ reply, ref }`, where `reply` is the server's reply.
   *
   * @param selectorOrTarget - The selector, element, or CID to target.
   * @param event - The event name.
   * @param [payload] - The payload to send to the server. Defaults to an empty object.
   * @param [onReply] - A callback to handle the server's reply.
   *
   * When onReply is not provided, the method returns a Promise.
   * When onReply is provided, the method returns void.
   */
  pushEventTo(
    selectorOrTarget: PhxTarget,
    event: string,
    payload: object,
    onReply: OnReply,
  ): void;
  pushEventTo(
    selectorOrTarget: PhxTarget,
    event: string,
    payload?: object,
  ): Promise<PromiseSettledResult<{ reply: any; ref: number }>[]>;

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
   * @param callbackRef - The reference to the callback to remove.
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

  // allow unknown methods, as people can define them in their hooks
  [key: PropertyKey]: any;
}

// based on https://github.com/DefinitelyTyped/DefinitelyTyped/blob/fac1aa75acdddbf4f1a95e98ee2297b54ce4b4c9/types/phoenix_live_view/hooks.d.ts#L26
// licensed under MIT
export interface Hook<out T = object, E extends HTMLElement = HTMLElement> {
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
   * Called when the element has been updated in the DOM by the server
   */
  updated?: (this: T & HookInterface<E>) => void;

  /**
   * The destroyed callback.
   *
   * Called when the element has been removed from the page, either by a parent update, or by the parent being removed entirely
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

  // Allow custom methods with any signature and custom properties
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
 */
export class ViewHook<E extends HTMLElement = HTMLElement>
  implements HookInterface<E>
{
  el: E;
  liveSocket: LiveSocket;

  private __listeners: Set<CallbackRef>;
  private __isDisconnected: boolean;
  private __view: () => View;

  static makeID() {
    return viewHookID++;
  }
  static elementID(el: HTMLElement) {
    return DOM.private(el, HOOK_ID);
  }

  constructor(view: View | null, el: E, callbacks?: Hook) {
    this.el = el;
    this.__attachView(view);
    this.__listeners = new Set();
    this.__isDisconnected = false;
    DOM.putPrivate(this.el, HOOK_ID, ViewHook.makeID());

    if (callbacks) {
      // This instance is for an object-literal hook. Copy methods/properties.
      // These are properties that should NOT be overridden by the callbacks object.
      const protectedProps = new Set([
        "el",
        "liveSocket",
        "__view",
        "__listeners",
        "__isDisconnected",
        "constructor", // Standard object properties
        // Core ViewHook API methods
        "js",
        "pushEvent",
        "pushEventTo",
        "handleEvent",
        "removeHandleEvent",
        "upload",
        "uploadTo",
        // Internal lifecycle callers
        "__mounted",
        "__updated",
        "__beforeUpdate",
        "__destroyed",
        "__reconnected",
        "__disconnected",
        "__cleanup__",
      ]);

      for (const key in callbacks) {
        if (Object.prototype.hasOwnProperty.call(callbacks, key)) {
          (this as any)[key] = callbacks[key];
          // for backwards compatibility, we allow the overwrite, but we log a warning
          if (protectedProps.has(key)) {
            console.warn(
              `Hook object for element #${el.id} overwrites core property '${key}'!`,
            );
          }
        }
      }

      const lifecycleMethods: (keyof Hook)[] = [
        "mounted",
        "beforeUpdate",
        "updated",
        "destroyed",
        "disconnected",
        "reconnected",
      ];
      lifecycleMethods.forEach((methodName) => {
        if (
          callbacks[methodName] &&
          typeof callbacks[methodName] === "function"
        ) {
          (this as any)[methodName] = callbacks[methodName];
        }
      });
    }
    // If 'callbacks' is not provided, this is an instance of a user-defined class (e.g., MyHook).
    // Its methods (mounted, updated, custom) are already part of its prototype or instance,
    // and will correctly override the defaults from ViewHook.prototype.
  }

  /** @internal */
  __attachView(view: View | null) {
    if (view) {
      this.__view = () => view;
      this.liveSocket = view.liveSocket;
    } else {
      this.__view = () => {
        throw new Error(
          `hook not yet attached to a live view: ${this.el.outerHTML}`,
        );
      };
      this.liveSocket = null;
    }
  }

  // Default lifecycle methods
  mounted(): void {}
  beforeUpdate(): void {}
  updated(): void {}
  destroyed(): void {}
  disconnected(): void {}
  reconnected(): void {}

  // Internal lifecycle callers - called by the View

  /** @internal */
  __mounted() {
    this.mounted();
  }
  /** @internal */
  __updated() {
    this.updated();
  }
  /** @internal */
  __beforeUpdate() {
    this.beforeUpdate();
  }
  /** @internal */
  __destroyed() {
    this.destroyed();
    DOM.deletePrivate(this.el, HOOK_ID); // https://github.com/phoenixframework/phoenix_live_view/issues/3496
  }
  /** @internal */
  __reconnected() {
    if (this.__isDisconnected) {
      this.__isDisconnected = false;
      this.reconnected();
    }
  }
  /** @internal */
  __disconnected() {
    this.__isDisconnected = true;
    this.disconnected();
  }

  js(): HookJSCommands {
    return {
      ...jsCommands(this.__view().liveSocket, "hook"),
      exec: (encodedJS: string) => {
        this.__view().liveSocket.execJS(this.el, encodedJS, "hook");
      },
    };
  }

  pushEvent(event: string, payload?: any, onReply?: OnReply) {
    const promise = this.__view().pushHookEvent(
      this.el,
      null,
      event,
      payload || {},
    );
    if (onReply === undefined) {
      return promise.then(({ reply }) => reply);
    }
    promise.then(({ reply, ref }) => onReply(reply, ref)).catch(() => {});
    return;
  }

  pushEventTo(
    selectorOrTarget: PhxTarget,
    event: string,
    payload?: object,
    onReply?: OnReply,
  ) {
    if (onReply === undefined) {
      const targetPair: { view: View; targetCtx: any }[] = [];
      this.__view().withinTargets(selectorOrTarget, (view, targetCtx) => {
        targetPair.push({ view, targetCtx });
      });
      const promises = targetPair.map(({ view, targetCtx }) => {
        return view.pushHookEvent(this.el, targetCtx, event, payload || {});
      });
      return Promise.allSettled(promises);
    }
    this.__view().withinTargets(selectorOrTarget, (view, targetCtx) => {
      view
        .pushHookEvent(this.el, targetCtx, event, payload || {})
        .then(({ reply, ref }) => onReply(reply, ref))
        .catch(() => {});
    });
    return;
  }

  handleEvent(event: string, callback: (payload: any) => any): CallbackRef {
    const callbackRef: CallbackRef = {
      event,
      callback: (customEvent: CustomEvent) => callback(customEvent.detail),
    };
    window.addEventListener(
      `phx:${event}`,
      callbackRef.callback as EventListener,
    );
    this.__listeners.add(callbackRef);
    return callbackRef;
  }

  removeHandleEvent(ref: CallbackRef): void {
    window.removeEventListener(
      `phx:${ref.event}`,
      ref.callback as EventListener,
    );
    this.__listeners.delete(ref);
  }

  upload(name: string, files: FileList): any {
    return this.__view().dispatchUploads(null, name, files);
  }

  uploadTo(selectorOrTarget: PhxTarget, name: string, files: FileList): any {
    return this.__view().withinTargets(selectorOrTarget, (view, targetCtx) => {
      view.dispatchUploads(targetCtx, name, files);
    });
  }

  /** @internal */
  __cleanup__() {
    this.__listeners.forEach((callbackRef) =>
      this.removeHandleEvent(callbackRef),
    );
  }
}

export type HooksOptions = Record<string, typeof ViewHook | Hook>;

export default ViewHook;
