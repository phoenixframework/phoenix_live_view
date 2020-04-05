defmodule Phoenix.LiveViewTest.ClientProxy do
  @moduledoc false
  use GenServer

  defstruct session_token: nil,
            static_token: nil,
            module: nil,
            endpoint: nil,
            pid: nil,
            proxy: nil,
            topic: nil,
            ref: nil,
            rendered: nil,
            children: [],
            child_statics: %{},
            id: nil,
            connect_params: %{}

  alias Phoenix.LiveViewTest.{ClientProxy, DOM}

  @doc """
  Encoding used by the Channel serializer.
  """
  def encode!(msg), do: msg

  @doc """
  Starts a client proxy.

  ## Options

    * `:caller` - the required `{ref, pid}` pair identifying the caller.
    * `:view` - the required `%Phoenix.LiveViewTest.View{}`
    * `:html` - the required string of HTML for the document.
    * `:timeout` - the required timeout for successful mount
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    {_caller_pid, _caller_ref} = caller = Keyword.fetch!(opts, :caller)
    root_html = Keyword.fetch!(opts, :html)
    root_view = Keyword.fetch!(opts, :view)
    timeout = Keyword.fetch!(opts, :timeout)
    session = Keyword.fetch!(opts, :session)
    url = Keyword.fetch!(opts, :url)

    state = %{
      timeout: timeout,
      join_ref: 0,
      ref: 0,
      caller: caller,
      views: %{},
      ids: %{},
      pids: %{},
      replies: %{},
      root_view: root_view,
      html: root_html,
      session: session
    }

    case mount_view(state, root_view, timeout, url) do
      {:ok, pid, rendered} ->
        new_state =
          state
          |> put_view(root_view, pid, rendered)
          |> detect_added_or_removed_children(root_view, root_html)

        send_caller(new_state, {:mounted, pid, DOM.to_html(new_state.html)})
        {:ok, new_state}

      {:error, reason} ->
        send_caller(state, reason)
        :ignore
    end
  end

  defp mount_view(state, view, timeout, url) do
    ref = make_ref()

    case start_supervised_channel(state, view, ref, url) do
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

  defp start_supervised_channel(state, view, ref, url) do
    socket = %Phoenix.Socket{
      transport_pid: self(),
      serializer: __MODULE__,
      channel: view.module,
      endpoint: view.endpoint,
      private: %{session: state.session},
      topic: view.topic,
      join_ref: state.join_ref
    }

    params = %{
      "session" => view.session_token,
      "static" => view.static_token,
      "url" => url,
      "params" => view.connect_params,
      "caller" => state.caller,
      "joins" => 0
    }

    spec = {Phoenix.LiveView.Channel, {params, {self(), ref}, socket}}
    DynamicSupervisor.start_child(Phoenix.LiveView.DynamicSupervisor, spec)
  end

  def handle_info({:sync_children, topic, from}, state) do
    {:ok, view} = fetch_view_by_topic(state, topic)

    children =
      Enum.flat_map(view.children, fn {id, _session} ->
        case fetch_view_by_id(state, id) do
          {:ok, child} -> [child]
          :error -> []
        end
      end)

    GenServer.reply(from, children)
    {:noreply, state}
  end

  def handle_info({:sync_render, topic, path, from}, state) do
    {:ok, view} = fetch_view_by_topic(state, topic)
    GenServer.reply(from, {:ok, state.html |> DOM.outer_html([view.id | path]) |> DOM.to_html()})
    {:noreply, state}
  end

  def handle_info(
        %Phoenix.Socket.Message{
          event: "redirect",
          topic: _topic,
          payload: %{to: _to} = opts
        },
        state
      ) do
    send_redirect(state, state.root_view.topic, opts)
    {:noreply, state}
  end

  def handle_info(
        %Phoenix.Socket.Message{
          event: "live_patch",
          topic: _topic,
          payload: %{to: _to} = opts
        },
        state
      ) do
    send_redirect(state, state.root_view.topic, opts)
    {:noreply, state}
  end

  def handle_info(
        %Phoenix.Socket.Message{
          event: "live_redirect",
          topic: _topic,
          payload: %{to: _to} = opts
        },
        state
      ) do
    send_redirect(state, state.root_view.topic, opts)
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

    case fetch_reply(state, ref) do
      {:ok, {from, _pid}} ->
        state = drop_reply(state, ref)

        case payload do
          %{live_redirect: %{to: _to} = opts} ->
            send_redirect(state, topic, opts)
            GenServer.reply(from, {:error, {:live_redirect, opts}})
            {:noreply, state}

          %{live_patch: %{to: _to} = opts} ->
            send_redirect(state, topic, opts)
            {:noreply, render_reply(reply, from, state)}

          %{redirect: %{to: _to} = opts} ->
            send_redirect(state, topic, opts)
            GenServer.reply(from, {:error, {:redirect, opts}})
            {:noreply, state}

          %{} ->
            {:noreply, render_reply(reply, from, state)}
        end

      :error ->
        {:noreply, state}
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

  def handle_call({:stop, topic}, _from, state) do
    case fetch_view_by_topic(state, topic) do
      {:ok, view} ->
        {:reply, :ok, drop_view_by_id(state, view.id, :stop)}

      :error ->
        {:reply, :ok, state}
    end
  end

  def handle_call({:children, topic}, from, state) do
    case fetch_view_by_topic(state, topic) do
      {:ok, view} ->
        :ok = Phoenix.LiveView.Channel.ping(view.pid)
        send(self(), {:sync_children, view.topic, from})
        {:noreply, state}

      :error ->
        {:reply, {:error, :removed}, state}
    end
  end

  def handle_call({:render_tree, topic, path}, from, state) do
    {:ok, view} = fetch_view_by_topic(state, topic)
    :ok = Phoenix.LiveView.Channel.ping(view.pid)
    send(self(), {:sync_render, topic, path, from})
    {:noreply, state}
  end

  def handle_call({:render_event, topic, type, path, event, raw_val}, from, state) do
    {:ok, view} = fetch_view_by_topic(state, topic)

    payload =
      maybe_add_cid_to_payload(view, path, %{
        "value" => raw_val,
        "event" => to_string(event),
        "type" => to_string(type)
      })

    {:noreply, push_with_reply(state, from, view, "event", payload)}
  end

  def handle_call({:render_patch, topic, path}, from, state) do
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

  defp put_child(state, %ClientProxy{} = parent, id, session) do
    update_in(state, [:views, parent.topic], fn %ClientProxy{} = parent ->
      %ClientProxy{parent | children: [{id, session} | parent.children]}
    end)
  end

  defp drop_child(state, %ClientProxy{} = parent, id, reason) do
    state
    |> update_in([:views, parent.topic], fn %ClientProxy{} = parent ->
      %ClientProxy{
        parent
        | children: Enum.reject(parent.children, fn {cid, _session} -> id == cid end)
      }
    end)
    |> drop_view_by_id(id, reason)
  end

  defp verify_session(%ClientProxy{} = view) do
    Phoenix.LiveView.Static.verify_session(view.endpoint, view.session_token, view.static_token)
  end

  defp put_view(state, %ClientProxy{} = view, pid, rendered) do
    {:ok, %{view: module}} = verify_session(view)
    new_view = %ClientProxy{view | module: module, proxy: self(), pid: pid, rendered: rendered}
    Process.monitor(pid)

    patch_view(
      %{
        state
        | views: Map.put(state.views, new_view.topic, new_view),
          pids: Map.put(state.pids, pid, new_view.topic),
          ids: Map.put(state.ids, new_view.id, new_view.topic)
      },
      view,
      DOM.render_diff(rendered)
    )
  end

  defp patch_view(state, view, child_html) do
    case DOM.patch_id(view.id, state.html, child_html) do
      {new_html, [_ | _] = deleted_cids, deleted_cid_ids} ->
        for id <- deleted_cid_ids,
            do: send_caller(state, {:removed_component, view.topic, id})

        push(%{state | html: new_html}, view, "cids_destroyed", %{"cids" => deleted_cids})

      {new_html, [] = _deleted_cids, [] = _deleted_cid_ids} ->
        %{state | html: new_html}
    end
  end

  defp drop_downed_view(state, pid, reason) when is_pid(pid) do
    {:ok, view} = fetch_view_by_pid(state, pid)
    send_caller(state, {:removed, view.topic, reason})

    flush_replies(
      %{
        state
        | ids: Map.delete(state.ids, view.id),
          views: Map.delete(state.views, view.topic),
          pids: Map.delete(state.pids, view.pid)
      },
      pid,
      reason
    )
  end

  defp drop_view_by_id(state, id, reason) do
    {:ok, view} = fetch_view_by_id(state, id)
    :ok = shutdown_view(view, reason)

    Enum.reduce(view.children, state, fn {child_id, _child_session}, acc ->
      drop_child(acc, view, child_id, reason)
    end)
  end

  defp fetch_view_by_topic(state, topic), do: Map.fetch(state.views, topic)

  defp fetch_view_by_pid(state, pid) when is_pid(pid) do
    with {:ok, topic} <- Map.fetch(state.pids, pid) do
      fetch_view_by_topic(state, topic)
    end
  end

  defp fetch_view_by_id(state, id) do
    with {:ok, topic} <- Map.fetch(state.ids, id) do
      fetch_view_by_topic(state, topic)
    end
  end

  defp drop_all_views(state, reason) do
    Enum.reduce(state.views, state, fn {_topic, view}, acc ->
      drop_view_by_id(acc, view.id, reason)
    end)
  end

  defp render_reply(reply, from, state) do
    %{payload: diff, topic: topic} = reply
    new_state = merge_rendered(state, topic, diff)

    case fetch_view_by_topic(new_state, topic) do
      {:ok, view} ->
        GenServer.reply(from, {:ok, new_state.html |> DOM.inner_html(view.id) |> DOM.to_html()})
        new_state

      :error ->
        new_state
    end
  end

  defp merge_rendered(state, topic, %{diff: diff}), do: merge_rendered(state, topic, diff)

  defp merge_rendered(%{html: html_before} = state, topic, %{} = diff) do
    case diff do
      %{title: new_title} -> send_caller(state, {:title, new_title})
      %{} -> :noop
    end

    case fetch_view_by_topic(state, topic) do
      {:ok, view} ->
        rendered = DOM.deep_merge(view.rendered, diff)
        new_view = %ClientProxy{view | rendered: rendered}

        %{state | views: Map.update!(state.views, topic, fn _ -> new_view end)}
        |> patch_view(new_view, DOM.render_diff(rendered))
        |> detect_added_or_removed_children(new_view, html_before)

      :error ->
        state
    end
  end

  defp detect_added_or_removed_children(state, view, html_before) do
    try do
      recursive_detect_added_or_removed_children(state, view, html_before)
    catch
      :throw, {:stop, {:redirect, view, to}, new_state} ->
        send_redirect(new_state, view.topic, %{to: to})
        drop_all_views(new_state, :redirected)
    else
      new_state ->
        {:ok, new_view} = fetch_view_by_topic(new_state, view.topic)

        ids_after =
          new_state.html
          |> DOM.all("[data-phx-view]")
          |> DOM.all_attributes("id")
          |> Enum.reduce(%{}, fn id, seen ->
            if Map.has_key?(seen, id) do
              raise "duplicate LiveView id: #{inspect(id)}"
            else
              Map.put(seen, id, true)
            end
          end)

        Enum.reduce(new_view.children, new_state, fn {id, _session}, acc ->
          if Map.has_key?(ids_after, id) do
            acc
          else
            drop_child(acc, new_view, id, :removed)
          end
        end)
    end
  end

  defp recursive_detect_added_or_removed_children(state, view, html_before) do
    state.html
    |> DOM.inner_html(view.id)
    |> DOM.find_live_views()
    |> Enum.reduce(state, fn {id, session, static}, acc ->
      case fetch_view_by_id(acc, id) do
        {:ok, view} ->
          {_, _, inner_html} = DOM.by_id!(html_before, view.id)
          patch_view(acc, view, inner_html)

        :error ->
          static = static || Map.get(state.root_view.child_statics, id)

          child_view = build_child(view, id: id, session_token: session, static_token: static)

          acc
          |> mount_view(child_view, acc.timeout, nil)
          |> case do
            {:ok, pid, rendered} ->
              acc
              |> put_view(child_view, pid, rendered)
              |> put_child(view, id, child_view.session_token)
              |> recursive_detect_added_or_removed_children(child_view, acc.html)

            {:error, %{live_redirect: %{to: to}}} ->
              throw({:stop, {:redirect, view, to}, acc})

            {:error, %{redirect: %{to: to}}} ->
              throw({:stop, {:redirect, view, to}, acc})

            {:error, reason} ->
              raise "failed to mount view: #{Exception.format_exit(reason)}"
          end
      end
    end)
  end

  defp shutdown_view(%ClientProxy{pid: pid}, reason) do
    Process.exit(pid, {:shutdown, reason})
    :ok
  end

  defp send_caller(%{caller: {pid, ref}}, msg) when is_pid(pid) do
    send(pid, {ref, msg})
  end

  defp send_redirect(state, topic, %{to: _to} = opts) do
    send_caller(state, {:redirect, topic, opts})
  end

  defp push(state, view, event, payload) do
    ref = to_string(state.ref + 1)

    send(view.pid, %Phoenix.Socket.Message{
      join_ref: state.join_ref,
      topic: view.topic,
      event: event,
      payload: payload,
      ref: ref
    })

    %{state | ref: state.ref + 1}
  end

  defp push_with_reply(state, from, view, event, payload) do
    ref = to_string(state.ref + 1)

    state
    |> push(view, event, payload)
    |> put_reply(ref, from, view.pid)
  end

  def build(attrs) do
    attrs_with_defaults =
      attrs
      |> Keyword.merge(topic: Phoenix.LiveView.Utils.random_id())
      |> Keyword.put_new_lazy(:ref, fn -> make_ref() end)

    struct(__MODULE__, attrs_with_defaults)
  end

  def build_child(%ClientProxy{ref: ref, proxy: proxy} = parent, attrs) do
    attrs
    |> Keyword.merge(
      ref: ref,
      proxy: proxy,
      endpoint: parent.endpoint
    )
    |> build()
  end

  defp maybe_add_cid_to_payload(_view, [], payload), do: payload

  defp maybe_add_cid_to_payload(view, [_ | _] = ids, payload) do
    id = List.last(ids)
    cid = DOM.cid_by_id(view.rendered, id)

    if cid && DOM.by_id!(DOM.render_diff(view.rendered), ids) do
      Map.put(payload, "cid", cid)
    else
      raise ArgumentError,
            "no component with ID \"#{id}\" found in view #{inspect(view.module)}"
    end
  end
end
