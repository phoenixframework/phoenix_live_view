defmodule Phoenix.LiveView.Channel do
  @moduledoc false
  use GenServer, restart: :temporary

  require Logger

  alias Phoenix.LiveView.{Socket, Utils, Diff, Static}
  alias Phoenix.Socket.Message

  @prefix :phoenix

  def start_link({auth_payload, from, phx_socket}) do
    hibernate_after = phx_socket.endpoint.config(:live_view)[:hibernate_after] || 15000
    opts = [hibernate_after: hibernate_after]
    GenServer.start_link(__MODULE__, {auth_payload, from, phx_socket}, opts)
  end

  def send_update(module, id, assigns) do
    send(self(), {@prefix, :send_update, {module, id, assigns}})
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
    %{socket: socket} = state
    %{view: view, router: router} = socket
    %{"url" => url} = msg.payload

    case Utils.live_link_info!(router, view, url) do
      {:internal, params, action, _} ->
        socket = socket |> assign_action(action) |> Utils.clear_flash()

        params
        |> view.handle_params(url, socket)
        |> handle_result({:handle_params, 3, msg.ref}, state)

      :external ->
        {:noreply, reply(state, msg.ref, :ok, %{link_redirect: true})}
    end
  end

  def handle_info(%Message{topic: topic, event: "cids_destroyed"} = msg, %{topic: topic} = state) do
    %{"cids" => cids} = msg.payload

    new_components =
      Enum.reduce(cids, state.components, fn cid, acc -> Diff.delete_component(cid, acc) end)

    {:noreply, reply(%{state | components: new_components}, msg.ref, :ok, %{})}
  end

  def handle_info(%Message{topic: topic, event: "event"} = msg, %{topic: topic} = state) do
    %{"value" => raw_val, "event" => event, "type" => type} = msg.payload
    val = decode_event_type(type, raw_val)

    case Map.fetch(msg.payload, "cid") do
      {:ok, cid} ->
        component_handle_event(state, cid, event, val, msg.ref)

      :error ->
        state.socket
        |> view_handle_event(event, val)
        |> handle_result({:handle_event, 3, msg.ref}, state)
    end
  end

  def handle_info({@prefix, :send_update, update}, state) do
    case Diff.update_component(state.socket, state.components, update) do
      {diff, new_components} ->
        {:noreply, push_render(%{state | components: new_components}, diff, nil)}

      :noop ->
        {:noreply, state}
    end
  end

  def handle_info({@prefix, :redirect, command, flash}, state) do
    handle_redirect(state, command, flash, nil)
  end

  def handle_info(msg, %{socket: socket} = state) do
    msg
    |> socket.view.handle_info(socket)
    |> handle_result({:handle_info, 2, nil}, state)
  end

  @impl true
  def handle_call({@prefix, :ping}, _from, state) do
    {:reply, :ok, state}
  end

  def handle_call({@prefix, :child_mount, _child_pid, assign_new}, _from, state) do
    assigns = Map.take(state.socket.assigns, assign_new)
    {:reply, assigns, state}
  end

  def handle_call(msg, from, %{socket: socket} = state) do
    case socket.view.handle_call(msg, from, socket) do
      {:reply, reply, %Socket{} = new_socket} ->
        case handle_changed(state, new_socket, nil) do
          {:noreply, new_state} -> {:reply, reply, new_state}
          {:stop, reason, new_state} -> {:stop, reason, reply, new_state}
        end

      {:noreply, %Socket{} = new_socket} ->
        handle_changed(state, new_socket, nil)

      other ->
        handle_result(other, {:handle_call, 3, nil}, state)
    end
  end

  @impl true
  def handle_cast(msg, %{socket: socket} = state) do
    msg
    |> socket.view.handle_cast(socket)
    |> handle_result({:handle_cast, 2, nil}, state)
  end

  @impl true
  def terminate(reason, %{socket: socket}) do
    %{view: view} = socket

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
    %{view: view} = socket

    if function_exported?(view, :code_change, 3) do
      view.code_change(old, socket, extra)
    else
      {:ok, state}
    end
  end

  defp view_handle_event(%Socket{} = socket, "lv:clear-flash", val) do
    case val do
      %{"key" => key} -> {:noreply, Utils.clear_flash(socket, key)}
      _ -> {:noreply, Utils.clear_flash(socket)}
    end
  end

  defp view_handle_event(%Socket{}, "lv:" <> _ = bad_event, _val) do
    raise ArgumentError, """
    received unknown LiveView event #{inspect(bad_event)}.
    The following LiveView events are suppported: lv:clear-flash.
    """
  end

  defp view_handle_event(%Socket{} = socket, event, val) do
    socket.view.handle_event(event, val, socket)
  end

  defp maybe_call_mount_handle_params(%{socket: socket} = state, router, url, params) do
    %{view: view, redirected: mount_redirect} = socket

    cond do
      mount_redirect ->
        mount_handle_params_result({:noreply, socket}, state, :mount)

      not function_exported?(view, :handle_params, 3) ->
        {diff, new_state} = render_diff(state, socket)
        {:ok, diff, :mount, new_state}

      socket.root_pid != self() or is_nil(router) ->
        # Let the callback fail for the usual reasons
        Utils.live_link_info!(nil, view, url)

      params == :not_mounted_at_router ->
        raise "cannot invoke handle_params/3 for #{inspect(view)} because #{inspect(view)}" <>
                " was not mounted at the router with the live/3 macro under URL #{inspect(url)}"

      true ->
        params
        |> view.handle_params(url, socket)
        |> mount_handle_params_result(state, :mount)
    end
  end

  defp mount_handle_params_result({:noreply, %Socket{} = new_socket}, state, redir) do
    new_state = %{state | socket: new_socket}

    case maybe_changed(new_state) do
      changed when changed in [:noop, :diff] ->
        {diff, new_state} = render_diff(new_state, new_socket)
        {:ok, diff, redir, new_state}

      {:redirect, %{to: _to} = opts} ->
        {:redirect, copy_flash(new_state, Utils.get_flash(new_socket), opts), new_state}

      {:live, :redirect, %{to: to} = opts} ->
        send(new_state.transport_pid, {:socket_close, self(), {:redirect, to}})
        {:live_redirect, copy_flash(new_state, Utils.get_flash(new_socket), opts), new_state}

      {:live, {params, action}, %{to: to} = opts} ->
        %{socket: new_socket} = new_state = drop_redirect(new_state)
        uri = build_uri(new_state, to)

        params
        |> new_socket.view.handle_params(uri, assign_action(new_socket, action))
        |> mount_handle_params_result(new_state, {:live_patch, opts})
    end
  end

  defp handle_result({:noreply, %Socket{} = new_socket}, {_from, _arity, ref}, state) do
    handle_changed(state, new_socket, ref)
  end

  defp handle_result(result, {:handle_call, 3, _ref}, state) do
    raise ArgumentError, """
    invalid noreply from #{inspect(state.socket.view)}.handle_call/3 callback.

    Expected one of:

        {:noreply, %Socket{}}
        {:reply, reply, %Socket}

    Got: #{inspect(result)}
    """
  end

  defp handle_result(result, {name, arity, _ref}, state) do
    raise ArgumentError, """
    invalid noreply from #{inspect(state.socket.view)}.#{name}/#{arity} callback.

    Expected one of:

        {:noreply, %Socket{}}

    Got: #{inspect(result)}
    """
  end

  defp component_handle_event(state, cid, event, val, ref) do
    %{socket: socket, components: components} = state

    result =
      Diff.with_component(socket, cid, %{}, components, fn component_socket, component ->
        case component.handle_event(event, val, component_socket) do
          {:noreply, %Socket{redirected: redirected, assigns: assigns} = component_socket} ->
            {component_socket, {redirected, assigns.flash}}

          other ->
            raise ArgumentError, """
            invalid return from #{inspect(component)}.handle_event/3 callback.

            Expected: {:noreply, %Socket{}}
            Got: #{inspect(other)}
            """
        end
      end)

    # Due to race conditions, the browser can send a request for a
    # component ID that no longer exists. So we need to check for
    # the :error case accordingly.
    case result do
      {diff, new_components, {redirected, flash}} ->
        new_state = %{state | components: new_components}

        if redirected do
          handle_redirect(new_state, redirected, flash, nil, {diff, ref})
        else
          {:noreply, push_render(new_state, diff, ref)}
        end

      :error ->
        {:noreply, push_noop(state, ref)}
    end
  end

  defp decode_event_type("form", url_encoded) do
    url_encoded
    |> Plug.Conn.Query.decode()
    |> decode_merge_target()
  end

  defp decode_event_type(_, value), do: value

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

  defp handle_changed(state, %Socket{} = new_socket, ref, pending_live_patch \\ nil) do
    new_state = %{state | socket: new_socket}

    case maybe_changed(new_state) do
      :diff ->
        {diff, new_state} = render_diff(new_state, new_socket)

        {:noreply,
         new_state
         |> push_live_patch(pending_live_patch)
         |> push_render(diff, ref)}

      :noop ->
        {:noreply,
         new_state
         |> push_live_patch(pending_live_patch)
         |> push_noop(ref)}

      result ->
        handle_redirect(new_state, result, flash_diff(new_socket, state.socket), ref)
    end
  end

  defp maybe_push_pending_diff_ack(state, nil), do: state
  defp maybe_push_pending_diff_ack(state, {diff, ref}), do: push_render(state, diff, ref)

  defp handle_redirect(new_state, result, flash, ref, pending_diff_ack \\ nil) do
    %{socket: new_socket} = new_state
    root_pid = new_socket.root_pid

    case result do
      {:redirect, %{to: to} = opts} ->
        new_state
        |> push_redirect(flash, opts, ref)
        |> stop_shutdown_redirect(to)

      {:live, :redirect, %{to: to} = opts} ->
        new_state
        |> push_live_redirect(flash, opts, ref)
        |> stop_shutdown_redirect(to)

      {:live, {params, action}, %{to: _to, kind: _kind} = opts} when root_pid == self() ->
        new_state
        |> drop_redirect()
        |> maybe_push_pending_diff_ack(pending_diff_ack)
        |> Map.update!(:socket, &Utils.replace_flash(&1, flash))
        |> sync_handle_params_with_live_redirect(params, action, opts, ref)

      {:live, {_params, _action}, %{to: _to, kind: _kind}} = patch ->
        send(new_socket.root_pid, {@prefix, :redirect, patch, flash})
        {diff, new_state} = render_diff(new_state, new_socket)

        {:noreply,
         new_state
         |> drop_redirect()
         |> maybe_push_pending_diff_ack(pending_diff_ack)
         |> push_render(diff, ref)}
    end
  end

  defp stop_shutdown_redirect(state, to) do
    send(state.transport_pid, {:socket_close, self(), {:redirect, to}})
    {:stop, {:shutdown, {:redirect, to}}, state}
  end

  defp drop_redirect(state) do
    put_in(state.socket.redirected, nil)
  end

  defp sync_handle_params_with_live_redirect(state, params, action, %{to: to} = opts, ref) do
    %{socket: socket} = state

    case socket.view.handle_params(params, build_uri(state, to), assign_action(socket, action)) do
      {:noreply, %Socket{} = new_socket} ->
        handle_changed(state, new_socket, ref, opts)

      other ->
        raise ArgumentError, """
        invalid return from #{inspect(socket.view)}.handle_params/3 callback.

        Expected one of:

            {:noreply, %Socket{}}

        Got: #{inspect(other)}
        """
    end
  end

  defp push_live_patch(state, nil), do: state

  defp push_live_patch(state, opts) do
    push(state, "live_patch", opts)
  end

  defp push_redirect(state, flash, opts, nil = _ref) do
    push(state, "redirect", copy_flash(state, flash, opts))
  end

  defp push_redirect(state, flash, opts, ref) do
    reply(state, ref, :ok, %{redirect: copy_flash(state, flash, opts)})
  end

  defp push_live_redirect(state, flash, opts, nil = _ref) do
    push(state, "live_redirect", copy_flash(state, flash, opts))
  end

  defp push_live_redirect(state, flash, opts, ref) do
    reply(state, ref, :ok, %{live_redirect: copy_flash(state, flash, opts)})
  end

  defp push_noop(state, nil = _ref), do: state
  defp push_noop(state, ref), do: reply(state, ref, :ok, %{})

  defp push_render(state, diff, ref) when diff == %{} do
    push_noop(state, ref)
  end

  defp push_render(state, diff, nil = _ref), do: push(state, "diff", diff)
  defp push_render(state, diff, ref), do: reply(state, ref, :ok, %{diff: diff})

  defp flash_diff(new_socket, old_socket) do
    Enum.reduce(Utils.get_flash(old_socket), Utils.get_flash(new_socket), fn {k, _}, acc ->
      Map.delete(acc, k)
    end)
  end

  defp copy_flash(_state, flash, opts) when flash == %{},
    do: opts

  defp copy_flash(state, flash, opts),
    do: Map.put(opts, :flash, Utils.sign_flash(state.socket.endpoint, flash))

  defp maybe_changed(%{socket: socket}) do
    socket.redirected ||
      if Utils.changed?(socket) do
        :diff
      else
        :noop
      end
  end

  defp render_diff(%{components: components} = state, socket) do
    rendered = Utils.to_rendered(socket, socket.view)
    {socket, diff, new_components} = Diff.render(socket, rendered, components)
    {diff, %{state | socket: Utils.clear_changed(socket), components: new_components}}
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
    case Static.verify_session(phx_socket.endpoint, session_token, params["static"]) do
      {:ok, verified} ->
        verified_mount(verified, params, from, phx_socket)

      {:error, reason} when reason in [:outdated, :expired] ->
        GenServer.reply(from, {:error, %{reason: "outdated"}})
        {:stop, :shutdown, :no_state}

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

  defp verify_flash(endpoint, verified, params) do
    flash_token = params["flash"]
    verified_flash = verified[:flash]

    # verified_flash is fetched from the disconnected render.
    # params["flash"] is sent on live redirects and therefore has higher priority.
    cond do
      flash_token -> Utils.verify_flash(endpoint, flash_token)
      params["joins"] == 0 && verified_flash -> verified_flash
      true -> %{}
    end
  end

  defp verified_mount(verified, params, from, phx_socket) do
    %{
      id: id,
      view: view,
      root_view: root_view,
      parent_pid: parent,
      root_pid: root,
      session: session,
      assign_new: assign_new
    } = verified

    # Optional verified parts
    router = verified[:router]

    %Phoenix.Socket{
      endpoint: endpoint,
      private: %{session: socket_session},
      transport_pid: transport_pid
    } = phx_socket

    flash = verify_flash(endpoint, verified, params)

    Process.monitor(transport_pid)
    load_csrf_token(endpoint, socket_session)

    # Optional parameter handling
    url = params["url"]
    connect_params = params["params"]

    case params do
      %{"caller" => {pid, _}} when is_pid(pid) -> Process.put(:"$callers", [pid])
      _ -> Process.put(:"$callers", [transport_pid])
    end

    {params, parsed_uri, action} =
      case router && url && Utils.live_link_info!(router, view, url) do
        {:internal, params, action, parsed_uri} -> {params, parsed_uri, action}
        _ -> {:not_mounted_at_router, :not_mounted_at_router, nil}
      end

    socket =
      Utils.configure_socket(
        %Socket{
          endpoint: endpoint,
          view: view,
          root_view: root_view,
          connected?: true,
          parent_pid: parent,
          root_pid: root || self(),
          id: id,
          router: router
        },
        mount_private(parent, assign_new, connect_params),
        action,
        flash
      )

    socket
    |> Utils.maybe_call_mount!(view, [params, Map.merge(socket_session, session), socket])
    |> build_state(phx_socket, parsed_uri)
    |> maybe_call_mount_handle_params(router, url, params)
    |> reply_mount(from)
  end

  defp load_csrf_token(endpoint, socket_session) do
    if token = socket_session["_csrf_token"] do
      state = Plug.CSRFProtection.dump_state_from_session(token)
      secret_key_base = endpoint.config(:secret_key_base)
      Plug.CSRFProtection.load_state(secret_key_base, state)
    end
  end

  defp mount_private(nil, assign_new, connect_params) do
    %{
      connect_params: connect_params,
      assign_new: {%{}, assign_new}
    }
  end

  defp mount_private(parent, assign_new, connect_params) do
    parent_assigns = sync_with_parent(parent, assign_new)

    # Child live views always ignore the layout on `:use`.
    %{
      connect_params: connect_params,
      assign_new: {parent_assigns, assign_new},
      phoenix_live_layout: false
    }
  end

  defp sync_with_parent(parent, assign_new) do
    _ref = Process.monitor(parent)
    GenServer.call(parent, {@prefix, :child_mount, self(), assign_new})
  end

  defp reply_mount(result, from) do
    case result do
      {:ok, diff, :mount, new_state} ->
        GenServer.reply(from, {:ok, %{rendered: diff}})
        {:noreply, post_mount_prune(new_state)}

      {:ok, diff, {:live_patch, opts}, new_state} ->
        GenServer.reply(from, {:ok, %{rendered: diff, live_patch: opts}})
        {:noreply, post_mount_prune(new_state)}

      {:live_redirect, opts, new_state} ->
        GenServer.reply(from, {:error, %{live_redirect: opts}})
        {:stop, :shutdown, new_state}

      {:redirect, opts, new_state} ->
        GenServer.reply(from, {:error, %{redirect: opts}})
        {:stop, :shutdown, new_state}
    end
  end

  defp build_state(%Socket{} = lv_socket, %Phoenix.Socket{} = phx_socket, parsed_uri) do
    %{
      uri: prune_uri(parsed_uri),
      join_ref: phx_socket.join_ref,
      serializer: phx_socket.serializer,
      socket: lv_socket,
      topic: phx_socket.topic,
      transport_pid: phx_socket.transport_pid,
      components: Diff.new_components()
    }
  end

  defp prune_uri(:not_mounted_at_router), do: :not_mounted_at_router

  defp prune_uri(url) do
    %URI{host: host, port: port, scheme: scheme} = url

    if host == nil do
      raise "client did not send full URL, missing host in #{url}"
    end

    %URI{host: host, port: port, scheme: scheme}
  end

  defp build_uri(%{uri: uri}, "/" <> _ = to) do
    URI.to_string(%{uri | path: to})
  end

  defp post_mount_prune(%{socket: socket} = state) do
    %{state | socket: Utils.post_mount_prune(socket)}
  end

  defp assign_action(socket, action) do
    Phoenix.LiveView.assign(socket, :live_action, action)
  end
end
