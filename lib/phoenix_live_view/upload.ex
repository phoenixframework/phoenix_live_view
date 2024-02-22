defmodule Phoenix.LiveView.Upload do
  # Operations integrating Phoenix.LiveView.Socket with UploadConfig.
  @moduledoc false

  alias Phoenix.LiveView.{Socket, Utils, UploadConfig, UploadEntry}

  @refs_to_names :__phoenix_refs_to_names__

  @doc """
  Allows an upload.
  """
  def allow_upload(%Socket{} = socket, name, opts)
      when (is_atom(name) or is_binary(name)) and is_list(opts) do
    case uploaded_entries(socket, name) do
      {[], []} ->
        :ok

      {_, _} ->
        raise ArgumentError, """
        cannot allow_upload on an existing upload with active entries.

        Use cancel_upload and/or consume_upload to handle the active entries before allowing a new upload.
        """
    end

    ref = Utils.random_id()
    uploads = socket.assigns[:uploads] || %{}
    upload_config = UploadConfig.build(name, ref, opts)

    new_uploads =
      uploads
      |> Map.put(name, upload_config)
      |> Map.update(@refs_to_names, %{ref => name}, fn refs -> Map.put(refs, ref, name) end)

    Utils.assign(socket, :uploads, new_uploads)
  end

  @doc """
  Disallows a previously allowed upload.
  """
  def disallow_upload(%Socket{} = socket, name) when is_atom(name) or is_binary(name) do
    case uploaded_entries(socket, name) do
      {[], []} ->
        uploads = socket.assigns[:uploads] || %{}

        upload_config =
          uploads
          |> Map.fetch!(name)
          |> UploadConfig.disallow()

        new_refs =
          Enum.reduce(uploads[@refs_to_names], uploads[@refs_to_names], fn
            {ref, ^name}, acc -> Map.delete(acc, ref)
            {_ref, _name}, acc -> acc
          end)

        new_uploads =
          uploads
          |> Map.put(name, upload_config)
          |> Map.update!(@refs_to_names, fn _ -> new_refs end)

        Utils.assign(socket, :uploads, new_uploads)

      {_completed, _inprogress} ->
        raise RuntimeError, "unable to disallow_upload for an upload with active entries"
    end
  end

  @doc """
  Cancels an upload entry.
  """
  def cancel_upload(socket, name, entry_ref) do
    upload_config = Map.fetch!(socket.assigns[:uploads] || %{}, name)

    case UploadConfig.get_entry_by_ref(upload_config, entry_ref) do
      %UploadEntry{} = entry ->
        upload_config
        |> UploadConfig.cancel_entry(entry)
        |> update_uploads(socket)

      _ ->
        raise ArgumentError, "no entry in upload \"#{inspect(name)}\" with ref \"#{entry_ref}\""
    end
  end

  @doc """
  Cancels all uploads that exist.

  Returns the new socket with the cancelled upload configs.
  """
  def maybe_cancel_uploads(socket) do
    uploads = socket.assigns[:uploads] || %{}

    uploads
    |> Map.delete(@refs_to_names)
    |> Enum.reduce({socket, []}, fn {name, conf}, {socket_acc, conf_acc} ->
      new_socket =
        Enum.reduce(conf.entries, socket_acc, fn entry, inner_acc ->
          cancel_upload(inner_acc, name, entry.ref)
        end)

      {new_socket, [conf | conf_acc]}
    end)
  end

  @doc """
  Updates the entry metadata.
  """
  def update_upload_entry_meta(%Socket{} = socket, upload_conf_name, %UploadEntry{} = entry, meta) do
    socket.assigns.uploads
    |> Map.fetch!(upload_conf_name)
    |> UploadConfig.update_entry_meta(entry.ref, meta)
    |> update_uploads(socket)
  end

  @doc """
  Updates the entry progress.

  Progress is either an integer percently between 0 and 100, or a map
  with an `"error"` key containing the information for a failed upload
  while in progress on the client.
  """
  def update_progress(%Socket{} = socket, config_ref, entry_ref, progress)
      when is_integer(progress) and progress >= 0 and progress <= 100 do
    socket
    |> get_upload_by_ref!(config_ref)
    |> UploadConfig.update_progress(entry_ref, progress)
    |> update_uploads(socket)
  end

  def update_progress(%Socket{} = socket, config_ref, entry_ref, %{"error" => reason})
      when is_binary(reason) do
    conf = get_upload_by_ref!(socket, config_ref)

    if conf.external do
      put_upload_error(socket, conf.name, entry_ref, :external_client_failure)
    else
      socket
    end
  end

  @doc """
  Puts the entries into the `%UploadConfig{}`.
  """
  def put_entries(%Socket{} = socket, %UploadConfig{} = conf, entries, cid) do
    case UploadConfig.put_entries(%UploadConfig{conf | cid: cid}, entries) do
      {:ok, new_config} ->
        {:ok, update_uploads(new_config, socket)}

      {:error, new_config} ->
        errors_resp = Enum.map(new_config.errors, fn {ref, msg} -> [ref, msg] end)
        {:error, %{ref: conf.ref, error: errors_resp}, update_uploads(new_config, socket)}
    end
  end

  @doc """
  Unregisters a completed entry from an `Phoenix.LiveView.UploadChannel` process.
  """
  def unregister_completed_entry_upload(%Socket{} = socket, %UploadConfig{} = conf, entry_ref) do
    conf
    |> UploadConfig.unregister_completed_entry(entry_ref)
    |> update_uploads(socket)
  end

  @doc """
  Registers a new entry upload for an `Phoenix.LiveView.UploadChannel` process.
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
  Populates the errors for a given entry.
  """
  def put_upload_error(%Socket{} = socket, conf_name, entry_ref, reason) do
    conf = Map.fetch!(socket.assigns.uploads, conf_name)

    conf
    |> UploadConfig.put_error(entry_ref, reason)
    |> update_uploads(socket)
  end

  @doc """
  Retrieves the `%UploadConfig{}` from the socket for the provided ref or raises.
  """
  def get_upload_by_ref!(%Socket{} = socket, config_ref) do
    uploads = socket.assigns[:uploads] || raise(ArgumentError, no_upload_allowed_message(socket))
    name = Map.fetch!(uploads[@refs_to_names], config_ref)
    Map.fetch!(uploads, name)
  end

  defp no_upload_allowed_message(socket) do
    "no uploads have been allowed on " <>
      if(socket.assigns[:myself], do: "component running inside ", else: "") <>
      "LiveView named #{inspect(socket.view)}"
  end

  @doc """
  Returns the `%UploadConfig{}` from the socket for the `Phoenix.LiveView.UploadChannel` pid.
  """
  def get_upload_by_pid(socket, pid) when is_pid(pid) do
    Enum.find_value(socket.assigns[:uploads] || %{}, fn
      {@refs_to_names, _} -> false
      {_name, %UploadConfig{} = conf} -> UploadConfig.get_entry_by_pid(conf, pid) && conf
    end)
  end

  @doc """
  Returns the completed and in progress entries for the upload.
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
  Consumes the uploaded entries or raises if entries are still in progress.
  """
  def consume_uploaded_entries(%Socket{} = socket, name, func) when is_function(func, 2) do
    conf =
      socket.assigns[:uploads][name] ||
        raise ArgumentError, "no upload allowed for #{inspect(name)}"

    case uploaded_entries(socket, name) do
      {[_ | _] = done_entries, []} ->
        consume_entries(conf, done_entries, func)

      {_, [_ | _]} ->
        raise ArgumentError, "cannot consume uploaded files when entries are still in progress"

      {[], []} ->
        []
    end
  end

  @doc """
  Consumes an individual entry or raises if it is still in progress.
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
  Drops all entries from the upload.
  """
  def drop_upload_entries(%Socket{} = socket, %UploadConfig{} = conf, entry_refs) do
    conf.entries
    |> Enum.filter(fn entry -> entry.ref in entry_refs end)
    |> Enum.reduce(conf, fn entry, acc -> UploadConfig.drop_entry(acc, entry) end)
    |> update_uploads(socket)
  end

  defp update_uploads(%UploadConfig{} = new_conf, %Socket{} = socket) do
    new_uploads = Map.update!(socket.assigns.uploads, new_conf.name, fn _ -> new_conf end)
    Utils.assign(socket, :uploads, new_uploads)
  end

  defp consume_entries(%UploadConfig{} = conf, entries, func)
       when is_list(entries) and is_function(func) do
    if conf.external do
      results =
        entries
        |> Enum.map(fn entry ->
          meta = Map.fetch!(conf.entry_refs_to_metas, entry.ref)

          result =
            cond do
              is_function(func, 1) -> func.(meta)
              is_function(func, 2) -> func.(meta, entry)
            end

          case result do
            {:ok, return} ->
              {entry.ref, return}

            {:postpone, return} ->
              {:postpone, return}

            return ->
              IO.warn("""
              consuming uploads requires a return signature matching:

                  {:ok, value} | {:postpone, value}

              got:

                  #{inspect(return)}
              """)

              {entry.ref, return}
          end
        end)

      consumed_refs =
        Enum.flat_map(results, fn
          {:postpone, _result} -> []
          {ref, _result} -> [ref]
        end)

      Phoenix.LiveView.Channel.drop_upload_entries(conf, consumed_refs)

      Enum.map(results, fn {_ref, result} -> result end)
    else
      entries
      |> Enum.map(fn entry -> {entry, UploadConfig.entry_pid(conf, entry)} end)
      |> Enum.filter(fn {_entry, pid} -> is_pid(pid) end)
      |> Enum.map(fn {entry, pid} -> Phoenix.LiveView.UploadChannel.consume(pid, entry, func) end)
    end
  end

  @doc """
  Generates a preflight response by calling the `:external` function.
  """
  def generate_preflight_response(%Socket{} = socket, name, cid, refs) do
    %UploadConfig{} = conf = Map.fetch!(socket.assigns.uploads, name)

    # don't send more than max_entries preflight responses
    refs = for {entry, i} <- Enum.with_index(conf.entries),
      entry.ref in refs,
      i < conf.max_entries && not entry.preflighted?,
      do: entry.ref

    client_meta = %{
      max_file_size: conf.max_file_size,
      max_entries: conf.max_entries,
      chunk_size: conf.chunk_size
    }

    {new_socket, new_conf, new_entries} = mark_preflighted(socket, conf, refs)

    case new_conf.external do
      false ->
        channel_preflight(new_socket, new_conf, new_entries, cid, client_meta)

      func when is_function(func) ->
        external_preflight(new_socket, new_conf, new_entries, client_meta)
    end
  end

  defp mark_preflighted(socket, conf, refs) do
    {new_conf, new_entries} = UploadConfig.mark_preflighted(conf, refs)
    new_socket = update_uploads(new_conf, socket)
    {new_socket, new_conf, new_entries}
  end

  defp channel_preflight(
         %Socket{} = socket,
         %UploadConfig{} = conf,
         entries,
         cid,
         %{} = client_config_meta
       ) do
    reply_entries =
      for entry <- entries, entry.valid?, into: %{} do
        token =
          Phoenix.LiveView.Static.sign_token(socket.endpoint, %{
            pid: self(),
            ref: {conf.ref, entry.ref},
            cid: cid
          })

        {entry.ref, token}
      end

    errors =
      for entry <- entries,
          not entry.valid?,
          into: %{},
          do: {entry.ref, entry_errors(conf, entry)}

    reply = %{ref: conf.ref, config: client_config_meta, entries: reply_entries, errors: errors}
    {:ok, reply, socket}
  end

  defp entry_errors(%UploadConfig{} = conf, %UploadEntry{} = entry) do
    for {ref, err} <- conf.errors, ref == entry.ref, do: err
  end

  defp external_preflight(%Socket{} = socket, %UploadConfig{} = conf, entries, client_config_meta) do
    reply_entries =
      Enum.reduce_while(entries, {:ok, %{}, %{}, socket}, fn entry, {:ok, metas, errors, acc} ->
        if conf.auto_upload? and not entry.valid? do
          reasons = for {ref, reason} <- conf.errors, ref == entry.ref, do: %{reason: reason}
          new_errors = Map.put(errors, entry.ref, reasons)
          {:cont, {:ok, metas, new_errors, acc}}
        else
          case conf.external.(entry, acc) do
            {:ok, %{} = meta, new_socket} ->
              new_socket = update_upload_entry_meta(new_socket, conf.name, entry, meta)
              {:cont, {:ok, Map.put(metas, entry.ref, meta), errors, new_socket}}

            {:error, %{} = meta, new_socket} ->
              if conf.auto_upload? do
                new_errors = Map.put(errors, entry.ref, [meta])
                {:cont, {:ok, metas, new_errors, new_socket}}
              else
                {:halt, {:error, {entry.ref, meta}, new_socket}}
              end
          end
        end
      end)

    case reply_entries do
      {:ok, entry_metas, errors, new_socket} ->
        reply = %{ref: conf.ref, config: client_config_meta, entries: entry_metas, errors: errors}
        {:ok, reply, new_socket}

      {:error, {entry_ref, meta_reason}, new_socket} ->
        new_socket = put_upload_error(new_socket, conf.name, entry_ref, meta_reason)
        {:error, %{ref: conf.ref, error: [[entry_ref, meta_reason]]}, new_socket}
    end
  end

  def register_cid(%Socket{} = socket, ref, cid) do
    socket
    |> get_upload_by_ref!(ref)
    |> UploadConfig.register_cid(cid)
    |> update_uploads(socket)
  end
end
