defmodule Phoenix.LiveView.Channel do
  @moduledoc false
  use GenServer, restart: :temporary

  require Logger

  alias Phoenix.LiveView.{Socket, View, Diff}
  alias Phoenix.Socket.Message

  @prefix :phoenix

  def start_link({auth_payload, from, phx_socket}) do
    GenServer.start_link(__MODULE__, {auth_payload, from, phx_socket})
  end

  def ping(pid) do
    GenServer.call(pid, {@prefix, :ping})
  end

  @impl true
  def init(triplet) do
    send(self(), {:mount, __MODULE__})
    {:ok, triplet}
  end

  @impl true
  def handle_info({:mount, __MODULE__}, triplet) do
    mount(triplet)
  end

  def handle_info({:DOWN, _, _, transport_pid, reason}, %{transport_pid: transport_pid} = state) do
    reason = if reason == :normal, do: {:shutdown, :closed}, else: reason
    {:stop, reason, state}
  end

  def handle_info({:DOWN, _, :process, parent, reason}, %{socket: %{parent_pid: parent}} = state) do
    send(state.transport_pid, {:socket_close, self(), reason})
    {:stop, reason, state}
  end

  def handle_info({:DOWN, _, :process, maybe_child_pid, _} = msg, %{socket: socket} = state) do
    case Map.fetch(state.children_pids, maybe_child_pid) do
      {:ok, id} ->
        new_pids = Map.delete(state.children_pids, maybe_child_pid)
        new_ids = Map.delete(state.children_ids, id)
        {:noreply, %{state | children_pids: new_pids, children_ids: new_ids}}

      :error ->
        msg
        |> view_module(state).handle_info(socket)
        |> handle_result({:handle_info, 2, nil}, state)
    end
  end

  def handle_info(%Message{topic: topic, event: "phx_leave"} = msg, %{topic: topic} = state) do
    reply(state, msg.ref, :ok, %{})
    {:stop, {:shutdown, :left}, state}
  end

  def handle_info(%Message{topic: topic, event: "link"} = msg, %{topic: topic} = state) do
    %{"url" => url} = msg.payload

    case View.live_link_info!(state.socket, url) do
      {:internal, params} ->
        new_state = put_uri(state, url)

        params
        |> new_state.socket.view.handle_params(url, new_state.socket)
        |> handle_result({:handle_params, 3, msg.ref}, new_state)

      :external ->
        {:noreply, reply(state, msg.ref, :ok, %{link_redirect: true})}
    end
  end

  def handle_info(%Message{topic: topic, event: "event"} = msg, %{topic: topic} = state) do
    %{"value" => raw_val, "event" => event, "type" => type} = msg.payload
    val = decode(type, state.socket.router, raw_val)

    event
    |> view_module(state).handle_event(val, state.socket)
    |> handle_result({:handle_event, 3, msg.ref}, state)
  end

  def handle_info(msg, %{socket: socket} = state) do
    msg
    |> view_module(state).handle_info(socket)
    |> handle_result({:handle_info, 2, nil}, state)
  end

  @impl true
  def handle_call({@prefix, :ping}, _from, state) do
    {:reply, :ok, state}
  end

  def handle_call({@prefix, :child_mount, child_pid, view, id, assigned_new}, _from, state) do
    assigns = Map.take(state.socket.assigns, assigned_new)
    {:reply, {:ok, assigns}, put_child(state, child_pid, view, id)}
  end

  def handle_call(msg, from, %{socket: socket} = state) do
    case view_module(state).handle_call(msg, from, socket) do
      {:reply, reply, %Socket{} = new_socket} ->
        case handle_changed(state, new_socket, nil) do
          {:ok, _changed, new_state} -> {:reply, reply, new_state}
          {:stop, reason, new_state} -> {:stop, reason, reply, new_state}
        end

      other ->
        handle_result(other, {:handle_call, 3, nil}, state)
    end
  end

  @impl true
  def handle_cast(msg, %{socket: socket} = state) do
    msg
    |> view_module(state).handle_cast(socket)
    |> handle_result({:handle_cast, 2, nil}, state)
  end

  @impl true
  def terminate(reason, %{socket: socket} = state) do
    view = view_module(state)

    if function_exported?(view, :terminate, 2) do
      view.terminate(reason, socket)
    else
      :ok
    end
  end

  def terminate(_reason, _state) do
    :ok
  end

  @impl true
  def code_change(old, %{socket: socket} = state, extra) do
    view = view_module(state)

    if function_exported?(view, :code_change, 3) do
      view.code_change(old, socket, extra)
    else
      {:ok, state}
    end
  end

  defp call_mount_handle_params(state, {_kind, %{to: to}} = redir) do
    if function_exported?(state.socket.view, :handle_params, 3) do
      url = to_url(state, to)
      new_state = put_uri(state, url)

      {:internal, params} = View.live_link_info!(new_state.socket, url)

      params
      |> view_module(new_state).handle_params(url, new_state.socket)
      |> handle_mount_result(redir, new_state)
    else
      {diff, new_state} = render_diff(state, state.socket)
      {:ok, diff, redir, new_state}
    end
  end

  defp handle_mount_result({:noreply, %Socket{} = new_socket}, redir, state) do
    new_state = %{state | socket: new_socket}

    case maybe_changed(new_socket) do
      changed when changed in [:noop, :diff] ->
        {diff, new_state} = render_diff(new_state, new_socket)
        {:ok, diff, redir, new_state}

      {:redirect, %{to: _to} = opts} ->
        {:stop, {:shutdown, {:redirect, put_flash(new_state, opts)}}, new_state}

      {:live_redirect, {:internal, _params}, %{to: _to, kind: _kind} = opts} ->
        new_state
        |> drop_redirect()
        |> call_mount_handle_params({:live_redirect, opts})

      {:live_redirect, :external, %{to: to} = opts} ->
        send(new_state.transport_pid, {:socket_close, self(), {:redirect, to}})
        {:stop, {:shutdown, {:live_redirect, :external, put_flash(new_state, opts)}}, new_state}
    end
  end

  defp handle_mount_result({:stop, %Socket{} = new_socket}, _uri, state) do
    new_state = %{state | socket: new_socket}

    case maybe_changed(new_socket) do
      {:redirect, %{to: _to} = opts} ->
        {:stop, {:shutdown, {:redirect, opts}}, new_state}

      {:live_redirect, _kind, _opts} ->
        bad_stop_and_live_redirect!()
    end
  end

  defp bad_stop_and_live_redirect!() do
    raise RuntimeError, """
    attempted to live redirect while stopping.

    a LiveView cannot be stopped while issuing a live redirect to the client. \
    Use redirect/2 instead if you wish to stop and redirect.
    """
  end

  defp handle_result({:noreply, %Socket{} = new_socket}, {_from, _arity, ref}, state) do
    case handle_changed(state, new_socket, ref) do
      {:ok, _changed, new_state} -> {:noreply, new_state}
      {:stop, reason, new_state} -> {:stop, reason, new_state}
    end
  end

  defp handle_result({:stop, %Socket{} = new_socket}, {_, _, ref}, state) do
    case handle_changed(state, new_socket, ref) do
      {:ok, :live_redirect, _new_state} ->
        bad_stop_and_live_redirect!()

      {:ok, _changed, new_state} ->
        send(new_state.transport_pid, {:socket_close, self(), :shutdown})
        {:stop, :shutdown, new_state}

      {:stop, reason, new_state} ->
        {:stop, reason, new_state}
    end
  end

  defp handle_result(result, {:handle_call, 3, _ref}, state) do
    raise ArgumentError, """
    invalid noreply from #{inspect(view_module(state))}.handle_call/3 callback.

    Expected one of:

        {:noreply, %Socket{}}
        {:reply, reply, %Socket}
        {:stop, %Socket{}}

    Got: #{inspect(result)}
    """
  end

  defp handle_result(result, {name, arity, _ref}, state) do
    raise ArgumentError, """
    invalid noreply from #{inspect(view_module(state))}.#{name}/#{arity} callback.

    Expected one of:

        {:noreply, %Socket{}}
        {:stop, %Socket{}}

    Got: #{inspect(result)}
    """
  end

  defp view_module(%{socket: %Socket{view: view}}), do: view

  defp decode("form", _router, url_encoded) do
    url_encoded
    |> Plug.Conn.Query.decode()
    |> decode_merge_target()
  end

  defp decode(_, _router, value), do: value

  defp decode_merge_target(%{"_target" => target} = params) when is_list(target), do: params

  defp decode_merge_target(%{"_target" => target} = params) when is_binary(target) do
    keyspace = target |> Plug.Conn.Query.decode() |> gather_keys([])
    Map.put(params, "_target", Enum.reverse(keyspace))
  end

  defp decode_merge_target(%{} = params), do: params

  defp gather_keys(%{} = map, acc) do
    case Enum.at(map, 0) do
      {key, val} -> gather_keys(val, [key | acc])
      nil -> acc
    end
  end

  defp gather_keys([], acc), do: acc

  defp gather_keys(nil, acc), do: acc

  defp handle_changed(state, %Socket{} = new_socket, ref, pending_internal_live_redirect \\ nil) do
    new_state = %{state | socket: new_socket}

    case maybe_changed(new_socket) do
      :diff ->
        {diff, new_state} = render_diff(new_state, new_socket)

        {:ok, :diff,
         new_state
         |> push_internal_live_redirect(pending_internal_live_redirect, nil)
         |> push_render(diff, ref)}

      :noop ->
        {:ok, :noop,
         new_state
         |> push_internal_live_redirect(pending_internal_live_redirect, nil)
         |> push_noop(ref)}

      {:redirect, %{to: to} = opts} ->
        new_state = push_redirect(new_state, opts, ref)
        send(new_state.transport_pid, {:socket_close, self(), {:redirect, to}})
        {:stop, {:shutdown, {:redirect, to}}, new_state}

      {:live_redirect, {:internal, params}, %{to: _to, kind: _kind} = opts} ->
        new_state
        |> drop_redirect()
        |> sync_handle_params_with_live_redirect(params, opts, ref)

      {:live_redirect, :external, %{to: to} = opts} ->
        new_state = push_external_live_redirect(new_state, put_flash(new_state, opts), ref)
        send(new_state.transport_pid, {:socket_close, self(), {:redirect, to}})
        {:stop, {:shutdown, {:redirect, to}}, new_state}
    end
  end

  defp drop_redirect(state) do
    %{state | socket: View.drop_redirect(state.socket)}
  end

  defp sync_handle_params_with_live_redirect(state, params, %{to: to} = opts, ref) do
    url = to_url(state, to)
    new_state = put_uri(state, url)

    case new_state.socket.view.handle_params(params, url, new_state.socket) do
      {:noreply, %Socket{} = new_socket} ->
        handle_changed(new_state, new_socket, ref, opts)

      {:stop, %Socket{} = new_socket} ->
        case handle_changed(new_state, new_socket, ref, opts) do
          {:ok, _changed, new_state} -> {:stop, :shutdown, new_state}
          {:stop, reason, new_state} -> {:stop, reason, new_state}
        end
    end
  end

  defp push_internal_live_redirect(state, nil, _ref), do: state

  defp push_internal_live_redirect(state, %{to: to, kind: kind}, nil = _ref) do
    push(state, "live_redirect", %{to: to, kind: kind})
  end

  defp push_internal_live_redirect(state, %{to: to, kind: kind}, ref) do
    reply(state, ref, :ok, %{live_redirect: %{to: to, kind: kind}})
  end

  defp push_redirect(state, %{to: to}, nil = _ref) do
    flash = View.get_flash(state.socket)
    push(state, "redirect", %{to: to, flash: View.sign_flash(state.socket, flash)})
  end

  defp push_redirect(state, %{to: to}, ref) do
    flash = View.get_flash(state.socket)
    reply(state, ref, :ok, %{redirect: %{to: to, flash: View.sign_flash(state.socket, flash)}})
  end

  defp push_noop(state, nil = _ref), do: state
  defp push_noop(state, ref), do: reply(state, ref, :ok, %{})

  defp push_render(state, diff, nil = _ref), do: push(state, "diff", diff)
  defp push_render(state, diff, ref), do: reply(state, ref, :ok, %{diff: diff})

  defp push_external_live_redirect(state, %{to: _, kind: _} = opts, nil = _ref) do
    push(state, "external_live_redirect", opts)
  end

  defp push_external_live_redirect(state, %{to: _, kind: _} = opts, ref) do
    reply(state, ref, :ok, %{external_live_redirect: opts})
  end

  defp maybe_changed(%Socket{} = socket) do
    # For now, we only track content changes.
    # But in the future, we may want to sync other properties.
    case socket.redirected do
      {:live, %{to: to} = opts} ->
        {:live_redirect, View.live_link_info!(socket, to), opts}

      {:redirect, opts} ->
        {:redirect, opts}

      nil ->
        if View.changed?(socket) do
          :diff
        else
          :noop
        end
    end
  end

  defp render_diff(%{} = state, %{fingerprints: prints} = socket) do
    rendered = View.render(socket, view_module(state))
    {diff, new_prints} = Diff.render(rendered, prints)
    {diff, %{state | socket: reset_changed(socket, new_prints)}}
  end

  defp reset_changed(socket, prints) do
    socket
    |> View.clear_changed()
    |> View.put_prints(prints)
  end

  defp reply(state, ref, status, payload) do
    reply_ref = {state.transport_pid, state.serializer, state.topic, ref, state.join_ref}
    Phoenix.Channel.reply(reply_ref, {status, payload})
    state
  end

  defp push(state, event, payload) do
    message = %Message{topic: state.topic, event: event, payload: payload}
    send(state.transport_pid, state.serializer.encode!(message))
    state
  end

  ## Mount

  defp mount({%{"session" => session_token} = params, from, phx_socket}) do
    case View.verify_session(phx_socket.endpoint, session_token, params["static"]) do
      {:ok,
       %{
         id: id,
         view: view,
         parent_pid: parent,
         router: router,
         session: session,
         assigned_new: new
       }} ->
        verified_mount(view, id, parent, router, new, session, params, from, phx_socket)

      {:error, reason} ->
        Logger.error(
          "Mounting #{phx_socket.topic} failed while verifying session with: #{inspect(reason)}"
        )

        GenServer.reply(from, {:error, %{reason: "badsession"}})
        {:stop, :shutdown, :no_state}
    end
  end

  defp mount({%{}, from, phx_socket}) do
    Logger.error("Mounting #{phx_socket.topic} failed because no session was provided")
    GenServer.reply(from, %{reason: "nosession"})
    :ignore
  end

  defp verified_mount(view, id, parent, router, assigned_new, session, params, from, phx_socket) do
    %Phoenix.Socket{endpoint: endpoint} = phx_socket
    Process.monitor(phx_socket.transport_pid)
    parent_assigns = register_with_parent(parent, view, id, assigned_new)
    %{"url" => url, "params" => connect_params} = params

    lv_socket =
      View.build_socket(endpoint, router, %{
        view: view,
        connected?: true,
        parent_pid: parent,
        id: id,
        connect_params: connect_params,
        assigned_new: {parent_assigns, assigned_new}
      })

    case View.call_mount(view, session, lv_socket) do
      {:ok, %Socket{} = lv_socket} ->
        state =
          lv_socket
          |> View.prune_assigned_new()
          |> build_state(phx_socket, url)

        state
        |> call_mount_handle_params({:mount, %{to: url}})
        |> reply_mount(from, url, view)

      {:stop, %Socket{} = lv_socket} = result ->
        state = lv_socket |> View.prune_assigned_new() |> build_state(phx_socket, url)

        result
        |> handle_mount_result(url, state)
        |> reply_mount(from, url, view)

      other ->
        View.raise_invalid_mount(other, view)
    end
  end

  defp reply_mount(result, from, original_uri, view) do
    case result do
      {:ok, diff, {:mount, %{to: ^original_uri}}, new_state} ->
        GenServer.reply(from, {:ok, %{rendered: diff}})
        {:noreply, post_mount_prune(new_state)}

      {:ok, diff, {:live_redirect, opts}, new_state} ->
        GenServer.reply(from, {:ok, %{rendered: diff, live_redirect: opts}})
        {:noreply, post_mount_prune(new_state)}

      {:stop, {:shutdown, {:live_redirect, :external, opts}}, new_state} ->
        GenServer.reply(from, {:error, %{external_live_redirect: opts}})
        {:stop, :shutdown, new_state}

      {:stop, {:shutdown, {:redirect, opts}}, new_state} ->
        GenServer.reply(from, {:error, %{redirect: opts}})
        {:stop, :shutdown, new_state}

      other ->
        View.raise_invalid_mount(other, view)
    end
  end

  defp build_state(%Socket{} = lv_socket, %Phoenix.Socket{} = phx_socket, uri_str) do
    put_uri(
      %{
        socket: lv_socket,
        serializer: phx_socket.serializer,
        topic: phx_socket.topic,
        transport_pid: phx_socket.transport_pid,
        join_ref: phx_socket.join_ref,
        children_pids: %{},
        children_ids: %{},
        uri: nil
      },
      uri_str
    )
  end

  defp register_with_parent(nil, _view, _id, _assigned_new), do: %{}

  defp register_with_parent(parent, view, id, assigned_new) do
    _ref = Process.monitor(parent)

    {:ok, values} =
      GenServer.call(parent, {@prefix, :child_mount, self(), view, id, assigned_new})

    values
  end

  defp put_child(state, child_pid, view, id) do
    parent = view_module(state)

    case Map.fetch(state.children_ids, id) do
      {:ok, existing_pid} ->
        raise RuntimeError, """
        unable to start child #{inspect(view)} under duplicate name for parent #{inspect(parent)}.
        A child LiveView #{inspect(existing_pid)} is already running under the ID #{id}.

        To render multiple LiveView children of the same module, a
        child_id option must be provided per live_render call. For example:

            <%= live_render @socket, #{inspect(view)}, child_id: 1 %>
            <%= live_render @socket, #{inspect(view)}, child_id: 2 %>
        """

      :error ->
        _ref = Process.monitor(child_pid)

        %{
          state
          | children_pids: Map.put(state.children_pids, child_pid, id),
            children_ids: Map.put(state.children_ids, id, child_pid)
        }
    end
  end

  defp put_flash(%{socket: socket}, opts) do
    Map.put(opts, :flash, View.sign_flash(socket, View.get_flash(socket)))
  end

  defp put_uri(%{} = state, url) do
    %URI{host: host, port: port, scheme: scheme} = URI.parse(url)
    %{state | uri: %URI{host: host, port: port, scheme: scheme}}
  end

  defp to_url(%{} = _state, "http://" <> _ = url), do: url
  defp to_url(%{} = _state, "https://" <> _ = url), do: url

  defp to_url(%{uri: %URI{host: host, port: port, scheme: scheme}}, to) do
    to_string(%URI{host: host, port: port, scheme: scheme, path: to})
  end

  defp post_mount_prune(%{socket: socket} = state) do
    %{state | socket: View.post_mount_prune(socket)}
  end
end
