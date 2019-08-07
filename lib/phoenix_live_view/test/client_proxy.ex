defmodule Phoenix.LiveViewTest.ClientProxy do
  @moduledoc false
  use GenServer

  alias Phoenix.LiveViewTest.{View, DOM}

  @doc """
  Starts a client proxy.

  ## Options

    * `:caller` - the required `{ref, pid}` pair identifying the caller.
    * `:view` - the required `%Phoenix.LiveViewTest.View{}`
    * `:timeout` - the required timeout for successful mount
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    {_caller_ref, _caller_pid} = caller = Keyword.fetch!(opts, :caller)
    root_view = Keyword.fetch!(opts, :view)
    timeout = Keyword.fetch!(opts, :timeout)

    state = %{
      timeout: timeout,
      join_ref: 0,
      ref: 0,
      caller: caller,
      views: %{},
      sessions: %{},
      pids: %{},
      replies: %{},
      root_view: root_view
    }

    case mount_view(state, root_view, timeout) do
      {:ok, pid, rendered} ->
        new_state =
          state
          |> put_view(root_view, pid, rendered)
          |> detect_added_or_removed_children(root_view.session_token)

        send_caller(state, {:mounted, pid, DOM.render_diff(rendered)})

        {:ok, new_state}

      {:error, reason} ->
        send_caller(state, reason)
        :ignore
    end
  end

  defp mount_view(state, view, timeout) do
    ref = make_ref()

    case start_supervised_channel(state, view, ref) do
      {:ok, pid} ->
        mon_ref = Process.monitor(pid)

        receive do
          {^ref, {:ok, %{rendered: rendered}}} ->
            Process.demonitor(mon_ref, [:flush])
            {:ok, pid, rendered}

          {^ref, {:error, reason}} ->
            Process.demonitor(mon_ref, [:flush])
            send_caller(state, reason)
            {:error, reason}

          {:DOWN, ^mon_ref, _, _, reason} ->
            send_caller(state, reason)
            {:error, reason}
        after
          timeout -> exit(:timeout)
        end

      {:error, reason} ->
        send_caller(state, reason)
        {:error, reason}
    end
  end

  defp start_supervised_channel(state, view, ref) do
    socket = %Phoenix.Socket{
      transport_pid: self(),
      serializer: Phoenix.LiveViewTest,
      channel: view.module,
      endpoint: view.endpoint,
      private: %{},
      topic: view.topic,
      join_ref: state.join_ref
    }

    params = %{
      "session" => view.session_token,
      "static" => view.static_token,
      "url" => Path.join(view.endpoint.url(), view.mount_path),
      "params" => view.connect_params
    }

    spec =
      Supervisor.child_spec(
        {Phoenix.LiveView.Channel, {params, {self(), ref}, socket}},
        restart: :temporary
      )

    DynamicSupervisor.start_child(Phoenix.LiveView.DynamicSupervisor, spec)
  end

  def handle_info({:sync_children, topic, from}, state) do
    {:ok, view} = fetch_view_by_topic(state, topic)

    children =
      Enum.flat_map(view.children, fn {session, _dom_id} ->
        case fetch_view_by_session(state, session) do
          {:ok, child} -> [child]
          :error -> []
        end
      end)

    GenServer.reply(from, children)
    {:noreply, state}
  end

  def handle_info({:sync_render, topic, from}, state) do
    {:ok, view} = fetch_view_by_topic(state, topic)
    GenServer.reply(from, {:ok, render_tree(state, view)})
    {:noreply, state}
  end

  def handle_info(
        %Phoenix.Socket.Message{
          event: "redirect",
          topic: topic,
          payload: %{to: to}
        },
        state
      ) do
    send_redirect(state, topic, to)
    {:noreply, state}
  end

  def handle_info(
        %Phoenix.Socket.Message{
          event: "live_redirect",
          topic: topic,
          payload: %{to: to}
        },
        state
      ) do
    send_redirect(state, topic, to)
    {:noreply, state}
  end

  def handle_info(
        %Phoenix.Socket.Message{
          event: "external_live_redirect",
          topic: topic,
          payload: %{to: to}
        },
        state
      ) do
    send_redirect(state, topic, to)
    {:noreply, state}
  end

  def handle_info(
        %Phoenix.Socket.Message{
          event: "diff",
          topic: topic,
          payload: diff
        },
        state
      ) do
    {:noreply, merge_rendered(state, topic, diff)}
  end

  def handle_info(%Phoenix.Socket.Reply{} = reply, state) do
    %{ref: ref, payload: payload, topic: topic} = reply
    {:ok, {from, _pid}} = fetch_reply(state, ref)
    state = drop_reply(state, ref)

    case payload do
      %{external_live_redirect: %{to: to}} ->
        send_redirect(state, topic, to)
        GenServer.reply(from, {:error, {:redirect, %{to: to}}})
        {:noreply, state}

      %{live_redirect: %{to: to}} ->
        send_redirect(state, topic, to)
        {:noreply, render_reply(reply, from, state)}

      %{redirect: %{to: to}} ->
        send_redirect(state, topic, to)
        GenServer.reply(from, {:error, {:redirect, %{to: to}}})
        {:noreply, state}

      %{} ->
        {:noreply, render_reply(reply, from, state)}
    end
  end

  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    case fetch_view_by_pid(state, pid) do
      {:ok, _view} -> {:noreply, drop_downed_view(state, pid, reason)}
      :error -> {:noreply, state}
    end
  end

  def handle_info({:socket_close, pid, reason}, state) do
    {:noreply, drop_downed_view(state, pid, reason)}
  end

  def handle_call({:stop, %View{topic: topic}}, _from, state) do
    case fetch_view_by_topic(state, topic) do
      {:ok, view} ->
        {:reply, :ok, drop_view_by_session(state, view.session_token, :stop)}

      :error ->
        {:reply, :ok, state}
    end
  end

  def handle_call({:children, %View{topic: topic}}, from, state) do
    case fetch_view_by_topic(state, topic) do
      {:ok, view} ->
        :ok = Phoenix.LiveView.Channel.ping(view.pid)
        send(self(), {:sync_children, view.topic, from})
        {:noreply, state}

      :error ->
        {:reply, {:error, :removed}, state}
    end
  end

  def handle_call({:render_tree, view}, from, state) do
    :ok = Phoenix.LiveView.Channel.ping(view.pid)
    send(self(), {:sync_render, view.topic, from})
    {:noreply, state}
  end

  def handle_call({:render_event, %View{topic: topic}, type, event, raw_val}, from, state) do
    {:ok, view} = fetch_view_by_topic(state, topic)
    ref = to_string(state.ref + 1)

    send(view.pid, %Phoenix.Socket.Message{
      join_ref: state.join_ref,
      topic: view.topic,
      event: "event",
      payload: %{"value" => raw_val, "event" => to_string(event), "type" => to_string(type)},
      ref: ref
    })

    {:noreply, put_reply(%{state | ref: state.ref + 1}, ref, from, view.pid)}
  end

  def handle_call({:render_live_link, %View{topic: topic}, path}, from, state) do
    {:ok, view} = fetch_view_by_topic(state, topic)
    ref = to_string(state.ref + 1)

    send(view.pid, %Phoenix.Socket.Message{
      join_ref: state.join_ref,
      topic: view.topic,
      event: "link",
      payload: %{"url" => path},
      ref: ref
    })

    {:noreply, put_reply(%{state | ref: state.ref + 1}, ref, from, view.pid)}
  end

  defp flush_replies(state, pid, reason) do
    Enum.reduce(state.replies, state, fn
      {ref, {from, ^pid}}, acc ->
        GenServer.reply(from, {:error, reason})
        drop_reply(acc, ref)

      {_ref, {_from, _pid}}, acc ->
        acc
    end)
  end

  defp fetch_reply(state, ref) do
    Map.fetch(state.replies, ref)
  end

  defp put_reply(state, ref, from, pid) do
    %{state | replies: Map.put(state.replies, ref, {from, pid})}
  end

  defp drop_reply(state, ref) do
    %{state | replies: Map.delete(state.replies, ref)}
  end

  defp render_tree(state, %View{} = view) do
    root_html = DOM.render_diff(view.rendered)

    Enum.reduce(view.children, root_html, fn {session, _dom_id}, acc ->
      {:ok, child} = fetch_view_by_session(state, session)
      child_html = render_tree(state, child)
      DOM.insert_attr(acc, "data-phx-session", session, child_html)
    end)
  end

  defp put_child(state, %View{} = parent, session, dom_id) do
    update_in(state, [:views, parent.topic], fn %View{} = parent ->
      View.put_child(parent, session, dom_id)
    end)
  end

  defp prune_children(state, %View{} = parent) do
    update_in(state, [:views, parent.topic], fn %View{} = parent ->
      View.prune_children(parent)
    end)
  end

  defp maybe_drop_dup_child_id(state, %View{} = parent, child_dom_id, reason) do
    case View.fetch_child_session_by_id(parent, child_dom_id) do
      {:ok, session} -> drop_child(state, parent, session, reason)
      :error -> state
    end
  end

  defp drop_child(state, %View{} = parent, session, reason) do
    state
    |> update_in([:views, parent.topic], fn %View{} = parent ->
      View.drop_child(parent, session)
    end)
    |> drop_view_by_session(session, reason)
  end

  defp verify_session(%View{} = view) do
    Phoenix.LiveView.View.verify_session(view.endpoint, view.session_token, view.static_token)
  end

  defp put_view(state, %View{} = view, pid, rendered) do
    {:ok, %{view: module}} = verify_session(view)
    new_view = %View{view | module: module, proxy: self(), pid: pid, rendered: rendered}
    Process.monitor(pid)

    %{
      state
      | views: Map.put(state.views, new_view.topic, new_view),
        pids: Map.put(state.pids, pid, new_view.topic),
        sessions: Map.put(state.sessions, new_view.session_token, new_view.topic)
    }
  end

  defp drop_downed_view(state, pid, reason) when is_pid(pid) do
    {:ok, view} = fetch_view_by_pid(state, pid)
    send_caller(state, {:removed, view.topic, reason})

    flush_replies(
      %{
        state
        | sessions: Map.delete(state.sessions, view.session_token),
          views: Map.delete(state.views, view.topic),
          pids: Map.delete(state.pids, view.pid)
      },
      pid,
      reason
    )
  end

  defp drop_view_by_session(state, session, reason) do
    {:ok, view} = fetch_view_by_session(state, session)
    :ok = shutdown_view(view, reason)

    Enum.reduce(view.children, state, fn {child_session, _dom_id}, acc ->
      drop_child(acc, view, child_session, reason)
    end)
  end

  defp fetch_view_by_topic(state, topic), do: Map.fetch(state.views, topic)

  defp fetch_view_by_pid(state, pid) when is_pid(pid) do
    with {:ok, topic} <- Map.fetch(state.pids, pid) do
      fetch_view_by_topic(state, topic)
    end
  end

  defp fetch_view_by_session(state, session) do
    with {:ok, topic} <- Map.fetch(state.sessions, session) do
      fetch_view_by_topic(state, topic)
    end
  end

  defp drop_all_views(state, reason) do
    Enum.reduce(state.views, state, fn {_topic, view}, acc ->
      drop_view_by_session(acc, view.session_token, reason)
    end)
  end

  defp render_reply(reply, from, state) do
    %{payload: diff, topic: topic} = reply
    new_state = merge_rendered(state, topic, diff)

    case fetch_view_by_topic(new_state, topic) do
      {:ok, view} ->
        html = render_tree(new_state, view)
        GenServer.reply(from, {:ok, html})
        new_state

      :error ->
        new_state
    end
  end

  defp merge_rendered(state, topic, %{diff: diff}), do: merge_rendered(state, topic, diff)

  defp merge_rendered(state, topic, %{} = diff) do
    case fetch_view_by_topic(state, topic) do
      {:ok, view} ->
        new_view = %View{view | rendered: DOM.deep_merge(view.rendered, diff)}
        new_state = %{state | views: Map.update!(state.views, topic, fn _ -> new_view end)}

        detect_added_or_removed_children(new_state, new_view.session_token)

      :error ->
        state
    end
  end

  defp detect_added_or_removed_children(state, token) do
    do_detect_added_or_removed_children(state, token)
  catch
    :throw, {:stop, {:redirect, view, to}, new_state} ->
      send_redirect(new_state, view.topic, to)
      drop_all_views(new_state, :redirected)
  end

  defp do_detect_added_or_removed_children(state, token) do
    {:ok, view} = fetch_view_by_session(state, token)
    children_before = view.children
    pruned_state = prune_children(state, view)

    new_state =
      view.rendered
      |> DOM.render_diff()
      |> DOM.find_sessions()
      |> Enum.reduce(pruned_state, fn {session, static, dom_id}, acc ->
        case fetch_view_by_session(acc, session) do
          {:ok, _view} ->
            put_child(acc, view, session, dom_id)

          :error ->
            static = static || Map.get(state.root_view.child_statics, dom_id)

            child_view =
              View.build_child(view, dom_id: dom_id, session_token: session, static_token: static)

            acc
            |> maybe_drop_dup_child_id(view, dom_id, :removed)
            |> mount_view(child_view, acc.timeout)
            |> case do
              {:ok, pid, rendered} ->
                acc
                |> put_view(child_view, pid, rendered)
                |> put_child(view, child_view.session_token, dom_id)
                |> do_detect_added_or_removed_children(child_view.session_token)

              {:error, %{redirect: to}} ->
                throw({:stop, {:redirect, child_view, to}, acc})

              {:error, reason} ->
                raise RuntimeError, "failed to mount view: #{inspect(reason)}"
            end
        end
      end)

    {:ok, new_view} = fetch_view_by_topic(new_state, view.topic)

    new_view
    |> View.removed_children(children_before)
    |> Enum.reduce(new_state, fn {session, _dom_id}, acc ->
      drop_child(acc, new_view, session, :removed)
    end)
  end

  defp shutdown_view(%View{pid: pid}, reason) do
    Process.exit(pid, {:shutdown, reason})
    :ok
  end

  defp send_caller(%{caller: {ref, pid}}, msg) when is_pid(pid) do
    send(pid, {ref, msg})
  end

  defp send_redirect(state, topic, to) do
    send_caller(state, {:redirect, topic, %{to: to}})
  end
end
