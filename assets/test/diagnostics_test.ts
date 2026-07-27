import { dispatchDiagnostic, logError } from "phoenix_live_view/diagnostics";
import { PHX_LV_DEBUG } from "phoenix_live_view/constants";
import { captureDiagnostics } from "./test_helpers";

describe("diagnostics", () => {
  afterEach(() => jest.restoreAllMocks());

  test("dispatches a versioned envelope on a stable event name", () => {
    // debug gating is done by the caller
    window.sessionStorage.setItem(PHX_LV_DEBUG, "false");
    const received: unknown[] = [];
    const listener = (event: Event) =>
      received.push((event as CustomEvent).detail);
    window.addEventListener("phx:live-view:diagnostic", listener);

    try {
      dispatchDiagnostic({
        level: "debug",
        code: "test.code",
        message: "message",
        attribution: "app",
      });
    } finally {
      window.removeEventListener("phx:live-view:diagnostic", listener);
      window.sessionStorage.removeItem(PHX_LV_DEBUG);
    }

    expect(received).toEqual([
      {
        version: 1,
        level: "debug",
        code: "test.code",
        message: "message",
        attribution: "app",
      },
    ]);
  });

  test("logError dispatches without metadata and view context", () => {
    const consoleError = jest
      .spyOn(console, "error")
      .mockImplementation(() => {});
    const { diagnostics, stop } = captureDiagnostics();

    try {
      logError("hook.missing-id", "no id", {}, { attribution: "app" });
    } finally {
      stop();
    }

    expect(consoleError).toHaveBeenCalledWith("no id", {});
    expect(diagnostics).toEqual([
      {
        version: 1,
        level: "error",
        code: "hook.missing-id",
        message: "no id",
        attribution: "app",
        metadata: {},
      },
    ]);
  });

  test("logs and dispatches structured errors", () => {
    const consoleError = jest
      .spyOn(console, "error")
      .mockImplementation(() => {});
    const { diagnostics, stop } = captureDiagnostics();
    const metadata = { id: "users" };

    try {
      logError("dom.duplicate-id", "duplicate", metadata, {
        viewId: "users-view",
        attribution: "app",
      });
    } finally {
      stop();
    }

    expect(consoleError).toHaveBeenCalledWith("duplicate", metadata);
    expect(diagnostics).toEqual([
      {
        version: 1,
        level: "error",
        code: "dom.duplicate-id",
        message: "duplicate",
        metadata,
        viewId: "users-view",
        attribution: "app",
      },
    ]);
  });
});
