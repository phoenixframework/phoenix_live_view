import { PHX_LV_DIAGNOSTIC_VERSION } from "./constants";
export type LiveViewDiagnosticLevel = "debug" | "error";
export type LiveViewDiagnosticMetadata = Record<string, unknown>;
export type LiveViewDiagnosticAttribution = "internal" | "network" | "app" | "unknown";
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
export declare const dispatchDiagnostic: (diagnostic: LiveViewDiagnosticInput) => void;
export declare const logError: (code: string, message: string, metadata: LiveViewDiagnosticMetadata, context: LiveViewDiagnosticContext) => void;
export type LogError = typeof logError;
export {};
