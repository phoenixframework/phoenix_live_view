# External Uploads

> This guide continues from the configuration started in the
> server [Uploads guide](uploads.html).

Uploads to external cloud providers, such as Amazon S3,
Google Cloud, etc., can be achieved by using the
`:external` option in [`allow_upload/3`](`Phoenix.LiveView.allow_upload/3`).

You provide a 2-arity function to allow the server to
generate metadata for each upload entry, which is passed to
a user-specified JavaScript function on the client.

Typically when your function is invoked, you will generate a
pre-signed URL, specific to your cloud storage provider, that
will provide temporary access for the end-user to upload data
directly to your cloud storage.

## Chunked HTTP Uploads

For any service that supports large file
uploads via chunked HTTP requests with `Content-Range`
headers, you can use the UpChunk JS library by Mux to do all
the hard work of uploading the file.

You only need to wire the UpChunk instance to the LiveView
UploadEntry callbacks, and LiveView will take care of the rest.

Install [UpChunk](https://github.com/muxinc/upchunk):

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
function that generates a signed URL where the client will
push the bytes for the upload entry.

For example, if you were using a context that provided a
[`start_session`](https://developers.google.com/youtube/v3/guides/using_resumable_upload_protocol##Start_Resumable_Session)
function, you might write something like this:

    defp presign_upload(entry, socket) do
      {:ok, %{"Location" => link}} =
        SomeTube.start_session(%{
          "uploadType" => "resumable",
          "x-upload-content-length" => entry.client_size
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
    upload.on("error", (e) => entry.error(e.detail.message))

    // notify progress events to LiveView
    upload.on("progress", (e) => {
      if(e.detail < 100){ entry.progress(e.detail) }
    })

    // success completes the UploadEntry
    upload.on("success", () => entry.progress(100))
  })
}

// Don't forget to assign Uploaders to the liveSocket
let liveSocket = new LiveSocket("/live", Socket, {
  uploaders: Uploaders,
  params: {_csrf_token: csrfToken}
})
```

## Direct to S3

In order to enforce all of your file constraints when
uploading to S3, it is necessary to perform a multipart form
POST with your file data.

> The following example uses a zero-dependency module
> called [`SimpleS3Upload`](https://gist.github.com/chrismccord/37862f1f8b1f5148644b75d20d1cb073)
> written by Chris McCord to generate pre-signed URLs for S3.

```elixir
def mount(_params, _session, socket) do
  {:ok,
    socket
    |> assign(:uploaded_files, [])
    |> allow_upload(:avatar, accept: :any, max_entries: 3, external: &presign_upload/2)}
end

defp presign_upload(entry, socket) do
  uploads = socket.assigns.uploads
  bucket = "phx-upload-example"
  key = "public/#{entry.client_name}"

  config = %{
    region: "us-east-1",
    access_key_id: System.fetch_env!("AWS_ACCESS_KEY_ID"),
    secret_access_key: System.fetch_env!("AWS_SECRET_ACCESS_KEY")
  }

  {:ok, fields} =
    SimpleS3Upload.sign_form_upload(config, bucket,
      key: key,
      content_type: entry.client_type,
      max_file_size: uploads.avatar.max_file_size,
      expires_in: :timer.hours(1)
    )

  meta = %{uploader: "S3", key: key, url: "http://#{bucket}.s3.amazonaws.com", fields: fields}
  {:ok, meta, socket}
end
```

Here, we implemented a `presign_upload/2` function, which we
passed as a captured anonymous function to `:external`. Next,
we generate a pre-signed URL for the upload. Lastly, we return
our `:ok` result, with a payload of metadata for the client,
along with our unchanged socket. The metadata *must* contain
the `:uploader` key, specifying the name of the JavaScript
client-side uploader, in this case `"S3"`.

To complete the flow, we can implement our `S3` client
uploader and tell the `LiveSocket` where to find it:

```js
let Uploaders = {}

Uploaders.S3 = function(entries, onViewError){
  entries.forEach(entry => {
    let formData = new FormData()
    let {url, fields} = entry.meta
    Object.entries(fields).forEach(([key, val]) => formData.append(key, val))
    formData.append("file", entry.file)
    let xhr = new XMLHttpRequest()
    onViewError(() => xhr.abort())
    xhr.onload = () => xhr.status === 204 ? entry.progress(100) : entry.error()
    xhr.onerror = () => entry.error()
    xhr.upload.addEventListener("progress", (event) => {
      if(event.lengthComputable){
        let percent = Math.round((event.loaded / event.total) * 100)
        if(percent < 100){ entry.progress(percent) }
      }
    })

    xhr.open("POST", url, true)
    xhr.send(formData)
  })
}

let liveSocket = new LiveSocket("/live", Socket, {
  uploaders: Uploaders,
  params: {_csrf_token: csrfToken}
})
```

We define an `Uploaders.S3` function, which receives our entries. It then
performs an AJAX request for each entry, using the `entry.progress()` and
`entry.error()`. functions to report upload events back to the LiveView.
Lastly, we pass the `uploaders` namespace to the `LiveSocket` constructor
to tell phoenix where to find the uploaders returned within the external
metadata.
