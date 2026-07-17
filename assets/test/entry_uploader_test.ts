import EntryUploader from "phoenix_live_view/entry_uploader";

describe("EntryUploader", () => {
  test("passes channel-error reply reason as string to entry.error", () => {
    let errorCb;
    let fakeChannel = {
      onError: jest.fn(),
      leave: jest.fn(),
      join: () => ({
        receive(kind, cb) {
          if (kind === "error") errorCb = cb;
          return this;
        },
      }),
    };
    let fakeLiveSocket = { channel: () => fakeChannel };
    let entry = { ref: "0", metadata: () => ({}), error: jest.fn() };
    let config = { chunk_size: 1024, chunk_timeout: 5000 };

    new EntryUploader(entry, config, fakeLiveSocket).upload();

    // Reply payload arrives as {reason: "..."}, not as a string.
    errorCb({ reason: "join crashed" });

    expect(entry.error).toHaveBeenCalledWith("join crashed");
  });

  test("reports join timeout to the entry", () => {
    let timeoutCb;
    const fakeChannel = {
      onError: jest.fn(),
      leave: jest.fn(),
      join: () => ({
        receive(kind, cb) {
          if (kind === "timeout") timeoutCb = cb;
          return this;
        },
      }),
    };
    const fakeLiveSocket = { channel: () => fakeChannel };
    const entry = { ref: "0", metadata: () => ({}), error: jest.fn() };
    const config = { chunk_size: 1024, chunk_timeout: 5000 };

    new EntryUploader(entry, config, fakeLiveSocket).upload();
    timeoutCb();

    expect(fakeChannel.leave).toHaveBeenCalled();
    expect(entry.error).toHaveBeenCalledWith("timeout");
  });

  test("reports chunk timeout to the entry", () => {
    let timeoutCb;
    const fakeChannel = {
      onError: jest.fn(),
      leave: jest.fn(),
      isJoined: () => true,
      push: () => ({
        receive(kind, cb) {
          if (kind === "timeout") timeoutCb = cb;
          return this;
        },
      }),
    };
    const fakeLiveSocket = { channel: () => fakeChannel };
    const entry = {
      ref: "0",
      metadata: () => ({}),
      error: jest.fn(),
      file: { size: 1 },
    };
    const config = { chunk_size: 1024, chunk_timeout: 5000 };
    const uploader = new EntryUploader(entry, config, fakeLiveSocket);

    uploader.pushChunk(new ArrayBuffer(1));
    timeoutCb();

    expect(fakeChannel.leave).toHaveBeenCalled();
    expect(entry.error).toHaveBeenCalledWith("timeout");
  });
});
