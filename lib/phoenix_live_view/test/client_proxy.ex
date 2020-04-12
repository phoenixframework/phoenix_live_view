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

  alias Phoenix.LiveViewTest.{ClientProxy, DOM, Element, View}

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
    root_view = Keyword.fetch!(opts, :proxy)
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
        try do
          state
          |> put_view(root_view, pid, rendered)
          |> detect_added_or_removed_children(root_view, root_html)
        catch
          :throw, {:stop, {:shutdown, reason}, _} ->
            send_caller(state, {:error, reason})
            :ignore
        else
          new_state ->
            send_caller(new_state, {:ok, build_view(root_view, pid), DOM.to_html(new_state.html)})
            {:ok, new_state}
        end

      {:error, reason} ->
        send_caller(state, {:error, reason})
        :ignore
    end
  end

  defp build_view(%ClientProxy{} = proxy, view_pid) do
    %{id: id, ref: ref, topic: topic, module: module, endpoint: endpoint} = proxy
    %View{id: id, pid: view_pid, proxy: {ref, topic, self()}, module: module, endpoint: endpoint}
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
            {:error, reason}

          {:DOWN, ^mon_ref, _, _, reason} ->
            {:error, reason}
        after
          timeout -> exit(:timeout)
        end

      {:error, reason} ->
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
    view = fetch_view_by_topic!(state, topic)

    children =
      Enum.flat_map(view.children, fn {id, _session} ->
        case fetch_view_by_id(state, id) do
          {:ok, child} -> [build_view(child, child.pid)]
          :error -> []
        end
      end)

    GenServer.reply(from, {:ok, children})
    {:noreply, state}
  end

  def handle_info({:sync_render, view_or_element, from}, state) do
    view = fetch_view_by_topic!(state, proxy_topic(view_or_element))

    result =
      case state |> root(view) |> select_node(view_or_element) do
        {:ok, node} -> {:ok, DOM.to_html(node)}
        {:error, message} -> {:raise, ArgumentError.exception(message)}
      end

    GenServer.reply(from, result)
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
    stop_redirect(state, state.root_view.topic, {:redirect, opts})
  end

  def handle_info(
        %Phoenix.Socket.Message{
          event: "live_patch",
          topic: _topic,
          payload: %{to: _to} = opts
        },
        state
      ) do
    send_patch(state, state.root_view.topic, opts)
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
    stop_redirect(state, state.root_view.topic, {:live_redirect, opts})
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
            stop_redirect(state, topic, {:live_redirect, opts}, from)

          %{live_patch: %{to: _to} = opts} ->
            send_patch(state, topic, opts)
            {:noreply, render_reply(reply, from, state)}

          %{redirect: %{to: _to} = opts} ->
            stop_redirect(state, topic, {:redirect, opts}, from)

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

  def handle_call({:live_children, topic}, from, state) do
    case fetch_view_by_topic(state, topic) do
      {:ok, view} ->
        :ok = Phoenix.LiveView.Channel.ping(view.pid)
        send(self(), {:sync_children, view.topic, from})
        {:noreply, state}

      :error ->
        {:reply, {:error, :removed}, state}
    end
  end

  def handle_call({:render_tree, view_or_element}, from, state) do
    topic = proxy_topic(view_or_element)
    %{pid: pid} = fetch_view_by_topic!(state, topic)
    :ok = Phoenix.LiveView.Channel.ping(pid)
    send(self(), {:sync_render, view_or_element, from})
    {:noreply, state}
  end

  def handle_call({:render_event, view_or_element, type, value}, from, state) do
    result =
      case view_or_element do
        # TODO: Remove me once paths are removed
        {view, [_ | _] = path, event} ->
          view = fetch_view_by_topic!(state, proxy_topic(view))
          root = root(state, view)

          with {:ok, node} <- DOM.maybe_one(root, Enum.join(path, " ")),
               {:ok, cid} <- maybe_cid(root, node) do
            {view, cid, event, %{}}
          end

        {view, [], event} ->
          view = fetch_view_by_topic!(state, proxy_topic(view))
          {view, nil, event, %{}}

        %Element{} = element ->
          view = fetch_view_by_topic!(state, proxy_topic(element))
          root = root(state, view)

          with {:ok, node} <- select_node(root, element),
               {:ok, event} <- maybe_event(type, node, element),
               {:ok, cid} <- maybe_cid(root, node) do
            {view, cid, event, DOM.all_values(node)}
          end
      end

    case result do
      {view, cid, event, extra} ->
        payload = %{
          "cid" => cid,
          "type" => Atom.to_string(type),
          "event" => event,
          "value" => encode(type, DOM.deep_merge(extra, stringify(value)))
        }

        {:noreply, push_with_reply(state, from, view, "event", payload)}

      {:stop, topic, reason} ->
        stop_redirect(state, topic, reason, from)

      {:error, message} ->
        {:reply, {:raise, ArgumentError.exception(message)}, state}
    end
  end

  def handle_call({:render_patch, topic, path}, from, state) do
    view = fetch_view_by_topic!(state, topic)
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
      new_children = Enum.reject(parent.children, fn {cid, _session} -> id == cid end)
      %ClientProxy{parent | children: new_children}
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
            do: send_caller(state, {:removed_component, view.topic, "#" <> id})

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

  defp stop_redirect(%{caller: {pid, _}} = state, topic, {_kind, opts} = reason, from \\ nil)
       when is_binary(topic) do
    # First emit the redirect to avoid races between a render command
    # returning {:error, redirect} but the redirect is not yet in its
    # inbox.
    send_caller(state, {:redirect, topic, opts})

    # Then we will reply with the actual reason. However, because in
    # some cases the redirect may be sent off-band, the client still
    # needs to catch any redirect server shutdown.
    from && GenServer.reply(from, {:error, reason})

    # Now we are ready to shutdown but unlink to avoid caller crashes.
    Process.unlink(pid)
    {:stop, {:shutdown, reason}, state}
  end

  defp fetch_view_by_topic!(state, topic), do: Map.fetch!(state.views, topic)
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

  defp render_reply(reply, from, state) do
    %{payload: diff, topic: topic} = reply
    new_state = merge_rendered(state, topic, diff)

    case fetch_view_by_topic(new_state, topic) do
      {:ok, view} ->
        GenServer.reply(from, {:ok, new_state.html |> DOM.inner_html!(view.id) |> DOM.to_html()})
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
    new_state = recursive_detect_added_or_removed_children(state, view, html_before)
    {:ok, new_view} = fetch_view_by_topic(new_state, view.topic)

    ids_after =
      new_state.html
      |> DOM.all("[data-phx-view]")
      |> DOM.all_attributes("id")
      |> MapSet.new()

    Enum.reduce(new_view.children, new_state, fn {id, _session}, acc ->
      if id in ids_after do
        acc
      else
        drop_child(acc, new_view, id, :removed)
      end
    end)
  end

  defp recursive_detect_added_or_removed_children(state, view, html_before) do
    state.html
    |> DOM.inner_html!(view.id)
    |> DOM.find_live_views()
    |> Enum.reduce(state, fn {id, session, static}, acc ->
      case fetch_view_by_id(acc, id) do
        {:ok, view} ->
          patch_view(acc, view, DOM.inner_html!(html_before, view.id))

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

            {:error, %{live_redirect: opts}} ->
              throw(stop_redirect(acc, view.topic, {:live_redirect, opts}))

            {:error, %{redirect: opts}} ->
              throw(stop_redirect(acc, view.topic, {:redirect, opts}))

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

  defp send_patch(state, topic, %{to: _to} = opts) do
    send_caller(state, {:patch, topic, opts})
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

  ## Element helpers

  defp proxy_topic(%View{proxy: {_ref, topic, _pid}}), do: topic
  defp proxy_topic(%Element{view: view}), do: proxy_topic(view)

  defp root(state, view), do: DOM.by_id!(state.html, view.id)

  defp select_node(root, %View{}) do
    {:ok, root}
  end

  defp select_node(root, %Element{selector: selector, text_filter: nil}) do
    root
    |> DOM.child_nodes()
    |> DOM.maybe_one(selector)
  end

  defp select_node(root, %Element{selector: selector, text_filter: text_filter}) do
    nodes =
      root
      |> DOM.child_nodes()
      |> DOM.all(selector)

    filtered_nodes = Enum.filter(nodes, &(DOM.to_text(&1) =~ text_filter))

    case {nodes, filtered_nodes} do
      {_, [filtered_node]} ->
        {:ok, filtered_node}

      {[], _} ->
        {:error, "selector #{inspect(selector)} did not return any element"}

      {[node], []} ->
        {:error,
         "selector #{inspect(selector)} did not match text filter #{inspect(text_filter)}, " <>
           "got: #{inspect(DOM.to_text(node))}"}

      {_, []} ->
        {:error,
         "selector #{inspect(selector)} returned #{length(nodes)} elements " <>
           "but none matched the text filter #{inspect(text_filter)}"}

      {_, _} ->
        {:error,
         "selector #{inspect(selector)} returned #{length(nodes)} elements " <>
           "and #{length(filtered_nodes)} of them matched the text filter #{inspect(text_filter)}"}
    end
  end

  defp maybe_cid(_tree, nil) do
    {:ok, nil}
  end

  defp maybe_cid(tree, node) do
    case DOM.all_attributes(node, "phx-target") do
      [] ->
        {:ok, nil}

      ["#" <> _ = target] ->
        with {:ok, target} <- DOM.maybe_one(tree, target, "phx-target") do
          if cid = DOM.component_id(target) do
            {:ok, String.to_integer(cid)}
          else
            {:ok, nil}
          end
        end

      [maybe_integer] ->
        case Integer.parse(maybe_integer) do
          {cid, ""} ->
            {:ok, cid}

          _ ->
            {:error,
             "expected phx-target to be either an ID or a CID, got: #{inspect(maybe_integer)}"}
        end
    end
  end

  defp maybe_event(:click, {"a", attrs, _}, element) do
    case List.keyfind(attrs, "phx-click", 0) do
      {_, value} ->
        {:ok, value}

      _ ->
        case List.keyfind(attrs, "href", 0) do
          {_, to} ->
            {:stop, proxy_topic(element), {:redirect, %{to: to}}}

          _ ->
            {:error,
             "link selected by #{inspect(element.selector)} does not have phx-click nor a href atribute"}
        end
    end
  end

  defp maybe_event(type, {_, attrs, _}, element) do
    case List.keyfind(attrs, "phx-#{type}", 0) do
      {_, value} ->
        {:ok, value}

      _ ->
        {:error,
         "element selected by #{inspect(element.selector)} does not have phx-#{type} attribute"}
    end
  end

  defp encode(:form, value), do: Plug.Conn.Query.encode(value)
  defp encode(_, value), do: value

  defp stringify(%{__struct__: _} = struct),
    do: struct

  defp stringify(%{} = params),
    do: Enum.into(params, %{}, &stringify_kv/1)

  defp stringify(other),
    do: other

  defp stringify_kv({k, v}),
    do: {to_string(k), stringify(v)}
end
