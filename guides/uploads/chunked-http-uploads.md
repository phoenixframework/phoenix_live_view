# Chunked HTTP Uploads

This guide provides an implementation of an
external uploader for any service that supports large file
uploads via `PUT` requests with `Content-Range` headers.

Fortunately, most content storage providers (Box, Dropbox,
Google Cloud Storage, Mux, YouTube, etc.) offer a mechanism
to upload files in this way.

On the client-side, this guide will use [UpChunk](https://github.com/muxinc/upchunk)
by Mux to do all the actual work to upload the file.
You merely need to wire the UpChunk instance to the LiveView
UploadEntry callbacks, and LiveView will take care of the rest.

Install UpChunk:

    npm install --prefix assets --save @mux/upchunk

Configure your uploader on `c:Phoenix.LiveView.mount/3`:

    def mount(_params, _session, socket) do
      {:ok,
       socket
       |> assign(:uploaded_files, [])
       |> allow_upload(:avatar, accept: :any, max_entries: 3, external: &presign_upload/2)}
    end

Supply the `:external` option to
`Phoenix.LiveView.allow_upload/3`. It requires a 2-arity
Function that generates a signed URL where the client will
push the bytes for the upload entry.

For example, if you were using a context that provided a
[`get_temporary_upload_link`](https://www.dropbox.com/developers/documentation/http/documentation#files-get_temporary_upload_link)
function, you might write something like this:

    defp presign_upload(entry, socket) do
      {:ok, %{"link" => link}} =
        Dropbox.get_temporary_upload_link(%{
          path: entry.client_name,
          mode: "add",
          autorename: true,
        })

      {:ok, %{uploader: "UpChunk", entrypoint: link}, socket}
    end

Finally, on the client-side, we use UpChunk to create an
upload from the temporary URL generated on the server and
attach listeners for its events to the entry's callbacks:

```js
import * as UpChunk from "@mux/upchunk"

let Uploaders = {}

Uploaders.UpChunk = function(entries, onViewError){
  entries.forEach(entry => {
    // create the upload session with UpChunk
    let { file, meta: { entrypoint } } = entry
    let upload = UpChunk.createUpload({ entrypoint, file })

    // stop uploading in the event of a view error
    onViewError(() => upload.pause())

    // upload error triggers LiveView error
    upload.on("error", (e) => entry.error(e.detail))

    // notify progress events to LiveView
    upload.on("progress", (e) => entry.progress(e.detail))

    // notify complete to LiveView
    upload.on("success", () => entry.done())
  })
}

// Don't forget to assign Uploaders to the liveSocket
let liveSocket = new LiveSocket("/live", Socket, {
  uploaders: Uploaders,
  params: {_csrf_token: csrfToken}
})
```