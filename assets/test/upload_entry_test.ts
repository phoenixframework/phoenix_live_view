import UploadEntry from "phoenix_live_view/upload_entry";
import LiveUploader from "phoenix_live_view/live_uploader";
import { PHX_LIVE_FILE_UPDATED } from "phoenix_live_view/constants";

describe("UploadEntry", () => {
  test.each([false, true])(
    "an error completes once without waiting for progress (auto upload: %s)",
    (autoUpload) => {
      const input = document.createElement("input");
      input.type = "file";
      const file = new File(["contents"], "file.txt");
      LiveUploader.trackFiles(input, [file]);
      const replies: (() => void)[] = [];
      const view = {
        pushFileProgress: jest.fn((_input, _ref, _progress, onReply) => {
          if (onReply) replies.push(onReply);
        }),
      };
      const entry = new UploadEntry(input, file, view, autoUpload);
      const onDone = jest.fn();
      entry.onDone(onDone);
      entry.progress(100);
      entry.error("failed");
      entry.error("failed again");
      entry.cancel();
      replies[0]();
      input.dispatchEvent(new CustomEvent(PHX_LIVE_FILE_UPDATED));

      expect(entry.isDone()).toBe(true);
      expect(entry.isErrored()).toBe(true);
      expect(onDone).toHaveBeenCalledTimes(1);
      expect(view.pushFileProgress).toHaveBeenCalledTimes(2);
      expect(view.pushFileProgress).toHaveBeenLastCalledWith(input, entry.ref, {
        error: "failed",
      });
    },
  );

  test("a failure already known to the server completes without pushing progress", () => {
    const input = document.createElement("input");
    input.type = "file";
    const file = new File(["contents"], "file.txt");
    LiveUploader.trackFiles(input, [file]);
    const view = { pushFileProgress: jest.fn() };
    const entry = new UploadEntry(input, file, view, false);
    const onDone = jest.fn();
    entry.onDone(onDone);
    entry.fail("writer_error", false);
    entry.error("failed");

    expect(entry.isDone()).toBe(true);
    expect(entry.isErrored()).toBe(true);
    expect(onDone).toHaveBeenCalledTimes(1);
    expect(view.pushFileProgress).not.toHaveBeenCalled();
    expect(LiveUploader.activeFiles(input)).toEqual([]);
  });
});
