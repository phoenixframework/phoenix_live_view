defmodule Phoenix.LiveViewTest.ClientProxy do
  @moduledoc false
  use GenServer

  alias Phoenix.LiveViewTest.{View, DOM}

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
    }

    case mount_view(state, root_view, timeout) do
      {:ok, pid, rendered} ->
        new_state =
          state
          |> put_view(root_view, pid, rendered)
          |> detect_added_or_removed_children(root_view.token)

        send_caller(state, {:mounted, pid, DOM.render(rendered)})

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
        receive do
          {^ref, %{rendered: rendered}} ->
            send_caller(state, {:mounted, pid, DOM.render(rendered)})
            {:ok, pid, rendered}

        after timeout ->
          exit(:timout)
        end

      :ignore ->
        receive do
          {^ref, reason} ->
            send_caller(state, reason)
            {:error, reason}
        end
    end
  end

  defp start_supervised_channel(state, view, ref) do
    socket = %Phoenix.Socket{
      transport_pid: self(),
      serializer: Phoenix.LiveViewTest,
      channel: view.module,
      endpoint: view.endpoint,
      private: %{log_join: false},
      topic: view.topic,
      join_ref: state.join_ref
    }

    spec =
      Supervisor.child_spec(
        {Phoenix.LiveView.Channel, {%{"session" => view.token}, {self(), ref}, socket}},
        restart: :temporary
      )

    DynamicSupervisor.start_child(Phoenix.LiveView.DynamicSupervisor, spec)
  end

  def handle_info({:sync_children, topic, from}, state) do
    {:ok, view} = fetch_view_by_topic(state, topic)

    children =
      Enum.map(view.children, fn session ->
        {:ok, child} = fetch_view_by_session(state, session)
        child
      end)

    GenServer.reply(from, children)
    {:noreply, state}
  end

  def handle_info({:sync_render, topic, from}, state) do
    {:ok, view} = fetch_view_by_topic(state, topic)
    GenServer.reply(from, {:ok, render_tree(state, view)})
    {:noreply, state}
  end

  def handle_info(%Phoenix.Socket.Message{
      event: "redirect",
      topic: topic,
      payload: %{to: to},
    }, state) do

    send_redirect(state, topic, to)
    {:noreply, state}
  end

  def handle_info(%Phoenix.Socket.Message{
      event: "render",
      topic: topic,
      payload: diff,
    }, state) do

    {:noreply, merge_rendered(state, topic, diff)}
  end

  def handle_info(%Phoenix.Socket.Reply{} = reply, state) do
    %{ref: ref, payload: diff, topic: topic} = reply
    new_state = merge_rendered(state, topic, diff)
    {:ok, view} = fetch_view_by_topic(new_state, topic)
    {:ok, {from, _pid}} = fetch_reply(new_state, ref)
    html = render_tree(state, view)

    GenServer.reply(from, {:ok, html})

    {:noreply, drop_reply(new_state, ref)}
  end

  def handle_info({:socket_close, pid, reason}, state) do
    Enum.each(state.replies, fn
      {_ref, {from, ^pid}} -> GenServer.reply(from, {:error, reason})
      {_ref, {_from, _pid}} -> :ok
    end)

    new_state = drop_downed_view(state, pid)
    {:noreply, %{new_state | replies: %{}}}
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
      ref: ref,
    })
    {:noreply, put_reply(%{state | ref: state.ref + 1}, ref, from, view.pid)}
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
    Enum.reduce(view.children, root_html, fn session, acc ->
      {:ok, child} = fetch_view_by_session(state, session)
      child_html = render_tree(state, child)
      DOM.insert_session(acc, session, child_html)
    end)
  end

  defp put_child(state, %View{} = parent, session) do
    update_in(state, [:views, parent.topic], fn %View{} = parent ->
      View.put_child(parent, session)
    end)
  end

  defp prune_children(state, %View{} = parent) do
    update_in(state, [:views, parent.topic], fn %View{} = parent ->
      View.prune_children(parent)
    end)
  end

  defp drop_child(state, %View{} = parent, session, reason) do
    state
    |> update_in([:views, parent.topic], fn %View{} = parent ->
      View.drop_child(parent, session)
    end)
    |> drop_view_by_session(session, reason)
  end

  defp verify_session(%View{} = view) do
    Phoenix.LiveView.View.verify_session(view.endpoint, view.token)
  end

  defp put_view(state, %View{} = view, pid, rendered) do
    {:ok, %{view: module}} = verify_session(view)
    new_view = %View{view | module: module, proxy: self(), pid: pid, rendered: rendered}

    %{
      state
      | views: Map.put(state.views, new_view.topic, new_view),
        pids: Map.put(state.pids, pid, new_view.topic),
        sessions: Map.put(state.sessions, new_view.token, new_view.topic)
    }
  end

  defp drop_downed_view(state, pid) when is_pid(pid) do
    {:ok, topic} = Map.fetch(state.pids, pid)
    {:ok, view} = fetch_view_by_topic(state, topic)

    %{
      state
      | sessions: Map.delete(state.sessions, view.token),
        views: Map.delete(state.views, topic),
        pids: Map.delete(state.pids, view.pid)
    }
  end

  defp drop_view_by_session(state, session, reason) do
    {:ok, view} = fetch_view_by_session(state, session)
    :ok = shutdown_view(view, reason)

    new_state =
      Enum.reduce(view.children, state, fn child_session, acc ->
        drop_child(acc, view, child_session, reason)
      end)

    {topic, new_sessions} = Map.pop(new_state.sessions, session)
    %{new_state |
      sessions: new_sessions,
      views: Map.delete(new_state.views, topic),
      pids: Map.delete(new_state.pids, view.pid)}
  end

  defp fetch_view_by_topic(state, topic), do: Map.fetch(state.views, topic)

  defp fetch_view_by_session(state, session) do
    with {:ok, topic} <- Map.fetch(state.sessions, session) do
      fetch_view_by_topic(state, topic)
    end
  end

  defp drop_all_views(state, reason) do
    Enum.reduce(state.views, state, fn {_topic, view}, acc ->
      drop_view_by_session(acc, view.token, reason)
    end)
  end

  defp merge_rendered(state, topic, diff) do
    {:ok, view} = fetch_view_by_topic(state, topic)
    new_view = %View{view | rendered: DOM.deep_merge(view.rendered, diff)}
    new_state =
      %{state | views: Map.update!(state.views, topic, fn _ -> new_view end)}

    detect_added_or_removed_children(new_state, new_view.token)
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
      |> DOM.render()
      |> DOM.find_sessions()
      |> Enum.reduce(pruned_state, fn session, acc ->
        case fetch_view_by_session(acc, session) do
          {:ok, _view} -> put_child(acc, view, session)
          :error ->
            child_view = View.build_child(view, token: session)
            case mount_view(acc, child_view, acc.timeout) do
              {:ok, pid, rendered} ->
                acc
                |> put_view(child_view, pid, rendered)
                |> put_child(view, child_view.token)
                |> do_detect_added_or_removed_children(child_view.token)

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
    |> Enum.reduce(new_state, fn session, acc ->
      drop_child(acc, new_view, session, :removed)
    end)
  end

  defp shutdown_view(%View{pid: pid}, reason) do
    Process.unlink(pid)
    GenServer.stop(pid, {:shutdown, reason})
  end

  defp send_caller(%{caller: {ref, pid}}, msg) when is_pid(pid) do
    send(pid, {ref, msg})
  end

  defp send_redirect(state, topic, to) do
    send_caller(state, {:redirect, topic, to})
  end
end
