defmodule Phoenix.LiveView.Channel do
  @moduledoc false
  use GenServer, restart: :temporary

  require Logger

  alias Phoenix.LiveView.{Socket, Utils, Diff, Static, Upload, UploadConfig}
  alias Phoenix.Socket.Message

  @prefix :phoenix

  def start_link({endpoint, from}) do
    hibernate_after = endpoint.config(:live_view)[:hibernate_after] || 15000
    opts = [hibernate_after: hibernate_after]
    GenServer.start_link(__MODULE__, from, opts)
  end

  def send_update(pid \\ self(), module, id, assigns) do
    send(pid, {@prefix, :send_update, {module, id, assigns}})
  end

  def send_update_after(pid \\ self(), module, id, assigns, time_in_milliseconds)
      when is_integer(time_in_milliseconds) do
    Process.send_after(
      pid,
      {@prefix, :send_update, {module, id, assigns}},
      time_in_milliseconds
    )
  end

  def ping(pid) do
    GenServer.call(pid, {@prefix, :ping}, :infinity)
  end

  def register_upload(pid, {upload_config_ref, entry_ref} = _ref, cid) do
    info = %{channel_pid: self(), ref: upload_config_ref, entry_ref: entry_ref, cid: cid}
    GenServer.call(pid, {@prefix, :register_entry_upload, info})
  end

  def fetch_upload_config(pid, name, cid) do
    GenServer.call(pid, {@prefix, :fetch_upload_config, name, cid})
  end

  def drop_upload_entries(%UploadConfig{} = conf, entry_refs) do
    info = %{ref: conf.ref, entry_refs: entry_refs, cid: conf.cid}
    send(self(), {@prefix, :drop_upload_entries, info})
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

  def handle_info(
        {:DOWN, _, _, transport_pid, _reason},
        %{socket: %{transport_pid: transport_pid}} = state
      ) do
    {:stop, {:shutdown, :closed}, state}
  end

  def handle_info({:DOWN, _, _, parent, reason}, %{socket: %{parent_pid: parent}} = state) do
    send(state.socket.transport_pid, {:socket_close, self(), reason})
    {:stop, {:shutdown, :parent_exited}, state}
  end

  def handle_info({:DOWN, _, :process, pid, reason} = msg, %{socket: socket} = state) do
    case Map.fetch(state.upload_pids, pid) do
      {:ok, {ref, entry_ref, cid}} ->
        if reason in [:normal, {:shutdown, :closed}] do
          new_state =
            state
            |> drop_upload_pid(pid)
            |> unregister_upload(ref, entry_ref, cid)

          {:noreply, new_state}
        else
          {:stop, {:shutdown, {:channel_upload_exit, reason}}, state}
        end

      :error ->
        msg
        |> socket.view.handle_info(socket)
        |> handle_result({:handle_info, 2, nil}, state)
    end
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

  def handle_info(
        %Message{topic: topic, event: "cids_will_destroy"} = msg,
        %{topic: topic} = state
      ) do
    %{"cids" => cids} = msg.payload

    new_components =
      Enum.reduce(cids, state.components, fn cid, acc ->
        Diff.mark_for_deletion_component(cid, acc)
      end)

    {:noreply, reply(%{state | components: new_components}, msg.ref, :ok, %{})}
  end

  def handle_info(%Message{topic: topic, event: "progress"} = msg, %{topic: topic} = state) do
    cid = msg.payload["cid"]

    new_state =
      write_socket(state, cid, msg.ref, fn socket, _ ->
        %{"ref" => ref, "entry_ref" => entry_ref, "progress" => progress} = msg.payload
        new_socket = Upload.update_progress(socket, ref, entry_ref, progress)
        upload_conf = Upload.get_upload_by_ref!(new_socket, ref)
        entry = UploadConfig.get_entry_by_ref(upload_conf, entry_ref)

        if event = entry && upload_conf.progress_event do
          {:noreply, new_socket} = event.(upload_conf.name, entry, new_socket)
          {new_socket, {:ok, {msg.ref, %{}}, state}}
        else
          {new_socket, {:ok, {msg.ref, %{}}, state}}
        end
      end)

    {:noreply, new_state}
  end

  def handle_info(%Message{topic: topic, event: "allow_upload"} = msg, %{topic: topic} = state) do
    %{"ref" => upload_ref, "entries" => entries} = payload = msg.payload
    cid = payload["cid"]

    new_state =
      write_socket(state, cid, msg.ref, fn socket, _ ->
        socket = Upload.register_cid(socket, upload_ref, cid)
        conf = Upload.get_upload_by_ref!(socket, upload_ref)
        ensure_unique_upload_name!(state, conf)

        {ok_or_error, reply, %Socket{} = new_socket} =
          with {:ok, new_socket} <- Upload.put_entries(socket, conf, entries, cid) do
            Upload.generate_preflight_response(new_socket, conf.name, cid)
          end

        new_upload_names =
          case ok_or_error do
            :ok -> Map.put(state.upload_names, conf.name, {upload_ref, cid})
            _ -> state.upload_names
          end

        {new_socket, {:ok, {msg.ref, reply}, %{state | upload_names: new_upload_names}}}
      end)

    {:noreply, new_state}
  end

  def handle_info(
        %Message{topic: topic, event: "cids_destroyed"} = msg,
        %{topic: topic} = state
      ) do
    %{"cids" => cids} = msg.payload
    {deleted_cids, new_state} = delete_components(state, cids)
    {:noreply, reply(new_state, msg.ref, :ok, %{cids: deleted_cids})}
  end

  def handle_info(%Message{topic: topic, event: "event"} = msg, %{topic: topic} = state) do
    %{"value" => raw_val, "event" => event, "type" => type} = msg.payload
    val = decode_event_type(type, raw_val)

    if cid = msg.payload["cid"] do
      component_handle_event(state, cid, event, val, msg.ref, msg.payload)
    else
      new_state = %{state | socket: maybe_update_uploads(state.socket, msg.payload)}

      new_state.socket
      |> view_handle_event(event, val)
      |> handle_result({:handle_event, 3, msg.ref}, new_state)
    end
  end

  def handle_info({@prefix, :drop_upload_entries, info}, state) do
    %{ref: ref, cid: cid, entry_refs: entry_refs} = info

    new_state =
      write_socket(state, cid, nil, fn socket, _ ->
        upload_config = Upload.get_upload_by_ref!(socket, ref)
        {Upload.drop_upload_entries(socket, upload_config, entry_refs), {:ok, nil, state}}
      end)

    {:noreply, new_state}
  end

  def handle_info({@prefix, :send_update, update}, state) do
    case Diff.update_component(state.socket, state.components, update) do
      {diff, new_components} ->
        {:noreply, push_diff(%{state | components: new_components}, diff, nil)}

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

  def handle_call({@prefix, :fetch_upload_config, name, cid}, _from, state) do
    read_socket(state, cid, fn socket, _ ->
      result =
        with {:ok, uploads} <- Map.fetch(socket.assigns, :uploads),
             {:ok, conf} <- Map.fetch(uploads, name),
             do: {:ok, conf}

      {:reply, result, state}
    end)
  end

  def handle_call({@prefix, :child_mount, _child_pid, assign_new}, _from, state) do
    assigns = Map.take(state.socket.assigns, assign_new)
    {:reply, assigns, state}
  end

  def handle_call({@prefix, :register_entry_upload, info}, from, state) do
    {:noreply, register_entry_upload(state, from, info)}
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
        {:diff, diff, new_state} = render_diff(state, socket, true)
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

    case maybe_diff(new_state, true) do
      {:diff, diff, new_state} ->
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
        {:reply, map, %Socket}

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

  defp component_handle_event(state, cid, event, val, ref, payload) do
    %{socket: socket, components: components} = state

    result =
      Diff.write_component(socket, cid, %{}, components, fn component_socket, component ->
        component_socket
        |> maybe_update_uploads(payload)
        |> inner_component_handle_event(component, event, val)
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
          {:noreply, push_diff(new_state, diff, ref)}
        end

      :error ->
        {:noreply, push_noop(state, ref)}
    end
  end

  defp unregister_upload(state, ref, entry_ref, cid) do
    write_socket(state, cid, nil, fn socket, _ ->
      conf = Upload.get_upload_by_ref!(socket, ref)
      new_state = drop_upload_name(state, conf.name)
      {Upload.unregister_completed_entry_upload(socket, conf, entry_ref), {:ok, nil, new_state}}
    end)
  end

  defp put_upload_pid(state, pid, ref, entry_ref, cid) when is_pid(pid) do
    Process.monitor(pid)
    %{state | upload_pids: Map.put(state.upload_pids, pid, {ref, entry_ref, cid})}
  end

  defp drop_upload_pid(state, pid) when is_pid(pid) do
    %{state | upload_pids: Map.delete(state.upload_pids, pid)}
  end

  defp drop_upload_name(state, name) do
    {_, new_state} = pop_in(state.upload_names[name])
    new_state
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
        component_socket =
          %Socket{redirected: redirected, assigns: assigns} =
          case component.handle_event(event, val, component_socket) do
            {:noreply, component_socket} ->
              component_socket

            {:reply, %{} = reply, component_socket} ->
              Utils.put_reply(component_socket, reply)

            other ->
              raise ArgumentError, """
              invalid return from #{inspect(component)}.handle_event/3 callback.

              Expected one of:

                  {:noreply, %Socket{}}
                  {:reply, map, %Socket}

              Got: #{inspect(other)}
              """
          end

        {
          {component_socket, {redirected, assigns.flash}},
          %{socket: component_socket, component: component, event: event, params: val}
        }
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
  defp gather_keys(_, acc), do: acc

  defp handle_changed(state, %Socket{} = new_socket, ref, pending_live_patch \\ nil) do
    new_state = %{state | socket: new_socket}

    case maybe_diff(new_state, false) do
      {:diff, diff, new_state} ->
        {:noreply,
         new_state
         |> push_live_patch(pending_live_patch)
         |> push_diff(diff, ref)}

      result ->
        handle_redirect(new_state, result, Utils.changed_flash(new_socket), ref)
    end
  end

  defp maybe_push_pending_diff_ack(state, nil), do: state
  defp maybe_push_pending_diff_ack(state, {diff, ref}), do: push_diff(state, diff, ref)

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
        |> push_live_redirect(opts, ref, pending_diff_ack)
        |> stop_shutdown_redirect(:live_redirect, opts)

      {:live, {params, action}, %{to: _to, kind: _kind} = opts} when root_pid == self() ->
        new_state
        |> drop_redirect()
        |> maybe_push_pending_diff_ack(pending_diff_ack)
        |> Map.update!(:socket, &Utils.replace_flash(&1, flash))
        |> sync_handle_params_with_live_redirect(params, action, opts, ref)

      {:live, {_params, _action}, %{to: _to, kind: _kind}} = patch ->
        send(new_socket.root_pid, {@prefix, :redirect, patch, flash})
        {:diff, diff, new_state} = render_diff(new_state, new_socket, false)

        {:noreply,
         new_state
         |> drop_redirect()
         |> maybe_push_pending_diff_ack(pending_diff_ack)
         |> push_diff(diff, ref)}
    end
  end

  defp stop_shutdown_redirect(state, kind, opts) do
    send(state.socket.transport_pid, {:socket_close, self(), {kind, opts}})
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

  defp push_live_redirect(state, opts, nil = _ref, {_diff, ack_ref}) do
    reply(state, ack_ref, :ok, %{live_redirect: opts})
  end

  defp push_live_redirect(state, opts, nil = _ref, _pending_diff_ack) do
    push(state, "live_redirect", opts)
  end

  defp push_live_redirect(state, opts, ref, _pending_diff_ack) do
    reply(state, ref, :ok, %{live_redirect: opts})
  end

  defp push_noop(state, nil = _ref), do: state
  defp push_noop(state, ref), do: reply(state, ref, :ok, %{})

  defp push_diff(state, diff, ref) when diff == %{}, do: push_noop(state, ref)
  defp push_diff(state, diff, nil = _ref), do: push(state, "diff", diff)
  defp push_diff(state, diff, ref), do: reply(state, ref, :ok, %{diff: diff})

  defp copy_flash(_state, flash, opts) when flash == %{},
    do: opts

  defp copy_flash(state, flash, opts),
    do: Map.put(opts, :flash, Utils.sign_flash(state.socket.endpoint, flash))

  defp maybe_diff(%{socket: socket} = state, force?) do
    socket.redirected || render_diff(state, socket, force?)
  end

  defp render_diff(state, socket, force?) do
    {socket, diff, components} =
      if force? or Utils.changed?(socket) do
        rendered = Utils.to_rendered(socket, socket.view)
        Diff.render(socket, rendered, state.components)
      else
        {socket, %{}, state.components}
      end

    diff = Diff.render_private(socket, diff)
    {:diff, diff, %{state | socket: Utils.clear_changed(socket), components: components}}
  end

  defp reply(state, {ref, extra}, status, payload) do
    reply(state, ref, status, Map.merge(payload, extra))
  end

  defp reply(state, ref, status, payload) when is_binary(ref) do
    reply_ref = {state.socket.transport_pid, state.serializer, state.topic, ref, state.join_ref}
    Phoenix.Channel.reply(reply_ref, {status, payload})
    state
  end

  defp push(state, event, payload) do
    message = %Message{topic: state.topic, event: event, payload: payload}
    send(state.socket.transport_pid, state.serializer.encode!(message))
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

            4) Ensure the `protect_from_forgery` plug is in your router pipeline:

                plug :protect_from_forgery

            5) Define the CSRF meta tag inside the `<head>` tag in your layout:

                <%= csrf_meta_tag() %>

            6) Pass it forward in your app.js:

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
      transport_pid: transport_pid,
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
        mount_private(parent, root_view, assign_new, connect_params, connect_info),
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

  defp mount_private(nil, root_view, assign_new, connect_params, connect_info) do
    %{
      connect_params: connect_params,
      connect_info: connect_info,
      assign_new: {%{}, assign_new},
      changed: %{},
      root_view: root_view
    }
  end

  defp mount_private(parent, root_view, assign_new, connect_params, connect_info) do
    parent_assigns = sync_with_parent(parent, assign_new)

    # Child live views always ignore the layout on `:use`.
    %{
      connect_params: connect_params,
      connect_info: connect_info,
      assign_new: {parent_assigns, assign_new},
      phoenix_live_layout: false,
      changed: %{},
      root_view: root_view
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
      components: Diff.new_components(),
      upload_names: %{},
      upload_pids: %{}
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

  defp maybe_update_uploads(%Socket{} = socket, %{"uploads" => uploads} = payload) do
    cid = payload["cid"]

    Enum.reduce(uploads, socket, fn {ref, entries}, acc ->
      upload_conf = Upload.get_upload_by_ref!(acc, ref)

      case Upload.put_entries(acc, upload_conf, entries, cid) do
        {:ok, new_socket} -> new_socket
        {:error, _error_resp, %Socket{} = new_socket} -> new_socket
      end
    end)
  end

  defp maybe_update_uploads(%Socket{} = socket, %{} = _payload), do: socket

  defp register_entry_upload(state, from, info) do
    %{channel_pid: pid, ref: ref, entry_ref: entry_ref, cid: cid} = info

    write_socket(state, cid, nil, fn socket, _ ->
      conf = Upload.get_upload_by_ref!(socket, ref)

      case Upload.register_entry_upload(socket, conf, pid, entry_ref) do
        {:ok, new_socket, entry} ->
          reply = %{max_file_size: entry.client_size, chunk_timeout: conf.chunk_timeout}
          GenServer.reply(from, {:ok, reply})
          new_state = put_upload_pid(state, pid, ref, entry_ref, cid)
          {new_socket, {:ok, nil, new_state}}

        {:error, reason} ->
          GenServer.reply(from, {:error, reason})
          {socket, :error}
      end
    end)
  end

  defp read_socket(state, nil = _cid, func) do
    func.(state.socket, nil)
  end

  defp read_socket(state, cid, func) do
    %{socket: socket, components: components} = state
    Diff.read_component(socket, cid, components, func)
  end

  # If :error is returned, the socket must not change,
  # otherwise we need to call push_diff on all cases.
  defp write_socket(state, nil, ref, fun) do
    {new_socket, return} = fun.(state.socket, nil)

    case return do
      {:ok, ref_reply, new_state} ->
        {:noreply, new_state} = handle_changed(new_state, new_socket, ref_reply)
        new_state

      :error ->
        push_noop(state, ref)
    end
  end

  defp write_socket(state, cid, ref, fun) do
    %{socket: socket, components: components} = state

    {diff, new_components, return} =
      case Diff.write_component(socket, cid, %{}, components, fun) do
        {_diff, _new_components, _return} = triplet -> triplet
        :error -> {%{}, components, :error}
      end

    case return do
      {:ok, ref_reply, new_state} ->
        new_state = %{new_state | components: new_components}
        push_diff(new_state, diff, ref_reply)

      :error ->
        push_noop(state, ref)
    end
  end

  defp delete_components(state, cids) do
    upload_cids = Enum.into(state.upload_names, MapSet.new(), fn {_name, {_ref, cid}} -> cid end)

    Enum.flat_map_reduce(cids, state, fn cid, acc ->
      {deleted_cids, new_components} = Diff.delete_component(cid, acc.components)

      canceled_confs =
        deleted_cids
        |> Enum.filter(fn deleted_cid -> deleted_cid in upload_cids end)
        |> Enum.flat_map(fn deleted_cid ->
          read_socket(acc, deleted_cid, fn c_socket, _ ->
            {_new_c_socket, canceled_confs} = Upload.maybe_cancel_uploads(c_socket)
            canceled_confs
          end)
        end)

      new_state =
        Enum.reduce(canceled_confs, acc, fn conf, acc -> drop_upload_name(acc, conf.name) end)

      {deleted_cids, %{new_state | components: new_components}}
    end)
  end

  defp ensure_unique_upload_name!(state, conf) do
    upload_ref = conf.ref
    cid = conf.cid

    case Map.fetch(state.upload_names, conf.name) do
      {:ok, {^upload_ref, ^cid}} ->
        :ok

      :error ->
        :ok

      {:ok, {_existing_ref, existing_cid}} ->
        raise RuntimeError, """
        existing upload for #{conf.name} already allowed in another component (#{existing_cid})

        If you want to allow simultaneous uploads across different components, pass a
        unique upload name to allow_upload/3
        """
    end
  end
end
