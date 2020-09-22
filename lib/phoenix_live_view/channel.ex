defmodule Phoenix.LiveView.Channel do
  @moduledoc false
  use GenServer, restart: :temporary

  require Logger

  alias Phoenix.LiveView.{Socket, Utils, Diff, Static}
  alias Phoenix.Socket.Message

  @prefix :phoenix

  def start_link({endpoint, from}) do
    hibernate_after = endpoint.config(:live_view)[:hibernate_after] || 15000
    opts = [hibernate_after: hibernate_after]
    GenServer.start_link(__MODULE__, from, opts)
  end

  def send_update(module, id, assigns) do
    send(self(), {@prefix, :send_update, {module, id, assigns}})
  end

  def send_update_after(module, id, assigns, time_in_milliseconds)
      when is_integer(time_in_milliseconds) do
    Process.send_after(
      self(),
      {@prefix, :send_update, {module, id, assigns}},
      time_in_milliseconds
    )
  end

  def ping(pid) do
    GenServer.call(pid, {@prefix, :ping}, :infinity)
  end

  @impl true
  def init({pid, _ref}) do
    {:ok, Process.monitor(pid)}
  end

  @impl true
  def handle_info({Phoenix.Channel, auth_payload, from, phx_socket}, ref) do
    Process.demonitor(ref)
    mount(auth_payload, from, phx_socket)
  rescue
    # Normalize exceptions for better client debugging
    e -> reraise(e, __STACKTRACE__)
  end

  def handle_info({:DOWN, ref, _, _, _reason}, ref) do
    {:stop, {:shutdown, :closed}, ref}
  end

  def handle_info({:DOWN, _, _, transport_pid, _reason}, %{transport_pid: transport_pid} = state) do
    {:stop, {:shutdown, :closed}, state}
  end

  def handle_info({:DOWN, _, _, parent, reason}, %{socket: %{parent_pid: parent}} = state) do
    send(state.transport_pid, {:socket_close, self(), reason})
    {:stop, {:shutdown, :parent_exited}, state}
  end

  def handle_info(%Message{topic: topic, event: "phx_leave"} = msg, %{topic: topic} = state) do
    reply(state, msg.ref, :ok, %{})
    {:stop, {:shutdown, :left}, state}
  end

  def handle_info(%Message{topic: topic, event: "link"} = msg, %{topic: topic} = state) do
    %{socket: socket} = state
    %{view: view} = socket
    %{"url" => url} = msg.payload

    case Utils.live_link_info!(socket, view, url) do
      {:internal, params, action, _} ->
        socket = socket |> assign_action(action) |> Utils.clear_flash()

        socket
        |> Utils.call_handle_params!(view, params, url)
        |> handle_result({:handle_params, 3, msg.ref}, state)

      {:external, _uri} ->
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

    if cid = msg.payload["cid"] do
      component_handle_event(state, cid, event, val, msg.ref)
    else
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
        {module, id, _} = update

        if function_exported?(module, :__info__, 1) do
          # Only a warning, because there can be race conditions where a component is removed before a `send_update` happens.
          Logger.debug(
            "send_update failed because component #{inspect(module)} with ID #{inspect(id)} does not exist or it has been removed"
          )
        else
          raise ArgumentError, "send_update failed (module #{inspect(module)} is not available)"
        end

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
    The following LiveView events are supported: lv:clear-flash.
    """
  end

  defp view_handle_event(%Socket{} = socket, event, val) do
    :telemetry.span(
      [:phoenix, :live_view, :handle_event],
      %{socket: socket, event: event, params: val},
      fn ->
        case socket.view.handle_event(event, val, socket) do
          {:noreply, %Socket{} = socket} ->
            {{:noreply, socket}, %{socket: socket, event: event, params: val}}

          {:reply, reply, %Socket{} = socket} ->
            {{:reply, reply, socket}, %{socket: socket, event: event, params: val}}

          other ->
            raise_bad_callback_response!(other, socket.view, :handle_event, 3)
        end
      end
    )
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
        Utils.live_link_info!(%{socket | router: nil}, view, url)

      params == :not_mounted_at_router ->
        raise "cannot invoke handle_params/3 for #{inspect(view)} because #{inspect(view)}" <>
                " was not mounted at the router with the live/3 macro under URL #{inspect(url)}"

      true ->
        socket
        |> Utils.call_handle_params!(view, params, url)
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

      {:redirect, %{external: url}} ->
        {:redirect, copy_flash(new_state, Utils.get_flash(new_socket), %{to: url}), new_state}

      {:live, :redirect, %{to: _to} = opts} ->
        {:live_redirect, copy_flash(new_state, Utils.get_flash(new_socket), opts), new_state}

      {:live, {params, action}, %{to: to} = opts} ->
        %{socket: new_socket} = new_state = drop_redirect(new_state)
        uri = build_uri(new_state, to)

        new_socket
        |> assign_action(action)
        |> Utils.call_handle_params!(new_socket.view, params, uri)
        |> mount_handle_params_result(new_state, {:live_patch, opts})
    end
  end

  defp handle_result(
         {:reply, %{} = reply, %Socket{} = new_socket},
         {:handle_event, 3, ref},
         state
       ) do
    handle_changed(state, Utils.put_reply(new_socket, reply), ref)
  end

  defp handle_result({:noreply, %Socket{} = new_socket}, {_from, _arity, ref}, state) do
    handle_changed(state, new_socket, ref)
  end

  defp handle_result(result, {name, arity, _ref}, state) do
    raise_bad_callback_response!(result, state.socket.view, name, arity)
  end

  defp raise_bad_callback_response!(result, view, :handle_call, 3) do
    raise ArgumentError, """
    invalid noreply from #{inspect(view)}.handle_call/3 callback.

    Expected one of:

        {:noreply, %Socket{}}
        {:reply, reply, %Socket}

    Got: #{inspect(result)}
    """
  end

  defp raise_bad_callback_response!(result, view, :handle_event, arity) do
    raise ArgumentError, """
    invalid return from #{inspect(view)}.handle_event/#{arity} callback.

    Expected one of:

        {:noreply, %Socket{}}
        {:reply, map, %Socket{}}

    Got: #{inspect(result)}
    """
  end

  defp raise_bad_callback_response!(result, view, name, arity) do
    raise ArgumentError, """
    invalid noreply from #{inspect(view)}.#{name}/#{arity} callback.

    Expected one of:

        {:noreply, %Socket{}}

    Got: #{inspect(result)}
    """
  end

  defp component_handle_event(state, cid, event, val, ref) do
    %{socket: socket, components: components} = state

    result =
      Diff.with_component(socket, cid, %{}, components, fn component_socket, component ->
        inner_component_handle_event(component_socket, component, event, val)
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

  defp inner_component_handle_event(component_socket, _component, "lv:clear-flash", val) do
    component_socket =
      case val do
        %{"key" => key} -> Utils.clear_flash(component_socket, key)
        _ -> Utils.clear_flash(component_socket)
      end

    {component_socket, {nil, %{}}}
  end

  defp inner_component_handle_event(_component_socket, _component, "lv:" <> _ = bad_event, _val) do
    raise ArgumentError, """
    received unknown LiveView event #{inspect(bad_event)}.
    The following LiveView events are supported: lv:clear-flash.
    """
  end

  defp inner_component_handle_event(component_socket, component, event, val) do
    :telemetry.span(
      [:phoenix, :live_component, :handle_event],
      %{socket: component_socket, component: component, event: event, params: val},
      fn ->
        case component.handle_event(event, val, component_socket) do
          {:noreply, %Socket{redirected: redirected, assigns: assigns} = component_socket} ->
            {
              {component_socket, {redirected, assigns.flash}},
              %{socket: component_socket, component: component, event: event, params: val}
            }

          other ->
            raise ArgumentError, """
            invalid return from #{inspect(component)}.handle_event/3 callback.

            Expected: {:noreply, %Socket{}}
            Got: #{inspect(other)}
            """
        end
      end
    )
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
  defp gather_keys([%{} = map], acc), do: gather_keys(map, acc)
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
        handle_redirect(new_state, result, Utils.changed_flash(new_socket), ref)
    end
  end

  defp maybe_push_pending_diff_ack(state, nil), do: state
  defp maybe_push_pending_diff_ack(state, {diff, ref}), do: push_render(state, diff, ref)

  defp handle_redirect(new_state, result, flash, ref, pending_diff_ack \\ nil) do
    %{socket: new_socket} = new_state
    root_pid = new_socket.root_pid

    case result do
      {:redirect, %{external: to} = opts} ->
        opts =
          copy_flash(new_state, flash, opts)
          |> Map.delete(:external)
          |> Map.put(:to, to)

        new_state
        |> push_redirect(opts, ref)
        |> stop_shutdown_redirect(:redirect, opts)

      {:redirect, %{to: _to} = opts} ->
        opts = copy_flash(new_state, flash, opts)

        new_state
        |> push_redirect(opts, ref)
        |> stop_shutdown_redirect(:redirect, opts)

      {:live, :redirect, %{to: _to} = opts} ->
        opts = copy_flash(new_state, flash, opts)

        new_state
        |> push_live_redirect(opts, ref)
        |> stop_shutdown_redirect(:live_redirect, opts)

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

  defp stop_shutdown_redirect(state, kind, opts) do
    send(state.transport_pid, {:socket_close, self(), {kind, opts}})
    {:stop, {:shutdown, {kind, opts}}, state}
  end

  defp drop_redirect(state) do
    put_in(state.socket.redirected, nil)
  end

  defp sync_handle_params_with_live_redirect(state, params, action, %{to: to} = opts, ref) do
    %{socket: socket} = state

    {:noreply, %Socket{} = new_socket} =
      socket
      |> assign_action(action)
      |> Utils.call_handle_params!(socket.view, params, build_uri(state, to))

    handle_changed(state, new_socket, ref, opts)
  end

  defp push_live_patch(state, nil), do: state
  defp push_live_patch(state, opts), do: push(state, "live_patch", opts)

  defp push_redirect(state, opts, nil = _ref) do
    push(state, "redirect", opts)
  end

  defp push_redirect(state, opts, ref) do
    reply(state, ref, :ok, %{redirect: opts})
  end

  defp push_live_redirect(state, opts, nil = _ref) do
    push(state, "live_redirect", opts)
  end

  defp push_live_redirect(state, opts, ref) do
    reply(state, ref, :ok, %{live_redirect: opts})
  end

  defp push_noop(state, nil = _ref), do: state
  defp push_noop(state, ref), do: reply(state, ref, :ok, %{})

  defp push_render(state, diff, ref) when diff == %{} do
    push_noop(state, ref)
  end

  defp push_render(state, diff, nil = _ref), do: push(state, "diff", diff)
  defp push_render(state, diff, ref), do: reply(state, ref, :ok, %{diff: diff})

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

  defp mount(%{"session" => session_token} = params, from, phx_socket) do
    case Static.verify_session(phx_socket.endpoint, session_token, params["static"]) do
      {:ok, verified} ->
        %{private: %{connect_info: connect_info}} = phx_socket

        case connect_info do
          %{session: nil} ->
            Logger.debug("""
            LiveView session was misconfigured or the user token is outdated.

            1) Ensure your session configuration in your endpoint is in a module attribute:

                @session_options [
                  ...
                ]

            2) Change the `plug Plug.Session` to use said attribute:

                plug Plug.Session, @session_options

            3) Also pass the `@session_options` to your LiveView socket:

                socket "/live", Phoenix.LiveView.Socket,
                  websocket: [connect_info: [session: @session_options]]

            4) Define the CSRF meta tag inside the `<head>` tag in your layout:

                <%= csrf_meta_tag() %>

            5) Pass it forward in your app.js:

                let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
                let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}});
            """)

            GenServer.reply(from, {:error, %{reason: "stale"}})
            {:stop, :shutdown, :no_state}

          %{} ->
            verified_mount(verified, params, from, phx_socket, connect_info)
        end

      {:error, _reason} ->
        GenServer.reply(from, {:error, %{reason: "stale"}})
        {:stop, :shutdown, :no_state}
    end
  end

  defp mount(%{}, from, phx_socket) do
    Logger.error("Mounting #{phx_socket.topic} failed because no session was provided")
    GenServer.reply(from, {:error, %{reason: "stale"}})
    {:stop, :shutdown, :no_session}
  end

  defp verify_flash(endpoint, verified, flash_token, connect_params) do
    verified_flash = verified[:flash]

    # verified_flash is fetched from the disconnected render.
    # params["flash"] is sent on live redirects and therefore has higher priority.
    cond do
      flash_token -> Utils.verify_flash(endpoint, flash_token)
      connect_params["_mounts"] == 0 && verified_flash -> verified_flash
      true -> %{}
    end
  end

  defp verified_mount(verified, params, from, phx_socket, connect_info) do
    %{
      id: id,
      view: view,
      root_view: root_view,
      parent_pid: parent,
      root_pid: root,
      session: session,
      assign_new: assign_new
    } = verified

    # Make sure the view is loaded. Otherwise if the first request
    # ever is a LiveView connection, the view won't be loaded and
    # the mount/handle_params callbacks won't be invoked as they
    # are optional, leading to errors.
    view.__live__()

    %Phoenix.Socket{
      endpoint: endpoint,
      transport_pid: transport_pid
    } = phx_socket

    # Optional parameter handling
    url = params["url"]
    connect_params = params["params"]

    # Optional verified parts
    router = verified[:router]
    flash = verify_flash(endpoint, verified, params["flash"], connect_params)
    socket_session = connect_info[:session] || %{}

    Process.monitor(transport_pid)
    load_csrf_token(endpoint, socket_session)

    case params do
      %{"caller" => {pid, _}} when is_pid(pid) -> Process.put(:"$callers", [pid])
      _ -> Process.put(:"$callers", [transport_pid])
    end

    socket = %Socket{
      endpoint: endpoint,
      view: view,
      root_view: root_view,
      connected?: true,
      parent_pid: parent,
      root_pid: root || self(),
      id: id,
      router: router
    }

    {params, host_uri, action} =
      case router && url && Utils.live_link_info!(socket, view, url) do
        {:internal, params, action, host_uri} -> {params, host_uri, action}
        {:external, host_uri} -> {:not_mounted_at_router, host_uri, nil}
        _ -> {:not_mounted_at_router, :not_mounted_at_router, nil}
      end

    socket =
      Utils.configure_socket(
        socket,
        mount_private(parent, assign_new, connect_params, connect_info),
        action,
        flash,
        host_uri
      )

    socket
    |> Utils.maybe_call_live_view_mount!(view, params, Map.merge(socket_session, session))
    |> build_state(phx_socket)
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

  defp mount_private(nil, assign_new, connect_params, connect_info) do
    %{
      connect_params: connect_params,
      connect_info: connect_info,
      assign_new: {%{}, assign_new}
    }
  end

  defp mount_private(parent, assign_new, connect_params, connect_info) do
    parent_assigns = sync_with_parent(parent, assign_new)

    # Child live views always ignore the layout on `:use`.
    %{
      connect_params: connect_params,
      connect_info: connect_info,
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

  defp build_state(%Socket{} = lv_socket, %Phoenix.Socket{} = phx_socket) do
    %{
      join_ref: phx_socket.join_ref,
      serializer: phx_socket.serializer,
      socket: lv_socket,
      topic: phx_socket.topic,
      transport_pid: phx_socket.transport_pid,
      components: Diff.new_components()
    }
  end

  defp build_uri(%{socket: socket}, "/" <> _ = to) do
    URI.to_string(%{socket.host_uri | path: to})
  end

  defp post_mount_prune(%{socket: socket} = state) do
    %{state | socket: Utils.post_mount_prune(socket)}
  end

  defp assign_action(socket, action) do
    Phoenix.LiveView.assign(socket, :live_action, action)
  end
end
