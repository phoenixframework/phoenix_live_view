import {
  PHX_LV_DIAGNOSTIC_EVENT,
  PHX_LV_DIAGNOSTIC_VERSION,
} from "./constants";

export type LiveViewDiagnosticLevel = "debug" | "error";

export type LiveViewDiagnosticMetadata = Record<string, unknown>;

export type LiveViewDiagnosticAttribution =
  | "internal" // errors that signify a bug in LiveView
  | "network" // errors caused by network problems
  | "app" // errors that are definitely caused by the user's app
  | "unknown"; // non-error diagnostics or cases that are not 100% clear

export type LiveViewDiagnosticContext = {
  viewId?: string;
  attribution: LiveViewDiagnosticAttribution;
};

export type LiveViewDiagnostic = {
  version: typeof PHX_LV_DIAGNOSTIC_VERSION;
  level: LiveViewDiagnosticLevel;
  code: string;
  message: string;
  metadata?: LiveViewDiagnosticMetadata;
} & LiveViewDiagnosticContext;

type LiveViewDiagnosticInput = Omit<LiveViewDiagnostic, "version">;

// Debug-level diagnostics are gated on LiveSocket.isDebugEnabled() by the
// caller; error-level diagnostics are always emitted.
export const dispatchDiagnostic = (
  diagnostic: LiveViewDiagnosticInput,
): void => {
  window.dispatchEvent(
    new CustomEvent<LiveViewDiagnostic>(PHX_LV_DIAGNOSTIC_EVENT, {
      detail: {
        version: PHX_LV_DIAGNOSTIC_VERSION,
        ...diagnostic,
      },
    }),
  );
};

export const logError = (
  code: string,
  message: string,
  metadata: LiveViewDiagnosticMetadata,
  context: LiveViewDiagnosticContext,
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
