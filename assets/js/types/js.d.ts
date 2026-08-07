export default JS;
declare namespace JS {
    function exec(e: any, eventType: any, phxEvent: any, view: any, sourceEl: any, defaults: any): void;
    function isVisible(el: any): boolean;
    function isInViewport(el: any): boolean;
    function exec_exec(e: any, eventType: any, phxEvent: any, view: any, sourceEl: any, el: any, { attr, to }: {
        attr: any;
        to: any;
    }): void;
    function exec_dispatch(e: any, eventType: any, phxEvent: any, view: any, sourceEl: any, el: any, { event, detail, bubbles, blocking }: {
        event: any;
        detail: any;
        bubbles: any;
        blocking: any;
    }): void;
    function exec_push(e: any, eventType: any, phxEvent: any, view: any, sourceEl: any, el: any, args: any): void;
    function exec_navigate(e: any, eventType: any, phxEvent: any, view: any, sourceEl: any, el: any, { href, replace }: {
        href: any;
        replace: any;
    }): void;
    function exec_patch(e: any, eventType: any, phxEvent: any, view: any, sourceEl: any, el: any, { href, replace }: {
        href: any;
        replace: any;
    }): void;
    function exec_focus(e: any, eventType: any, phxEvent: any, view: any, sourceEl: any, el: any): void;
    function exec_focus_first(e: any, eventType: any, phxEvent: any, view: any, sourceEl: any, el: any): void;
    function exec_push_focus(e: any, eventType: any, phxEvent: any, view: any, sourceEl: any, el: any): void;
    function exec_pop_focus(_e: any, _eventType: any, _phxEvent: any, _view: any, _sourceEl: any, _el: any): void;
    function exec_add_class(e: any, eventType: any, phxEvent: any, view: any, sourceEl: any, el: any, { names, transition, time, blocking }: {
        names: any;
        transition: any;
        time: any;
        blocking: any;
    }): void;
    function exec_remove_class(e: any, eventType: any, phxEvent: any, view: any, sourceEl: any, el: any, { names, transition, time, blocking }: {
        names: any;
        transition: any;
        time: any;
        blocking: any;
    }): void;
    function exec_toggle_class(e: any, eventType: any, phxEvent: any, view: any, sourceEl: any, el: any, { names, transition, time, blocking }: {
        names: any;
        transition: any;
        time: any;
        blocking: any;
    }): void;
    function exec_toggle_attr(e: any, eventType: any, phxEvent: any, view: any, sourceEl: any, el: any, { attr: [attr, val1, val2] }: {
        attr: [any, any, any];
    }): void;
    function exec_ignore_attrs(e: any, eventType: any, phxEvent: any, view: any, sourceEl: any, el: any, { attrs }: {
        attrs: any;
    }): void;
    function exec_transition(e: any, eventType: any, phxEvent: any, view: any, sourceEl: any, el: any, { time, transition, blocking }: {
        time: any;
        transition: any;
        blocking: any;
    }): void;
    function exec_toggle(e: any, eventType: any, phxEvent: any, view: any, sourceEl: any, el: any, { display, ins, outs, time, blocking }: {
        display: any;
        ins: any;
        outs: any;
        time: any;
        blocking: any;
    }): void;
    function exec_show(e: any, eventType: any, phxEvent: any, view: any, sourceEl: any, el: any, { display, transition, time, blocking }: {
        display: any;
        transition: any;
        time: any;
        blocking: any;
    }): void;
    function exec_hide(e: any, eventType: any, phxEvent: any, view: any, sourceEl: any, el: any, { display, transition, time, blocking }: {
        display: any;
        transition: any;
        time: any;
        blocking: any;
    }): void;
    function exec_set_attr(e: any, eventType: any, phxEvent: any, view: any, sourceEl: any, el: any, { attr: [attr, val] }: {
        attr: [any, any];
    }): void;
    function exec_remove_attr(e: any, eventType: any, phxEvent: any, view: any, sourceEl: any, el: any, { attr }: {
        attr: any;
    }): void;
    function ignoreAttrs(el: any, attrs: any): void;
    function onBeforeElUpdated(fromEl: any, toEl: any): void;
    function show(eventType: any, view: any, el: any, display: any, transition: any, time: any, blocking: any): void;
    function hide(eventType: any, view: any, el: any, display: any, transition: any, time: any, blocking: any): void;
    function toggle(eventType: any, view: any, el: any, display: any, ins: any, outs: any, time: any, blocking: any): void;
    function toggleClasses(el: any, classes: any, transition: any, time: any, view: any, blocking: any): void;
    function toggleAttr(el: any, attr: any, val1: any, val2: any): void;
    function addOrRemoveClasses(el: any, adds: any, removes: any, transition: any, time: any, view: any, blocking: any): void;
    function setOrRemoveAttrs(el: any, sets: any, removes: any): void;
    function hasAllClasses(el: any, classes: any): any;
    function isToggledOut(el: any, outClasses: any): any;
    function filterToEls(liveSocket: any, sourceEl: any, { to }: {
        to: any;
    }): any;
    function defaultDisplay(el: any): any;
    function transitionClasses(val: any): any[];
}
