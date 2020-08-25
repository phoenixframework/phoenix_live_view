defmodule Phoenix.LiveView.Utils do
  # Shared helpers used mostly by Channel and Diff,
  # but also Static, and LiveViewTest.
  @moduledoc false

  alias Phoenix.LiveView.{Rendered, Socket, UploadConfig, UploadEntry}

  # All available mount options
  @mount_opts [:temporary_assigns, :layout]

  @max_flash_age :timer.seconds(60)
  @refs_to_names :__phoenix_refs_to_names__

  @doc """
  Assigns a value if it changed change.
  """
  def assign(%Socket{} = socket, key, value) do
    case socket do
      %{assigns: %{^key => ^value}} -> socket
      %{} -> force_assign(socket, key, value)
    end
  end

  @doc """
  Forces an assign.
  """
  def force_assign(%Socket{assigns: assigns, changed: changed} = socket, key, val) do
    current_val = Map.get(assigns, key)
    # If the current value is a map, we store it in changed so
    # we can perform nested change tracking. Also note the use
    # of put_new is important. We want to keep the original value
    # from assigns and not any intermediate ones that may appear.
    new_changed = Map.put_new(changed, key, if(is_map(current_val), do: current_val, else: true))
    new_assigns = Map.put(assigns, key, val)
    %{socket | assigns: new_assigns, changed: new_changed}
  end

  @doc """
  Clears the changes from the socket assigns.
  """
  def clear_changed(%Socket{private: private, assigns: assigns} = socket) do
    temporary = Map.get(private, :temporary_assigns, %{})
    %Socket{socket | changed: %{}, assigns: Map.merge(assigns, temporary)}
  end

  @doc """
  Checks if the socket changed.
  """
  def changed?(%Socket{changed: changed}), do: changed != %{}

  @doc """
  Checks if the given assign changed.
  """
  def changed?(%Socket{changed: %{} = changed}, assign), do: Map.has_key?(changed, assign)
  def changed?(%Socket{}, _), do: false

  @doc """
  Configures the socket for use.
  """
  def configure_socket(%Socket{id: nil} = socket, private, action, flash, host_uri) do
    %{
      socket
      | id: random_id(),
        private: private,
        assigns: configure_assigns(socket.assigns, socket.view, action, flash),
        host_uri: prune_uri(host_uri)
    }
  end

  def configure_socket(%Socket{} = socket, private, action, flash, host_uri) do
    assigns = configure_assigns(socket.assigns, socket.view, action, flash)
    %{socket | host_uri: prune_uri(host_uri), private: private, assigns: assigns}
  end

  defp configure_assigns(assigns, view, action, flash) do
    Map.merge(assigns, %{live_module: view, live_action: action, flash: flash})
  end

  defp prune_uri(:not_mounted_at_router), do: :not_mounted_at_router

  defp prune_uri(url) do
    %URI{host: host, port: port, scheme: scheme} = url

    if host == nil do
      raise "client did not send full URL, missing host in #{url}"
    end

    %URI{host: host, port: port, scheme: scheme}
  end

  @doc """
  Returns a random ID with valid DOM tokens
  """
  def random_id do
    "phx-"
    |> Kernel.<>(random_encoded_bytes())
    |> String.replace(["/", "+"], "-")
  end

  @doc """
  Prunes any data no longer needed after mount.
  """
  def post_mount_prune(%Socket{} = socket) do
    socket
    |> clear_changed()
    |> drop_private([:connect_info, :connect_params, :assign_new])
  end

  @doc """
  Renders the view with socket into a rendered struct.
  """
  def to_rendered(socket, view) do
    assigns = render_assigns(socket)

    inner_content =
      assigns
      |> view.render()
      |> check_rendered!(view)

    case layout(socket, view) do
      {layout_mod, layout_template} ->
        assigns = put_in(assigns[:inner_content], inner_content)
        assigns = put_in(assigns.__changed__[:inner_content], true)

        layout_template
        |> layout_mod.render(assigns)
        |> check_rendered!(layout_mod)

      false ->
        inner_content
    end
  end

  defp check_rendered!(%Rendered{} = rendered, _view), do: rendered

  defp check_rendered!(other, view) do
    raise RuntimeError, """
    expected #{inspect(view)} to return a %Phoenix.LiveView.Rendered{} struct

    Ensure your render function uses ~L, or your eex template uses the .leex extension.

    Got:

        #{inspect(other)}

    """
  end

  @doc """
  Returns the socket's flash messages.
  """
  def get_flash(%Socket{assigns: assigns}), do: assigns.flash
  def get_flash(%{} = flash, key), do: flash[key]

  @doc """
  Puts a new flash with the socket's flash messages.
  """
  def replace_flash(%Socket{} = socket, %{} = new_flash) do
    assign(socket, :flash, new_flash)
  end

  @doc """
  Clears the flash.
  """
  def clear_flash(%Socket{} = socket) do
    socket
    |> assign(:flash, %{})
    |> Map.update!(:changed, &Map.delete(&1, {:private, :flash}))
  end

  @doc """
  Clears the key from the flash.
  """
  def clear_flash(%Socket{} = socket, key) do
    key = flash_key(key)
    new_flash = Map.delete(socket.assigns.flash, key)

    socket
    |> assign(:flash, new_flash)
    |> update_changed({:private, :flash}, &Map.delete(&1 || %{}, key))
  end

  @doc """
  Puts a flash message in the socket.
  """
  def put_flash(%Socket{assigns: assigns} = socket, key, msg) do
    key = flash_key(key)
    new_flash = Map.put(assigns.flash, key, msg)

    socket
    |> assign(:flash, new_flash)
    |> update_changed({:private, :flash}, &Map.put(&1 || %{}, key, msg))
  end

  @doc """
  Returns a map of the flash messages which have changed.
  """
  def changed_flash(%Socket{} = socket) do
    socket.changed[{:private, :flash}] || %{}
  end

  defp flash_key(binary) when is_binary(binary), do: binary
  defp flash_key(atom) when is_atom(atom), do: Atom.to_string(atom)

  @doc """
  Annotates the changes with the event to be pushed.
  """
  def push_event(%Socket{} = socket, event, %{} = payload) do
    update_changed(socket, {:private, :push_events}, &[[event, payload] | &1 || []])
  end

  @doc """
  Annotates the reply in the socket changes.
  """
  def put_reply(%Socket{} = socket, %{} = payload) do
    update_changed(socket, {:private, :push_reply}, fn _ -> payload end)
  end

  @doc """
  Returns the push events in the socket.
  """
  def get_push_events(%Socket{} = socket) do
    Enum.reverse(socket.changed[{:private, :push_events}] || [])
  end

  @doc """
  Returns the reply in the socket.
  """
  def get_reply(%Socket{} = socket) do
    socket.changed[{:private, :push_reply}]
  end

  defp update_changed(%Socket{} = socket, key, func) do
    update_in(socket.changed[key], func)
  end

  @doc """
  TODO
  """
  def allow_upload(%Socket{} = socket, name, opts) when is_atom(name) and is_list(opts) do
    # TODO raise on non-canceled active upload for existing name?
    ref = random_id()
    uploads = socket.assigns[:uploads] || %{}
    upload_config = UploadConfig.build(name, ref, opts)

    new_uploads =
      uploads
      |> Map.put(name, upload_config)
      |> Map.update(@refs_to_names, %{ref => name}, fn refs -> Map.put(refs, ref, name) end)

    assign(socket, :uploads, new_uploads)
  end

  @doc """
  TODO
  """
  def disallow_upload(%Socket{} = socket, name) when is_atom(name) do
    # TODO raise or cancel active upload for existing name?
    uploads = socket.assigns[:uploads] || %{}

    upload_config =
      uploads
      |> Map.fetch!(name)
      |> UploadConfig.disallow()

    new_refs =
      Enum.reduce(uploads[@refs_to_names], uploads[@refs_to_names], fn
        {ref, ^name}, acc -> Map.drop(acc, ref)
        {_ref, _name}, acc -> acc
      end)

    new_uploads =
      uploads
      |> Map.put(name, upload_config)
      |> Map.update!(@refs_to_names, fn _ -> new_refs end)

    assign(socket, :uploads, new_uploads)
  end

  @doc """
  TODO
  """
  def cancel_upload(socket, name, entry_ref) do
    upload_config = Map.fetch!(socket.assigns[:uploads] || %{}, name)
    %UploadEntry{} = entry = UploadConfig.get_entry_by_ref(upload_config, entry_ref)

    upload_config
    |> UploadConfig.cancel_entry(entry)
    |> update_uploads(socket)
  end

  @doc """
  TODO
  """
  def get_uploaded_entries(%Socket{} = socket, name) when is_atom(name) do
    upload_config = Map.fetch!(socket.assigns[:uploads] || %{}, name)
    UploadConfig.uploaded_entries(upload_config)
  end

  @doc """
  TODO
  """
  def update_upload_entry_meta(%Socket{} = socket, upload_conf_name, %UploadEntry{} = entry, meta) do
    socket.assigns.uploads
    |> Map.fetch!(upload_conf_name)
    |> UploadConfig.update_entry_meta(entry.ref, meta)
    |> update_uploads(socket)
  end

  @doc """
  TODO
  """
  def update_progress(%Socket{} = socket, config_ref, entry_ref, progress)
      when is_integer(progress) and progress >= 0 and progress <= 100 do
    {_uploads, _name, upload_config} = get_upload_by_ref!(socket, config_ref)

    upload_config
    |> UploadConfig.update_progress(entry_ref, progress)
    |> update_uploads(socket)
  end

  def update_progress(%Socket{} = socket, config_ref, entry_ref, %{"error" => reason})
      when is_binary(reason) do
    {_uploads, _name, conf} = get_upload_by_ref!(socket, config_ref)

    put_upload_error(socket, conf.name, entry_ref, :external_client_failure)
  end

  @doc """
  TODO
  """
  def put_entries(%Socket{} = socket, %UploadConfig{} = conf, entries) do
    case UploadConfig.put_entries(conf, entries) do
      {:ok, new_config} ->
        {:ok, update_uploads(new_config, socket)}

      {:error, new_config} ->
        {:error, update_uploads(new_config, socket), new_config.errors}
    end
  end

  @doc """
  TODO
  """
  def unregister_completed_entry_upload(%Socket{} = socket, %UploadConfig{} = conf, pid)
      when is_pid(pid) do
    conf
    |> UploadConfig.unregister_completed_entry(pid)
    |> update_uploads(socket)
  end

  @doc """
  TODO
  """
  def register_entry_upload(%Socket{} = socket, %UploadConfig{} = conf, pid, entry_ref)
      when is_pid(pid) do
    case UploadConfig.register_entry_upload(conf, pid, entry_ref) do
      {:ok, new_config} ->
        entry = UploadConfig.get_entry_by_ref(new_config, entry_ref)
        {:ok, update_uploads(new_config, socket), entry}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  TODO
  """
  def put_upload_error(%Socket{} = socket, conf_name, entry_ref, reason) do
    conf = Map.fetch!(socket.assigns.uploads, conf_name)

    conf
    |> UploadConfig.put_error(entry_ref, reason)
    |> update_uploads(socket)
  end

  @doc """
  TODO
  """
  def get_upload_by_ref!(%Socket{} = socket, config_ref) do
    uploads = socket.assigns[:uploads] || raise(ArgumentError, "no uploads have been allowed")
    name = Map.fetch!(uploads[@refs_to_names], config_ref)
    config = Map.fetch!(uploads, name)

    {uploads, name, config}
  end

  @doc """
  TODO
  """
  def get_upload_by_pid(socket, pid) when is_pid(pid) do
    Enum.find_value(socket.assigns[:uploads] || %{}, fn
      {@refs_to_names, _} -> false
      {_name, %UploadConfig{} = conf} -> UploadConfig.get_entry_by_pid(conf, pid) && conf
    end)
  end

  @doc """
  TODO
  """
  def uploaded_entries(%Socket{} = socket, name) do
    entries =
      case Map.fetch(socket.assigns[:uploads] || %{}, name) do
        {:ok, conf} -> conf.entries
        :error -> []
      end

    Enum.reduce(entries, {[], []}, fn entry, {done, in_progress} ->
      if entry.done? do
        {[entry | done], in_progress}
      else
        {done, [entry | in_progress]}
      end
    end)
  end

  @doc """
  TODO
  """
  def consume_uploaded_entries(%Socket{} = socket, name, func) when is_function(func, 2) do
    conf =
      socket.assigns[:uploads][name] ||
        raise ArgumentError, "no upload allowed for #{inspect(name)}"

    entries =
      case uploaded_entries(socket, name) do
        {[_ | _] = done_entries, []} ->
          done_entries

        {_, [_ | _]} ->
          raise ArgumentError, "cannot consume uploaded files when entries are still in progress"

        {[], []} ->
          raise ArgumentError, "cannot consume uploaded files without active entries"
      end

    consume_entries(conf, entries, func)
  end

  @doc """
  TODO
  """
  def consume_uploaded_entry(%Socket{} = socket, %UploadEntry{} = entry, func)
      when is_function(func, 1) do
    unless entry.done?,
      do: raise(ArgumentError, "cannot consume uploaded files when entries are still in progress")

    conf = Map.fetch!(socket.assigns[:uploads], entry.upload_config)
    [result] = consume_entries(conf, [entry], func)

    result
  end

  @doc """
  TODO
  """
  def drop_upload_entries(%Socket{} = socket, %UploadConfig{} = conf) do
    conf.entries
    |> Enum.reduce(conf, fn entry, acc -> UploadConfig.drop_entry(acc, entry) end)
    |> update_uploads(socket)
  end

  defp update_uploads(%UploadConfig{} = new_conf, %Socket{} = socket) do
    new_uploads = Map.update!(socket.assigns.uploads, new_conf.name, fn _ -> new_conf end)
    assign(socket, :uploads, new_uploads)
  end

  @doc """
  TODO
  """
  def consume_entries(%UploadConfig{} = conf, entries, func)
      when is_list(entries) and is_function(func) do
    if conf.external do
      results =
        entries
        |> Enum.map(fn entry -> {entry, Map.fetch!(conf.entry_refs_to_metas, entry.ref)} end)
        |> Enum.map(fn {entry, meta} ->
          cond do
            is_function(func, 1) -> func.(meta)
            is_function(func, 2) -> func.(meta, entry)
          end
        end)

      Phoenix.LiveView.Channel.drop_upload_entries(conf)

      results
    else
      entries
      |> Enum.map(fn entry -> {entry, UploadConfig.entry_pid(conf, entry)} end)
      |> Enum.filter(fn {_entry, pid} -> is_pid(pid) end)
      |> Enum.map(fn {entry, pid} -> Phoenix.LiveView.UploadChannel.consume(pid, entry, func) end)
    end
  end

  @doc """
  TODO
  """
  def generate_preflight_response(%Socket{} = socket, name) do
    %UploadConfig{} = conf = Map.fetch!(socket.assigns.uploads, name)

    client_meta = %{
      max_file_size: conf.max_file_size,
      max_entries: conf.max_entries,
      chunk_size: conf.chunk_size
    }

    case conf do
      %UploadConfig{external: false} = conf ->
        channel_preflight(socket, conf, client_meta)

      %UploadConfig{external: func} when is_function(func) ->
        external_preflight(socket, conf, client_meta)
    end
  end

  defp channel_preflight(%Socket{} = socket, %UploadConfig{} = conf, %{} = client_config_meta) do
    reply_entries =
      for entry <- conf.entries, into: %{} do
        token =
          Phoenix.LiveView.Static.sign_token(socket.endpoint, %{
            pid: self(),
            ref: {conf.ref, entry.ref}
          })

        {entry.ref, token}
      end

    {:ok, %{ref: conf.ref, config: client_config_meta, entries: reply_entries}, socket}
  end

  def external_preflight(%Socket{} = socket, %UploadConfig{} = conf, client_config_meta) do
    reply_entries =
      Enum.reduce_while(conf.entries, {:ok, %{}, socket}, fn entry, {:ok, metas, acc} ->
        case conf.external.(entry, acc) do
          {:ok, %{} = meta, new_socket} ->
            new_socket = update_upload_entry_meta(new_socket, conf.name, entry, meta)
            {:cont, {:ok, Map.put(metas, entry.ref, meta), new_socket}}

          {:error, %{} = meta, new_socket} ->
            {:halt, {:error, {entry.ref, meta}, new_socket}}
        end
      end)

    case reply_entries do
      {:ok, entry_metas, new_socket} ->
        {:ok, %{ref: conf.ref, config: client_config_meta, entries: entry_metas}, new_socket}

      {:error, {ref, meta_reason}, new_socket} ->
        new_socket = put_upload_error(new_socket, conf.name, ref, meta_reason)
        {:error, %{ref: conf.ref, error: [ref, :preflight_failed]}, new_socket}
    end
  end

  @doc """
  Returns the configured signing salt for the endpoint.
  """
  def salt!(endpoint) when is_atom(endpoint) do
    endpoint.config(:live_view)[:signing_salt] ||
      raise ArgumentError, """
      no signing salt found for #{inspect(endpoint)}.

      Add the following LiveView configuration to your config/config.exs:

          config :my_app, MyAppWeb.Endpoint,
              ...,
              live_view: [signing_salt: "#{random_encoded_bytes()}"]

      """
  end

  @doc """
  Returns the internal or external matched LiveView route info for the given uri
  """
  def live_link_info!(%Socket{router: nil}, view, _uri) do
    raise ArgumentError,
          "cannot invoke handle_params/3 on #{inspect(view)} " <>
            "because it is not mounted nor accessed through the router live/3 macro"
  end

  def live_link_info!(%Socket{router: router, endpoint: endpoint} = socket, view, uri) do
    %URI{host: host, path: path, query: query} = parsed_uri = URI.parse(uri)
    host = host || socket.host_uri.host
    query_params = if query, do: Plug.Conn.Query.decode(query), else: %{}
    decoded_path = URI.decode(path || "")
    split_path = for segment <- String.split(decoded_path, "/"), segment != "", do: segment
    route_path = strip_segments(endpoint.script_name(), split_path) || split_path

    case Phoenix.Router.route_info(router, "GET", route_path, host) do
      %{plug: Phoenix.LiveView.Plug, phoenix_live_view: {^view, action}, path_params: path_params} ->
        {:internal, Map.merge(query_params, path_params), action, parsed_uri}

      %{} ->
        {:external, parsed_uri}

      :error ->
        raise ArgumentError,
              "cannot invoke handle_params nor live_redirect/live_patch to #{inspect(uri)} " <>
                "because it isn't defined in #{inspect(router)}"
    end
  end

  defp strip_segments([head | tail1], [head | tail2]), do: strip_segments(tail1, tail2)
  defp strip_segments([], tail2), do: tail2
  defp strip_segments(_, _), do: nil

  @doc """
  Raises error message for bad live patch on mount.
  """
  def raise_bad_mount_and_live_patch!() do
    raise RuntimeError, """
    attempted to live patch while mounting.

    a LiveView cannot be mounted while issuing a live patch to the client. \
    Use push_redirect/2 or redirect/2 instead if you wish to mount and redirect.
    """
  end

  @doc """
  Calls the `c:Phoenix.LiveView.mount/3` callback, otherwise returns the socket as is.
  """
  def maybe_call_live_view_mount!(%Socket{} = socket, view, params, session) do
    if function_exported?(view, :mount, 3) do
      :telemetry.span(
        [:phoenix, :live_view, :mount],
        %{socket: socket, params: params, session: session},
        fn ->
          socket =
            params
            |> view.mount(session, socket)
            |> handle_mount_result!({:mount, 3, view})

          {socket, %{socket: socket, params: params, session: session}}
        end
      )
    else
      socket
    end
  end

  @doc """
  Calls the `c:Phoenix.LiveComponent.mount/1` callback, otherwise returns the socket as is.
  """
  def maybe_call_live_component_mount!(%Socket{} = socket, view) do
    if function_exported?(view, :mount, 1) do
      socket
      |> view.mount()
      |> handle_mount_result!({:mount, 1, view})
    else
      socket
    end
  end

  defp handle_mount_result!({:ok, %Socket{} = socket, opts}, {:mount, arity, _view})
       when is_list(opts) do
    validate_mount_redirect!(socket.redirected)

    Enum.reduce(opts, socket, fn {key, val}, acc -> mount_opt(acc, key, val, arity) end)
  end

  defp handle_mount_result!({:ok, %Socket{} = socket}, {:mount, _arity, _view}) do
    validate_mount_redirect!(socket.redirected)

    socket
  end

  defp handle_mount_result!(response, {:mount, arity, view}) do
    raise ArgumentError, """
    invalid result returned from #{inspect(view)}.mount/#{arity}.

    Expected {:ok, socket} | {:ok, socket, opts}, got: #{inspect(response)}
    """
  end

  defp validate_mount_redirect!({:live, {_, _}, _}), do: raise_bad_mount_and_live_patch!()
  defp validate_mount_redirect!(_), do: :ok

  @doc """
  Calls the `handle_params/3` callback, and returns the result.

  This function expects the calling code has checked to see if this function has
  been exported. Raises an `ArgumentError` on unexpected return types.
  """
  def call_handle_params!(%Socket{} = socket, view, params, uri) do
    :telemetry.span(
      [:phoenix, :live_view, :handle_params],
      %{socket: socket, params: params, uri: uri},
      fn ->
        case view.handle_params(params, uri, socket) do
          {:noreply, %Socket{} = socket} ->
            {{:noreply, socket}, %{socket: socket, params: params, uri: uri}}

          other ->
            raise ArgumentError, """
            invalid result returned from #{inspect(view)}.handle_params/3.

            Expected {:noreply, socket}, got: #{inspect(other)}
            """
        end
      end
    )
  end

  @doc """
  Calls the optional `update/2` callback, otherwise update the socket directly.
  """
  def maybe_call_update!(socket, component, assigns) do
    if function_exported?(component, :update, 2) do
      socket =
        case component.update(assigns, socket) do
          {:ok, %Socket{} = socket} ->
            socket

          other ->
            raise ArgumentError, """
            invalid result returned from #{inspect(component)}.update/2.

            Expected {:ok, socket}, got: #{inspect(other)}
            """
        end

      if socket.redirected do
        raise "cannot redirect socket on update/2"
      end

      socket
    else
      Enum.reduce(assigns, socket, fn {k, v}, acc -> assign(acc, k, v) end)
    end
  end

  @doc """
  Signs the socket's flash into a token if it has been set.
  """
  def sign_flash(endpoint_mod, %{} = flash) do
    Phoenix.Token.sign(endpoint_mod, flash_salt(endpoint_mod), flash)
  end

  @doc """
  Verifies the socket's flash token.
  """
  def verify_flash(endpoint_mod, flash_token) do
    salt = flash_salt(endpoint_mod)

    case Phoenix.Token.verify(endpoint_mod, salt, flash_token, max_age: @max_flash_age) do
      {:ok, flash} -> flash
      {:error, _reason} -> %{}
    end
  end

  defp random_encoded_bytes do
    binary = <<
      System.system_time(:nanosecond)::64,
      :erlang.phash2({node(), self()})::16,
      :erlang.unique_integer()::16
    >>

    Base.url_encode64(binary)
  end

  defp mount_opt(%Socket{} = socket, key, val, _arity) when key in @mount_opts do
    do_mount_opt(socket, key, val)
  end

  defp mount_opt(%Socket{view: view}, key, val, arity) do
    raise ArgumentError, """
    invalid option returned from #{inspect(view)}.mount/#{arity}.

    Expected keys to be one of #{inspect(@mount_opts)}
    got: #{inspect(key)}: #{inspect(val)}
    """
  end

  defp do_mount_opt(socket, :layout, {mod, template}) when is_atom(mod) and is_binary(template) do
    %Socket{socket | private: Map.put(socket.private, :phoenix_live_layout, {mod, template})}
  end

  defp do_mount_opt(socket, :layout, false) do
    %Socket{socket | private: Map.put(socket.private, :phoenix_live_layout, false)}
  end

  defp do_mount_opt(_socket, :layout, bad_layout) do
    raise ArgumentError,
          "the :layout mount option expects a tuple of the form {MyLayoutView, \"my_template.html\"}, " <>
            "got: #{inspect(bad_layout)}"
  end

  defp do_mount_opt(socket, :temporary_assigns, temp_assigns) do
    unless Keyword.keyword?(temp_assigns) do
      raise "the :temporary_assigns mount option must be keyword list"
    end

    temp_assigns = Map.new(temp_assigns)

    %Socket{
      socket
      | assigns: Map.merge(temp_assigns, socket.assigns),
        private: Map.put(socket.private, :temporary_assigns, temp_assigns)
    }
  end

  defp drop_private(%Socket{private: private} = socket, keys) do
    %Socket{socket | private: Map.drop(private, keys)}
  end

  defp render_assigns(%{assigns: assigns, changed: changed} = socket) do
    socket = %Socket{socket | assigns: %Socket.AssignsNotInSocket{__assigns__: assigns}}

    assigns
    |> Map.put(:socket, socket)
    |> Map.put(:__changed__, changed)
  end

  defp layout(socket, view) do
    case socket.private do
      %{phoenix_live_layout: layout} -> layout
      %{} -> view.__live__()[:layout] || false
    end
  end

  defp flash_salt(endpoint_mod) when is_atom(endpoint_mod) do
    "flash:" <> salt!(endpoint_mod)
  end
end
