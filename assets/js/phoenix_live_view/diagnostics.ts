import {
  PHX_LV_DIAGNOSTIC_EVENT,
  PHX_LV_DIAGNOSTIC_VERSION,
} from "./constants";

export type LiveViewDiagnosticLevel = "debug" | "error";

export type LiveViewDiagnosticMetadata = Record<string, unknown>;

export type LiveViewDiagnosticContext = {
  viewId?: string;
};

export type LiveViewDiagnostic = {
  version: typeof PHX_LV_DIAGNOSTIC_VERSION;
  level: LiveViewDiagnosticLevel;
  code: string;
  message: string;
  viewId?: string;
  metadata?: LiveViewDiagnosticMetadata;
};

// Debug-level diagnostics are gated on LiveSocket.isDebugEnabled() by the
// caller; error-level diagnostics are always emitted.
export const dispatchDiagnostic = (
  diagnostic: Omit<LiveViewDiagnostic, "version">,
): void => {
  window.dispatchEvent(
    new CustomEvent<LiveViewDiagnostic>(PHX_LV_DIAGNOSTIC_EVENT, {
      detail: { version: PHX_LV_DIAGNOSTIC_VERSION, ...diagnostic },
    }),
  );
};

export const logError = (
  code: string,
  message: string,
  metadata?: LiveViewDiagnosticMetadata,
  context: LiveViewDiagnosticContext = {},
): void => {
  console.error && console.error(message, metadata);
  dispatchDiagnostic({
    level: "error",
    code,
    message,
    metadata,
    ...context,
  });
};

export type LogError = typeof logError;
