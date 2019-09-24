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
  rescue
    # Normalize exceptions for better client debugging
    e -> reraise(e, __STACKTRACE__)
  end

  def handle_info({:DOWN, _, _, transport_pid, reason}, %{transport_pid: transport_pid} = state) do
    reason = if reason == :normal, do: {:shutdown, :closed}, else: reason
    {:stop, reason, state}
  end

  def handle_info({:DOWN, _, _, parent, reason}, %{socket: %{parent_pid: parent}} = state) do
    send(state.transport_pid, {:socket_close, self(), reason})
    {:stop, reason, state}
  end

  def handle_info(%Message{topic: topic, event: "phx_leave"} = msg, %{topic: topic} = state) do
    reply(state, msg.ref, :ok, %{})
    {:stop, {:shutdown, :left}, state}
  end

  def handle_info(%Message{topic: topic, event: "link"} = msg, %{topic: topic} = state) do
    %{router: router, socket: %{view: view}} = state
    %{"url" => url} = msg.payload

    case View.live_link_info!(router, view, url) do
      {:internal, params} ->
        new_state = %{state | uri: parse_uri(url)}

        if function_exported?(view, :handle_params, 3) do
          params
          |> new_state.socket.view.handle_params(url, new_state.socket)
          |> handle_result({:handle_params, 3, msg.ref}, new_state)
        else
          {:noreply, reply(new_state, msg.ref, :ok, %{})}
        end

      :external ->
        {:noreply, reply(state, msg.ref, :ok, %{link_redirect: true})}
    end
  end

  def handle_info(%Message{topic: topic, event: "cids_destroyed"} = msg, %{topic: topic} = state) do
    %{"cids" => _cids} = msg.payload
    # TODO
    {:noreply, state}
  end

  def handle_info(%Message{topic: topic, event: "event"} = msg, %{topic: topic} = state) do
    %{"value" => raw_val, "event" => event, "type" => type} = msg.payload
    val = decode(type, state.router, raw_val)

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

  def handle_call({@prefix, :child_mount, _child_pid, assigned_new}, _from, state) do
    assigns = Map.take(state.socket.assigns, assigned_new)
    {:reply, assigns, state}
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

  defp maybe_call_mount_handle_params(%{socket: socket} = state, url) do
    if function_exported?(socket.view, :handle_params, 3) do
      case View.live_link_info!(state.router, socket.view, url) do
        {:internal, params} ->
          params
          |> view_module(state).handle_params(url, socket)
          |> mount_handle_params_result(state, :mount)

        :external ->
          raise "cannot invoke handle_params/3 for #{inspect socket.view} " <>
                  "because #{inspect socket.view} was not declared in the router with " <>
                  "the live/3 macro under #{inspect url}"
      end
    else
      {diff, new_state} = render_diff(state, socket)
      {:ok, diff, :mount, new_state}
    end
  end

  defp mount_handle_params_result({:noreply, %Socket{} = new_socket}, state, redir) do
    new_state = %{state | socket: new_socket}

    case maybe_changed(new_state) do
      changed when changed in [:noop, :diff] ->
        {diff, new_state} = render_diff(new_state, new_socket)
        {:ok, diff, redir, new_state}

      {:redirect, %{to: _to} = opts} ->
        {:redirect, put_flash(new_state, opts), new_state}

      {:live_redirect, {:internal, params}, %{to: to} = opts} ->
        {url, new_state} = new_state |> drop_redirect() |> compute_url(to)

        params
        |> view_module(new_state).handle_params(url, new_state.socket)
        |> mount_handle_params_result(new_state, {:live_redirect, opts})

      {:live_redirect, :external, %{to: to} = opts} ->
        send(new_state.transport_pid, {:socket_close, self(), {:redirect, to}})
        {:external_live_redirect, put_flash(new_state, opts), new_state}
    end
  end

  defp mount_handle_params_result({:stop, %Socket{} = new_socket}, state, _redir) do
    case new_socket.redirected do
      {:live, _} ->
        View.raise_bad_stop_and_live_redirect!()

      {:redirect, opts} ->
        {:redirect, opts, %{state | socket: new_socket}}

      nil ->
        View.raise_bad_stop_and_no_redirect!()
    end
  end

  defp handle_result({:noreply, %Socket{} = new_socket}, {_from, _arity, ref}, state) do
    case handle_changed(state, new_socket, ref) do
      {:ok, _changed, new_state} -> {:noreply, new_state}
      {:stop, reason, new_state} -> {:stop, reason, new_state}
    end
  end

  defp handle_result({:stop, %Socket{redirected: nil}}, {_, _, _}, _) do
    View.raise_bad_stop_and_no_redirect!()
  end

  defp handle_result({:stop, %Socket{redirected: {:live, _}}}, {_, _, _}, _) do
    View.raise_bad_stop_and_live_redirect!()
  end

  defp handle_result({:stop, %Socket{} = new_socket}, {_, _, ref}, state) do
    case handle_changed(state, new_socket, ref) do
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

    case maybe_changed(new_state) do
      :diff ->
        {diff, new_state} = render_diff(new_state, new_socket)

        {:ok, :diff,
         new_state
         |> push_internal_live_redirect(pending_internal_live_redirect)
         |> push_render(diff, ref)}

      :noop ->
        {:ok, :noop,
         new_state
         |> push_internal_live_redirect(pending_internal_live_redirect)
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
    {url, new_state} = compute_url(state, to)

    case view_module(new_state).handle_params(params, url, new_state.socket) do
      {:noreply, %Socket{} = new_socket} ->
        handle_changed(new_state, new_socket, ref, opts)

      {:stop, %Socket{redirected: {:live, _}}} ->
        View.raise_bad_stop_and_live_redirect!()

      {:stop, %Socket{} = new_socket} ->
        case handle_changed(new_state, new_socket, ref, opts) do
          {:ok, _changed, new_state} -> {:stop, :shutdown, new_state}
          {:stop, reason, new_state} -> {:stop, reason, new_state}
        end
    end
  end

  defp push_internal_live_redirect(state, nil), do: state

  defp push_internal_live_redirect(state, %{to: to, kind: kind}) do
    push(state, "live_redirect", %{to: to, kind: kind})
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

  defp maybe_changed(%{socket: socket} = state) do
    # For now, we only track content changes.
    # But in the future, we may want to sync other properties.
    case socket.redirected do
      {:live, %{to: to} = opts} ->
        {:live_redirect, View.live_link_info!(state.router, socket.view, to), opts}

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

  defp render_diff(state, %{fingerprints: prints} = socket) do
    rendered = View.dynamic_render(socket, view_module(state))
    {diff, new_prints} = Diff.render(rendered, prints)
    socket = View.clear_changed(%{socket | fingerprints: new_prints})
    {diff, %{state | socket: socket}}
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
      {:ok, verified} ->
        verified_mount(verified, params, from, phx_socket)

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
    GenServer.reply(from, {:error, %{reason: "nosession"}})
    {:stop, :shutdown, :no_session}
  end

  defp verified_mount(verified, params, from, phx_socket) do
    %{
       id: id,
       view: view,
       parent_pid: parent,
       root_pid: root,
       session: session,
       assigned_new: assigned_new
    } = verified

    %Phoenix.Socket{endpoint: endpoint} = phx_socket
    Process.monitor(phx_socket.transport_pid)
    parent_assigns = sync_with_parent(parent, assigned_new)
    %{"url" => url, "params" => connect_params} = params

    with %{"caller" => {pid, _}} when is_pid(pid) <- params do
      Process.put(:"$callers", [pid])
    end

    %Socket{
      endpoint: endpoint,
      view: view,
      connected?: true,
      parent_pid: parent,
      root_pid: root || self(),
      id: id
    }
    |> View.configure_socket(%{
      connect_params: connect_params,
      assigned_new: {parent_assigns, assigned_new}
    })
    |> View.call_mount!(view, session)
    |> build_state(phx_socket, verified[:router], url)
    |> maybe_call_mount_handle_params(url)
    |> reply_mount(from)
  end

  defp reply_mount(result, from) do
    case result do
      {:ok, diff, :mount, new_state} ->
        GenServer.reply(from, {:ok, %{rendered: diff}})
        {:noreply, post_mount_prune(new_state)}

      {:ok, diff, {:live_redirect, opts}, new_state} ->
        GenServer.reply(from, {:ok, %{rendered: diff, live_redirect: opts}})
        {:noreply, post_mount_prune(new_state)}

      {:external_live_redirect, opts, new_state} ->
        GenServer.reply(from, {:error, %{external_live_redirect: opts}})
        {:stop, :shutdown, new_state}

      {:redirect, opts, new_state} ->
        GenServer.reply(from, {:error, %{redirect: opts}})
        {:stop, :shutdown, new_state}
    end
  end

  defp build_state(%Socket{} = lv_socket, %Phoenix.Socket{} = phx_socket, router, url) do
    %{
      # There is no need to keep the uri if we don't have a router
      uri: router && parse_uri(url),
      router: router,
      join_ref: phx_socket.join_ref,
      serializer: phx_socket.serializer,
      socket: lv_socket,
      topic: phx_socket.topic,
      transport_pid: phx_socket.transport_pid
    }
  end

  defp sync_with_parent(nil, _assigned_new), do: %{}

  defp sync_with_parent(parent, assigned_new) do
    _ref = Process.monitor(parent)
    GenServer.call(parent, {@prefix, :child_mount, self(), assigned_new})
  end

  defp put_flash(%{socket: socket}, opts) do
    Map.put(opts, :flash, View.sign_flash(socket, View.get_flash(socket)))
  end

  defp parse_uri(url) do
    %URI{host: host, port: port, scheme: scheme} = URI.parse(url)
    %URI{host: host, port: port, scheme: scheme}
  end

  defp compute_url(state, "http://" <> _ = url), do: {url, %{state | uri: parse_uri(url)}}
  defp compute_url(state, "https://" <> _ = url), do: {url, %{state | uri: parse_uri(url)}}
  defp compute_url(%{uri: uri} = state, to), do: {URI.to_string(%{uri | path: to}), state}

  defp post_mount_prune(%{socket: socket} = state) do
    %{state | socket: View.post_mount_prune(socket)}
  end
end
