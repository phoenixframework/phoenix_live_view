# Uploads

LiveView supports interactive file uploads with progress for
both direct to server uploads as well as external
direct-to-cloud uploads on the client.

Uploads are enabled by using `Phoenix.LiveView.allow_upload/3`
and specifying the constraints, such as accepted file types,
max file size, number of maximum selected entries, etc.
When the client selects file(s), the file metadata is
automatically validated against the `allow_upload`
specification. Uploads are populated in an `@uploads` assign
in the socket, granting reactive based templates that
automatically update with progress, error information, etc.

The complete upload flow is as follows:

## Allow uploads

You enable an upload, typically on mount, via
[`allow_upload/3`](`Phoenix.LiveView.allow_upload/3`):

```elixir
@impl Phoenix.LiveView
def mount(_params, _session, socket) do
  {:ok,
   socket
   |> assign(:uploaded_files, [])
   |> allow_upload(:avatar, accept: ~w(.jpg .jpeg), max_entries: 2)}
end
```

## Render reactive elements

Use the `Phoenix.LiveView.Helpers.live_file_input/2` file
input generator to render a file input for the upload.
The generator has full support for `multiple=true`, and the
attribute will automatically be set if `:max_entries` is
greater than 1 in the [`allow_upload/3`](`Phoenix.LiveView.allow_upload/3`) spec.

Within the template, you render each upload entry. The entry
struct contains all the information about the upload,
including progress, name, errors, etc.

For example:

```elixir
<%= for entry <- @uploads.avatar.entries do %>
<%= entry.client_name %> - <%= entry.progress %>%
<% end %>

<form phx-submit="save">
  <%= live_file_input @uploads.avatar %>
  <button type="submit">Upload</button>
</form>
```

Reactive updates to the template will occur as the end-user
interacts with the file input.

## Consume uploaded entries

When the end-user submits a form containing a
[`live_file_input/2`](`Phoenix.LiveView.Helpers.live_file_input/2`),
the JavaScript client first uploads the file(s) before
invoking the callback for the form's `phx-submit` event.

Within the callback for the `phx-submit` event, you invoke
the `Phoenix.LiveView.consume_uploaded_entries/3` function
to process the completed uploads, persisting the relevant
upload data alongside the form data:

```elixir
def handle_event("save", _params, socket) do
  uploaded_files =
    consume_uploaded_entries(socket, :avatar, fn %{path: path} ->
      dest = Path.join("priv/static/uploads", Path.basename(path))
      File.cp!(path, dest)
      Routes.static_path(socket, "/uploads/#{Path.basename(dest)}")
    end)
  {:noreply, update(socket, :uploaded_files, &(&1 ++ uploaded_files))}
end
```

> **Note**: While client metadata cannot be trusted, max file
> size validations are enforced as each chunk is received
> when performing direct to server uploads.


## External Uploads

Uploads to external cloud providers, such as Amazon S3, Google Cloud, etc, can
be achieved by using the `:external` option in [`allow_upload/3`](`Phoenix.LiveView.allow_upload/3`). A 2-arity function
is provided to allow the server to generate metadata for each entry, which is
passed to a user-specified JavaScript function on the client. For example,
presigned uploads can be generated for the client to perform a direct-to-cloud
upload. An S3 example would look something like this:

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
        S3.sign_form_upload(config, bucket,
          key: key,
          content_type: entry.client_type,
          max_file_size: uploads.avatar.max_file_size,
          expires_in: :timer.hours(1)
        )

      meta = %{uploader: "S3", key: key, url: "http://#{bucket}.s3.amazonaws.com", fields: fields}
      {:ok, meta, socket}
    end

Here, we implemented a `presign_upload/2` function, which we passed as a captured anonymous
function to `:external`. Next, we used `ExAws` to generate a presigned URL for the
upload. Lastly, we return our `:ok` result, with a payload of metadata for the client,
along with our unchanged socket. The metadata *must* contain the `:uploader` key,
specifying name of the JavaScript client-side uploader, in this case "S3".

To complete the flow, we can implement our `S3` client uploader and tell the
`LiveSocket` where to find it:

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
    xhr.onload = () => xhr.status === 204 ? entry.done() : entry.error()
    xhr.onerror = () => entry.error()
    xhr.upload.addEventListener("progress", (event) => {
      if(event.lengthComputable){
        let percent = Math.round((event.loaded / event.total) * 100)
        entry.progress(percent)
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
performs an AJAX request for each entry, using the `entry.progress()`,
`entry.error()`, and `entry.done()` functions to report upload events
back to the LiveView. Lastly, we pass the `uploaders` namespace to the
`LiveSocket` constructor to tell phoenix where to find the uploaders
return within the external metadata.

For another example of external uploads, see the [Chunked HTTP Uploads](chunked-http-uploads.md) guide.