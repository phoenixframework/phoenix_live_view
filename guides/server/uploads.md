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
    consume_uploaded_entries(socket, :avatar, fn %{path: path}, _entry ->
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

For more information on implementing client-side,
direct-to-cloud uploads, see the [External Uploads guide](uploads-external.md).
