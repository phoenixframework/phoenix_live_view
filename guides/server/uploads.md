# Uploads

LiveView supports interactive file uploads with progress for
both direct to server uploads as well as direct-to-cloud
[external uploads](uploads-external.html) on the client.

### Built-in Features

  * Accept specification - Define accepted file types, max
    number of entries, max file size, etc. When the client
    selects file(s), the file metadata is automatically
    validated against the specification. See
    `Phoenix.LiveView.allow_upload/3`.

  * Reactive entries - Uploads are populated in an
    `@uploads` assign in the socket. Entries automatically
    respond to progress, errors, cancelation, etc.

  * Drag and drop - Use the `phx-drop-target` attribute to
    enable. See `Phoenix.LiveView.Helpers.live_file_input/2`.

## Allow uploads

You enable an upload, typically on mount, via [`allow_upload/3`]:

```elixir
@impl Phoenix.LiveView
def mount(_params, _session, socket) do
  {:ok,
   socket
   |> assign(:uploaded_files, [])
   |> allow_upload(:avatar, accept: ~w(.jpg .jpeg), max_entries: 2)}
end
```

That's it for now! We will come back to the LiveView to
implement some form- and upload-related callbacks later, but
most of the functionality around uploads takes place in the
template.

## Render reactive elements

Use the `Phoenix.LiveView.Helpers.live_file_input/2` file
input generator to render a file input for the upload:

```elixir
# lib/my_app_web/live/upload_live.html.leex

<form id="upload-form" phx-submit="save" phx-change="validate">
  <%= live_file_input @uploads.avatar %>
  <button type="submit">Upload</button>
</form>
```

> **Important:** You must bind `phx-submit` and `phx-change` on the form.

Note that while [`live_file_input/2`]
allows you to set additional attributes on the file input,
many attributes such as `id`, `accept`, and `multiple` will
be set automatically based on the [`allow_upload/3`] spec.

Reactive updates to the template will occur as the end-user
interacts with the file input.

### Upload entries

Uploads are populated in an `@uploads` assign in the socket.
Each allowed upload contains a _list_ of entries,
irrespective of the `:max_entries` value in the
[`allow_upload/3`] spec. These entry structs contain all the
information about an upload, including progress, client file
info, errors, etc.

Let's look at an annotated example:

```elixir
# lib/my_app_web/live/upload_live.html.leex

<%# use phx-drop-target with the upload ref to enable file drag and drop %>
<section phx-drop-target="<%= @uploads.avatar.ref %>">

<%# render each avatar entry %>
<%= for entry <- @uploads.avatar.entries do %>
  <article class="upload-entry">

    <figure>
      <%# Phoenix.LiveView.Helpers.live_img_preview/2 renders a client-side preview %>
      <%= live_img_preview entry %>
      <figcaption><%= entry.client_name %></figcaption>
    </figure>

    <%# entry.progress will update automatically for in-flight entries %>
    <progress value="<%= entry.progress %>" max="100"> <%= entry.progress %>% </progress>

    <%# a regular click event whose handler will invoke Phoenix.LiveView.cancel_upload/3 %>
    <button phx-click="cancel-upload" phx-value-ref="<%= entry.ref %>" aria-label="cancel">&times;</button>

    <%# Phoenix.LiveView.Helpers.upload_errors/2 returns a list of error atoms %>
    <%= for err <- upload_errors(@uploads.avatar, entry) do %>
      <p class="alert alert-danger"><%= error_to_string(err) %></p>
    <% end %>

  </article>
<% end %>

</section>
```

The `section` element in the example acts as the
`phx-drop-target` for the `:avatar` upload. Users can interact
with the file input or they can drop files over the element
to add new entries.

Upload entries are created when a file is added to the form
input and each will exist until it has been consumed,
following a successfully completed upload.

### Entry validation

Validation occurs automatically based on any conditions
that were specified in [`allow_upload/3`] however, as
mentioned previously you are required to bind `phx-change`
on the form in order for the validation to be performed.
Therefore you must implement at least a minimal callback:

```elixir
@impl Phoenix.LiveView
def handle_event("validate", _params, socket) do
  {:noreply, socket}
end
```

Entries for files that do not match the [`allow_upload/3`]
spec will contain errors. Use
`Phoenix.LiveView.Helpers.upload_errors/2` and your own
helper function to render a friendly error message:

```elixir
def error_to_string(:too_large), do: "Too large"
def error_to_string(:too_many_files), do: "You have selected too many files"
def error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
```

### Cancel an entry

Upload entries may also be canceled, either programmatically
or as a result of a user action. For instance, to handle the
click event in the template above, you could do the following:

```elixir
@impl Phoenix.LiveView
def handle_event("cancel-upload", %{"ref" => ref}, socket) do
  {:noreply, cancel_upload(socket, :avatar, ref)}
end
```

## Consume uploaded entries

When the end-user submits a form containing a [`live_file_input/2`],
the JavaScript client first uploads the file(s) before
invoking the callback for the form's `phx-submit` event.

Within the callback for the `phx-submit` event, you invoke
the `Phoenix.LiveView.consume_uploaded_entries/3` function
to process the completed uploads, persisting the relevant
upload data alongside the form data:

```elixir
@impl Phoenix.LiveView
def handle_event("save", _params, socket) do
  uploaded_files =
    consume_uploaded_entries(socket, :avatar, fn %{path: path}, _entry ->
      dest = Path.join([:code.priv_dir(:my_app), "static", "uploads", Path.basename(path)])
      File.cp!(path, dest)
      Routes.static_path(socket, "/uploads/#{Path.basename(dest)}")
    end)

  {:noreply, update(socket, :uploaded_files, &(&1 ++ uploaded_files))}
end
```

> **Note**: While client metadata cannot be trusted, max file
> size validations are enforced as each chunk is received
> when performing direct to server uploads.

For more information on implementing client-side,
direct-to-cloud uploads, see the [External Uploads guide](uploads-external.md).

## Appendix A: UploadLive

A complete example of the LiveView from this guide:

```elixir
# lib/my_app_web/live/upload_live.ex
defmodule MyAppWeb.UploadLive do
  use MyAppWeb, :live_view

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok,
    socket
    |> assign(:uploaded_files, [])
    |> allow_upload(:avatar, accept: ~w(.jpg .jpeg), max_entries: 2)}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :avatar, ref)}
  end

  @impl Phoenix.LiveView
  def handle_event("save", _params, socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :avatar, fn %{path: path}, _entry ->
        dest = Path.join([:code.priv_dir(:my_app), "static", "uploads", Path.basename(path)])
        File.cp!(path, dest)
        Routes.static_path(socket, "/uploads/#{Path.basename(dest)}")
      end)

    {:noreply, update(socket, :uploaded_files, &(&1 ++ uploaded_files))}
  end

  defp error_to_string(:too_large), do: "Too large"
  defp error_to_string(:too_many_files), do: "You have selected too many files"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
end
```

[`allow_upload/3`]: `Phoenix.LiveView.allow_upload/3`
[`live_file_input/2`]: `Phoenix.LiveView.Helpers.live_file_input/2`
