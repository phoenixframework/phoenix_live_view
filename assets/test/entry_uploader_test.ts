import EntryUploader from "phoenix_live_view/entry_uploader";

describe("EntryUploader", () => {
  test("passes channel-error reply reason as string to entry.error", () => {
    let errorCb;
    let form = {};
    let cancelSubmit = jest.fn();
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
    let entry = {
      ref: "0",
      fileEl: { form },
      view: { cancelSubmit },
      metadata: () => ({}),
      error: jest.fn(),
    };
    let config = { chunk_size: 1024, chunk_timeout: 5000 };

    new EntryUploader(entry, config, fakeLiveSocket).upload();

    // Reply payload arrives as {reason: "..."}, not as a string.
    errorCb({ reason: "join crashed" });

    expect(cancelSubmit).toHaveBeenCalledWith(form);
    expect(entry.error).toHaveBeenCalledWith("join crashed");
  });

  test("writer errors remain pending without sending a generic entry error", () => {
    let errorCb;
    let channelErrorCb;
    let form = {};
    let cancelSubmit = jest.fn();
    let fakeChannel = {
      onError: (cb) => (channelErrorCb = cb),
      leave: jest.fn(),
      join: () => ({
        receive(kind, cb) {
          if (kind === "error") errorCb = cb;
          return this;
        },
      }),
    };
    let fakeLiveSocket = { channel: () => fakeChannel };
    let entry = {
      ref: "0",
      fileEl: { form },
      view: { cancelSubmit },
      metadata: () => ({}),
      cancel: jest.fn(),
      error: jest.fn(),
    };
    let config = { chunk_size: 1024, chunk_timeout: 5000 };

    new EntryUploader(entry, config, fakeLiveSocket).upload();

    errorCb({ reason: "writer_error" });
    channelErrorCb("closed");

    expect(cancelSubmit).toHaveBeenCalledTimes(1);
    expect(cancelSubmit).toHaveBeenCalledWith(form);
    expect(fakeChannel.leave).toHaveBeenCalledTimes(1);
    expect(entry.cancel).not.toHaveBeenCalled();
    expect(entry.error).not.toHaveBeenCalled();
  });
});
