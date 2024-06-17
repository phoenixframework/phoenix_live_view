export const CONSECUTIVE_RELOADS = "consecutive-reloads"
export const MAX_RELOADS = 10
export const RELOAD_JITTER_MIN = 5000
export const RELOAD_JITTER_MAX = 10000
export const FAILSAFE_JITTER = 30000
export const PHX_EVENT_CLASSES = [
  "phx-click-loading", "phx-change-loading", "phx-submit-loading",
  "phx-keydown-loading", "phx-keyup-loading", "phx-blur-loading", "phx-focus-loading",
  "phx-hook-loading"
]
export const PHX_COMPONENT = "data-phx-component"
export const PHX_LIVE_LINK = "data-phx-link"
export const PHX_TRACK_STATIC = "track-static"
export const PHX_LINK_STATE = "data-phx-link-state"
export const PHX_REF = "data-phx-ref"
export const PHX_REF_SRC = "data-phx-ref-src"
export const PHX_TRACK_UPLOADS = "track-uploads"
export const PHX_UPLOAD_REF = "data-phx-upload-ref"
export const PHX_PREFLIGHTED_REFS = "data-phx-preflighted-refs"
export const PHX_DONE_REFS = "data-phx-done-refs"
export const PHX_DROP_TARGET = "drop-target"
export const PHX_ACTIVE_ENTRY_REFS = "data-phx-active-refs"
export const PHX_LIVE_FILE_UPDATED = "phx:live-file:updated"
export const PHX_SKIP = "data-phx-skip"
export const PHX_MAGIC_ID = "data-phx-id"
export const PHX_PRUNE = "data-phx-prune"
export const PHX_PAGE_LOADING = "page-loading"
export const PHX_CONNECTED_CLASS = "phx-connected"
export const PHX_LOADING_CLASS = "phx-loading"
export const PHX_NO_FEEDBACK_CLASS = "phx-no-feedback"
export const PHX_ERROR_CLASS = "phx-error"
export const PHX_CLIENT_ERROR_CLASS = "phx-client-error"
export const PHX_SERVER_ERROR_CLASS = "phx-server-error"
export const PHX_PARENT_ID = "data-phx-parent-id"
export const PHX_MAIN = "data-phx-main"
export const PHX_ROOT_ID = "data-phx-root-id"
export const PHX_VIEWPORT_TOP = "viewport-top"
export const PHX_VIEWPORT_BOTTOM = "viewport-bottom"
export const PHX_TRIGGER_ACTION = "trigger-action"
export const PHX_FEEDBACK_FOR = "feedback-for"
export const PHX_FEEDBACK_GROUP = "feedback-group"
export const PHX_HAS_FOCUSED = "phx-has-focused"
export const FOCUSABLE_INPUTS = ["text", "textarea", "number", "email", "password", "search", "tel", "url", "date", "time", "datetime-local", "color", "range"]
export const CHECKABLE_INPUTS = ["checkbox", "radio"]
export const PHX_HAS_SUBMITTED = "phx-has-submitted"
export const PHX_SESSION = "data-phx-session"
export const PHX_VIEW_SELECTOR = `[${PHX_SESSION}]`
export const PHX_STICKY = "data-phx-sticky"
export const PHX_STATIC = "data-phx-static"
export const PHX_READONLY = "data-phx-readonly"
export const PHX_DISABLED = "data-phx-disabled"
export const PHX_DISABLE_WITH = "disable-with"
export const PHX_DISABLE_WITH_RESTORE = "data-phx-disable-with-restore"
export const PHX_HOOK = "hook"
export const PHX_DEBOUNCE = "debounce"
export const PHX_THROTTLE = "throttle"
export const PHX_UPDATE = "update"
export const PHX_STREAM = "stream"
export const PHX_STREAM_REF = "data-phx-stream"
export const PHX_KEY = "key"
export const PHX_PRIVATE = "phxPrivate"
export const PHX_AUTO_RECOVER = "auto-recover"
export const PHX_LV_DEBUG = "phx:live-socket:debug"
export const PHX_LV_PROFILE = "phx:live-socket:profiling"
export const PHX_LV_LATENCY_SIM = "phx:live-socket:latency-sim"
export const PHX_PROGRESS = "progress"
export const PHX_MOUNTED = "mounted"
export const LOADER_TIMEOUT = 1
export const BEFORE_UNLOAD_LOADER_TIMEOUT = 200
export const BINDING_PREFIX = "phx-"
export const PUSH_TIMEOUT = 30000
export const LINK_HEADER = "x-requested-with"
export const RESPONSE_URL_HEADER = "x-response-url"
export const DEBOUNCE_TRIGGER = "debounce-trigger"
export const THROTTLED = "throttled"
export const DEBOUNCE_PREV_KEY = "debounce-prev-key"
export const DEFAULTS = {
  debounce: 300,
  throttle: 300
}

// Rendered
export const DYNAMICS = "d"
export const STATIC = "s"
export const ROOT = "r"
export const COMPONENTS = "c"
export const EVENTS = "e"
export const REPLY = "r"
export const TITLE = "t"
export const TEMPLATES = "p"
export const STREAM = "stream"