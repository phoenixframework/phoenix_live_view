defmodule Phoenix.LiveViewTest.ClientProxy do
  @moduledoc false
  use GenServer

  @data_phx_upload_ref "data-phx-upload-ref"
  @events :e
  @title :t
  @reply :r

  defstruct session_token: nil,
            static_token: nil,
            module: nil,
            endpoint: nil,
            router: nil,
            pid: nil,
            proxy: nil,
            topic: nil,
            ref: nil,
            rendered: nil,
            children: [],
            child_statics: %{},
            id: nil,
            uri: nil,
            connect_params: %{},
            connect_info: %{}

  alias Phoenix.LiveViewTest.{ClientProxy, DOM, Element, View, Upload}

  @doc """
  Encoding used by the Channel serializer.
  """
  def encode!(msg), do: msg

  @doc """
  Stops the client proxy gracefully.
  """
  def stop(proxy_pid, reason) do
    GenServer.call(proxy_pid, {:stop, reason})
  end

  @doc """
  Returns the tokens of the root view.
  """
  def root_view(proxy_pid) do
    GenServer.call(proxy_pid, :root_view)
  end

  @doc """
  Reports upload progress to the proxy.
  """
  def report_upload_progress(proxy_pid, from, element, entry_ref, percent, cid) do
    GenServer.call(proxy_pid, {:upload_progress, from, element, entry_ref, percent, cid})
  end

  @doc """
  Starts a client proxy.

  ## Options

    * `:caller` - the required `{ref, pid}` pair identifying the caller.
    * `:view` - the required `%Phoenix.LiveViewTest.View{}`
    * `:html` - the required string of HTML for the document.

  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    # Since we are always running in the test client, we will disable
    # our own logging and let the client do the job.
    Logger.disable(self())

    %{
      caller: {_, ref} = caller,
      html: response_html,
      connect_params: connect_params,
      connect_info: connect_info,
      live_module: module,
      endpoint: endpoint,
      router: router,
      session: session,
      url: url,
      test_supervisor: test_supervisor
    } = opts

    # We can assume there is at least one LiveView
    # because the live_module assign was set.
    root_html = DOM.parse(response_html)

    {id, session_token, static_token, redirect_url} =
      case Map.fetch(opts, :live_redirect) do
        {:ok, {id, session_token, static_token}} ->
          {id, session_token, static_token, url}

        :error ->
          [{id, session_token, static_token} | _] = DOM.find_live_views(root_html)
          {id, session_token, static_token, nil}
      end

    root_view = %ClientProxy{
      id: id,
      ref: ref,
      connect_params: connect_params,
      connect_info: connect_info,
      session_token: session_token,
      static_token: static_token,
      module: module,
      endpoint: endpoint,
      router: router,
      uri: URI.parse(url),
      child_statics: Map.delete(DOM.find_static_views(root_html), id),
      topic: "lv:#{id}"
    }

    # We build an absolute path to any relative
    # static assets through the root LiveView's endpoint.
    priv_dir = :otp_app |> endpoint.config() |> Application.app_dir("priv")
    static_url = endpoint.config(:static_url) || []

    static_path =
      case Keyword.get(static_url, :path) do
        nil ->
          Path.join(priv_dir, "static")

        _path ->
          priv_dir
      end

    state = %{
      join_ref: 0,
      ref: 0,
      caller: caller,
      views: %{},
      ids: %{},
      pids: %{},
      replies: %{},
      root_view: nil,
      html: root_html,
      static_path: static_path,
      session: session,
      test_supervisor: test_supervisor,
      url: url,
      page_title: root_page_title(root_html)
    }

    try do
      {root_view, rendered, resp} = mount_view(state, root_view, url, redirect_url)

      new_state =
        state
        |> maybe_put_container(resp)
        |> Map.put(:root_view, root_view)
        |> put_view(root_view, rendered)
        |> detect_added_or_removed_children(root_view, root_html)

      send_caller(new_state, {:ok, build_client_view(root_view), DOM.to_html(new_state.html)})
      {:ok, new_state}
    catch
      :throw, {:stop, {:shutdown, reason}, _state} ->
        send_caller(state, {:error, reason})
        :ignore

      :throw, {:stop, reason, _} ->
        Process.unlink(elem(caller, 0))
        {:stop, reason}
    end
  end

  defp maybe_put_container(state, %{container: container}) do
    [tag, attrs] = container
    %{state | html: DOM.replace_root_container(state.html, tag, attrs)}
  end

  defp maybe_put_container(state, %{} = _resp), do: state

  defp build_client_view(%ClientProxy{} = proxy) do
    %{id: id, ref: ref, topic: topic, module: module, endpoint: endpoint, pid: pid} = proxy
    %View{id: id, pid: pid, proxy: {ref, topic, self()}, module: module, endpoint: endpoint}
  end

  defp mount_view(state, view, url, redirect_url) do
    ref = make_ref()

    case start_supervised_channel(state, view, ref, url, redirect_url) do
      {:ok, pid} ->
        mon_ref = Process.monitor(pid)

        receive do
          {^ref, {:ok, %{rendered: rendered} = resp}} ->
            Process.demonitor(mon_ref, [:flush])
            {%{view | pid: pid}, DOM.merge_diff(%{}, rendered), resp}

          {^ref, {:error, %{live_redirect: opts}}} ->
            throw(stop_redirect(state, view.topic, {:live_redirect, opts}))

          {^ref, {:error, %{redirect: opts}}} ->
            throw(stop_redirect(state, view.topic, {:redirect, opts}))

          {^ref, {:error, %{reason: reason}}} when reason in ~w(stale unauthorized) ->
            redir_to =
              case redirect_url do
                %URI{} = uri -> URI.to_string(uri)
                nil -> url
              end

            throw(stop_redirect(state, view.topic, {:redirect, %{to: redir_to}}))

          {^ref, {:error, reason}} ->
            throw({:stop, reason, state})

          {:DOWN, ^mon_ref, _, _, reason} ->
            throw({:stop, reason, state})
        end

      {:error, reason} ->
        throw({:stop, reason, state})
    end
  end

  defp start_supervised_channel(state, view, ref, url, redirect_url) do
    socket = %Phoenix.Socket{
      transport_pid: self(),
      serializer: __MODULE__,
      channel: view.module,
      endpoint: view.endpoint,
      private: %{connect_info: Map.put_new(view.connect_info, :session, state.session)},
      topic: view.topic,
      join_ref: state.join_ref
    }

    params = %{
      "session" => view.session_token,
      "static" => view.static_token,
      "params" => Map.put(view.connect_params, "_mounts", 0),
      "caller" => state.caller
    }

    params = put_non_nil(params, "url", url)
    params = put_non_nil(params, "redirect", redirect_url)

    from = {self(), ref}

    spec = %{
      id: make_ref(),
      start: {Phoenix.LiveView.Channel, :start_link, [{view.endpoint, from}]},
      restart: :temporary
    }

    with {:ok, pid} <- Supervisor.start_child(state.test_supervisor, spec) do
      send(pid, {Phoenix.Channel, params, from, socket})
      {:ok, pid}
    end
  end

  defp put_non_nil(%{} = map, _key, nil), do: map
  defp put_non_nil(%{} = map, key, val), do: Map.put(map, key, val)

  def handle_info({:sync_children, topic, from}, state) do
    view = fetch_view_by_topic!(state, topic)

    children =
      Enum.flat_map(view.children, fn {id, _session} ->
        case fetch_view_by_id(state, id) do
          {:ok, child} -> [build_client_view(child)]
          :error -> []
        end
      end)

    GenServer.reply(from, {:ok, children})
    {:noreply, state}
  end

  def handle_info({:sync_render_element, operation, topic_or_element, from}, state) do
    view = fetch_view_by_topic!(state, proxy_topic(topic_or_element))
    result = state |> root(view) |> select_node(topic_or_element)

    reply =
      case {operation, result} do
        {:find_element, {:ok, node}} -> {:ok, node}
        {:find_element, {:error, _, message}} -> {:raise, ArgumentError.exception(message)}
        {:has_element?, {:error, :none, _}} -> {:ok, false}
        {:has_element?, _} -> {:ok, true}
      end

    GenServer.reply(from, reply)
    {:noreply, state}
  end

  def handle_info({:sync_render_event, topic_or_element, type, value, from}, state) do
    result =
      case topic_or_element do
        {topic, event, selector} ->
          view = fetch_view_by_topic!(state, topic)

          cids =
            if selector, do: DOM.targets_from_selector(root(state, view), selector), else: [nil]

          case value do
            %Upload{} = upload ->
              {view, cids, event, %{}, upload}

            other ->
              {view, cids, event, stringify(other, & &1), nil}
          end

        %Element{} = element ->
          view = fetch_view_by_topic!(state, proxy_topic(element))
          root = root(state, view)

          with {:ok, node} <- select_node(root, element),
               :ok <- maybe_enabled(type, node, element),
               {:ok, event} <- maybe_event(type, node, element),
               {:ok, extra} <- maybe_values(type, node, element) do
            {values, uploads} =
              case value do
                %Upload{} = upload -> {extra, upload}
                other -> {DOM.deep_merge(extra, stringify(other, & &1)), nil}
              end

            {view, DOM.targets_from_node(root, node), event, values, uploads}
          end
      end

    case result do
      {view, cids, event, values, upload} when is_list(cids) ->
        last = length(cids) - 1

        diffs =
          cids
          |> Enum.with_index()
          |> Enum.reduce(state, fn {cid, index}, acc ->
            {type, encoded_value} = encode_event_type(type, values)

            payload =
              maybe_put_uploads(
                state,
                view,
                %{
                  "cid" => cid,
                  "type" => type,
                  "event" => event,
                  "value" => encoded_value
                },
                upload
              )

            push_with_callback(acc, view, "event", payload, fn reply, state ->
              if index == last do
                {:noreply, render_reply(reply, from, state)}
              else
                {:noreply, state}
              end
            end)
          end)

        {:noreply, diffs}

      {:allow_upload, topic, ref} ->
        handle_call({:render_allow_upload, topic, ref, value}, from, state)

      {:upload_progress, topic, upload_ref} ->
        payload = Map.put(value, "ref", upload_ref)
        view = fetch_view_by_topic!(state, topic)
        {:noreply, push_with_reply(state, from, view, "progress", payload)}

      {:patch, topic, path} ->
        handle_call({:render_patch, topic, path}, from, state)

      {:stop, topic, reason} ->
        stop_redirect(state, topic, reason)

      {:error, _, message} ->
        GenServer.reply(from, {:raise, ArgumentError.exception(message)})
        {:noreply, state}
    end
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

  def handle_info(%Phoenix.Socket.Reply{ref: ref} = reply, state) do
    case fetch_reply(state, ref) do
      {:ok, {_pid, callback}} ->
        case handle_reply(state, reply) do
          {:ok, new_state} -> callback.(reply, drop_reply(new_state, ref))
          other -> other
        end

      :error ->
        {:noreply, state}
    end
  end

  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    case fetch_view_by_pid(state, pid) do
      {:ok, _view} ->
        {:stop, reason, state}

      :error ->
        {:noreply, state}
    end
  end

  def handle_info({:socket_close, pid, reason}, state) do
    case fetch_view_by_pid(state, pid) do
      {:ok, view} ->
        {:noreply, drop_view_by_id(state, view.id, reason)}

      :error ->
        {:noreply, state}
    end
  end

  def handle_call({:upload_progress, from, %Element{} = el, entry_ref, progress, cid}, _, state) do
    payload = put_cid(%{"entry_ref" => entry_ref, "progress" => progress}, cid)
    topic = proxy_topic(el)
    %{pid: pid} = fetch_view_by_topic!(state, topic)
    :ok = Phoenix.LiveView.Channel.ping(pid)
    send(self(), {:sync_render_event, el, :upload_progress, payload, from})
    {:reply, :ok, state}
  end

  def handle_call(:page_title, _from, state) do
    {:reply, {:ok, state.page_title}, state}
  end

  def handle_call(:url, _from, state) do
    {:reply, {:ok, state.url}, state}
  end

  def handle_call(:html, _from, state) do
    {:reply, {:ok, {state.html, state.static_path}}, state}
  end

  def handle_call(:root_view, _from, state) do
    {:reply, {state.session, state.root_view}, state}
  end

  def handle_call({:live_children, topic}, from, state) do
    view = fetch_view_by_topic!(state, topic)
    :ok = Phoenix.LiveView.Channel.ping(view.pid)
    send(self(), {:sync_children, view.topic, from})
    {:noreply, state}
  end

  def handle_call({:render_element, operation, topic_or_element}, from, state) do
    topic = proxy_topic(topic_or_element)
    %{pid: pid} = fetch_view_by_topic!(state, topic)
    :ok = Phoenix.LiveView.Channel.ping(pid)
    send(self(), {:sync_render_element, operation, topic_or_element, from})
    {:noreply, state}
  end

  def handle_call({:render_event, topic_or_element, type, value}, from, state) do
    topic = proxy_topic(topic_or_element)
    %{pid: pid} = fetch_view_by_topic!(state, topic)
    :ok = Phoenix.LiveView.Channel.ping(pid)
    send(self(), {:sync_render_event, topic_or_element, type, value, from})
    {:noreply, state}
  end

  def handle_call({:render_patch, topic, path}, from, state) do
    view = fetch_view_by_topic!(state, topic)
    state = push_with_reply(state, from, view, "live_patch", %{"url" => path})
    send_patch(state, state.root_view.topic, %{to: path})
    {:noreply, state}
  end

  def handle_call({:render_allow_upload, topic, ref, {entries, cid}}, from, state) do
    view = fetch_view_by_topic!(state, topic)
    payload = put_cid(%{"ref" => ref, "entries" => entries}, cid)

    new_state =
      push_with_callback(
        state,
        view,
        "allow_upload",
        payload,
        fn reply, state ->
          GenServer.reply(from, {:ok, reply.payload})
          {:noreply, state}
        end
      )

    {:noreply, new_state}
  end

  def handle_call({:stop, reason}, _from, state) do
    %{caller: {pid, _}} = state
    Process.unlink(pid)
    {:stop, :ok, reason, state}
  end

  defp drop_view_by_id(state, id, reason) do
    {:ok, view} = fetch_view_by_id(state, id)
    push(state, view, "phx_leave", %{})

    state =
      Enum.reduce(view.children, state, fn {child_id, _child_session}, acc ->
        drop_view_by_id(acc, child_id, reason)
      end)

    flush_replies(
      %{
        state
        | ids: Map.delete(state.ids, view.id),
          views: Map.delete(state.views, view.topic),
          pids: Map.delete(state.pids, view.pid)
      },
      view.pid
    )
  end

  defp flush_replies(state, pid) do
    Enum.reduce(state.replies, state, fn
      {ref, {^pid, _callback}}, acc -> drop_reply(acc, ref)
      {_ref, {_pid, _callback}}, acc -> acc
    end)
  end

  defp fetch_reply(state, ref) do
    Map.fetch(state.replies, ref)
  end

  defp put_reply(state, ref, pid, callback) do
    %{state | replies: Map.put(state.replies, ref, {pid, callback})}
  end

  defp drop_reply(state, ref) do
    %{state | replies: Map.delete(state.replies, ref)}
  end

  defp put_child(state, %ClientProxy{} = parent, id, session) do
    update_in(state.views[parent.topic], fn %ClientProxy{} = parent ->
      %ClientProxy{parent | children: [{id, session} | parent.children]}
    end)
  end

  defp drop_child(state, %ClientProxy{} = parent, id, reason) do
    update_in(state.views[parent.topic], fn %ClientProxy{} = parent ->
      new_children = Enum.reject(parent.children, fn {cid, _session} -> id == cid end)
      %ClientProxy{parent | children: new_children}
    end)
    |> drop_view_by_id(id, reason)
  end

  defp verify_session(%ClientProxy{} = view) do
    Phoenix.LiveView.Session.verify_session(
      view.endpoint,
      view.topic,
      view.session_token,
      view.static_token
    )
  end

  defp put_view(state, %ClientProxy{pid: pid} = view, rendered) do
    {:ok, %Phoenix.LiveView.Session{view: module}} = verify_session(view)
    new_view = %ClientProxy{view | module: module, proxy: self(), pid: pid, rendered: rendered}
    Process.monitor(pid)

    rendered = maybe_push_events(rendered, state)

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
      {new_html, [_ | _] = will_destroy_cids} ->
        topic = view.topic
        state = %{state | html: new_html}
        payload = %{"cids" => will_destroy_cids}

        push_with_callback(state, view, "cids_will_destroy", payload, fn _, state ->
          still_there_cids = DOM.component_ids(view.id, state.html)
          payload = %{"cids" => Enum.reject(will_destroy_cids, &(&1 in still_there_cids))}

          state =
            push_with_callback(state, view, "cids_destroyed", payload, fn reply, state ->
              cids = reply.payload.cids
              {:noreply, update_in(state.views[topic].rendered, &DOM.drop_cids(&1, cids))}
            end)

          {:noreply, state}
        end)

      {new_html, [] = _deleted_cids} ->
        %{state | html: new_html}
    end
  end

  defp stop_redirect(%{caller: {pid, _}} = state, topic, {_kind, opts} = reason)
       when is_binary(topic) do
    send_caller(state, {:redirect, topic, opts})
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
    case fetch_view_by_topic(state, reply.topic) do
      {:ok, view} ->
        GenServer.reply(from, {:ok, state.html |> DOM.inner_html!(view.id) |> DOM.to_html()})
        state

      :error ->
        state
    end
  end

  defp merge_rendered(state, topic, %{diff: diff}), do: merge_rendered(state, topic, diff)

  defp merge_rendered(%{html: html_before} = state, topic, %{} = diff) do
    {diff, state} =
      diff
      |> maybe_push_events(state)
      |> maybe_push_reply(state)
      |> maybe_push_title(state)

    case fetch_view_by_topic(state, topic) do
      {:ok, view} ->
        rendered = DOM.merge_diff(view.rendered, diff)
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
      |> DOM.reverse_filter(&DOM.attribute(&1, "data-phx-session"))
      |> DOM.all_attributes("id")
      |> MapSet.new()

    Enum.reduce(new_view.children, new_state, fn {id, _session}, acc ->
      if id in ids_after do
        acc
      else
        drop_child(acc, new_view, id, {:shutdown, :left})
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

          {child_view, rendered, _resp} = mount_view(acc, child_view, nil, nil)

          acc
          |> put_view(child_view, rendered)
          |> put_child(view, id, child_view.session_token)
          |> recursive_detect_added_or_removed_children(child_view, acc.html)
      end
    end)
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
    push_with_callback(state, view, event, payload, fn reply, state ->
      {:noreply, render_reply(reply, from, state)}
    end)
  end

  defp handle_reply(state, reply) do
    %{payload: payload, topic: topic} = reply

    new_state =
      case payload do
        %{diff: diff} -> merge_rendered(state, topic, diff)
        %{} = diff -> merge_rendered(state, topic, diff)
      end

    case payload do
      %{live_redirect: %{to: _to} = opts} ->
        stop_redirect(new_state, topic, {:live_redirect, opts})

      %{live_patch: %{to: _to} = opts} ->
        send_patch(new_state, topic, opts)
        {:ok, new_state}

      %{redirect: %{to: _to} = opts} ->
        stop_redirect(new_state, topic, {:redirect, opts})

      %{} ->
        {:ok, new_state}
    end
  end

  defp push_with_callback(state, view, event, payload, callback) do
    ref = to_string(state.ref + 1)

    state
    |> push(view, event, payload)
    |> put_reply(ref, view.pid, callback)
  end

  defp build_child(%ClientProxy{ref: ref, proxy: proxy, endpoint: endpoint}, attrs) do
    attrs_with_defaults =
      Keyword.merge(attrs,
        ref: ref,
        proxy: proxy,
        endpoint: endpoint,
        topic: "lv:#{Keyword.fetch!(attrs, :id)}"
      )

    struct!(__MODULE__, attrs_with_defaults)
  end

  ## Element helpers

  defp encode_event_type(type, value) when type in [:change, :submit],
    do: {"form", Plug.Conn.Query.encode(value)}

  defp encode_event_type(type, value),
    do: {Atom.to_string(type), value}

  defp proxy_topic({topic, _, _}) when is_binary(topic), do: topic
  defp proxy_topic(%{proxy: {_ref, topic, _pid}}), do: topic

  defp root(state, view), do: DOM.by_id!(state.html, view.id)

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
        {:error, :none,
         "selector #{inspect(selector)} did not return any element within: \n\n" <>
           DOM.inspect_html(root)}

      {[node], []} ->
        {:error, :none,
         "selector #{inspect(selector)} did not match text filter #{inspect(text_filter)}, " <>
           "got: \n\n#{DOM.inspect_html(node)}"}

      {_, []} ->
        {:error, :none,
         "selector #{inspect(selector)} returned #{length(nodes)} elements " <>
           "but none matched the text filter #{inspect(text_filter)}: \n\n" <>
           DOM.inspect_html(nodes)}

      {_, _} ->
        {:error, :many,
         "selector #{inspect(selector)} returned #{length(nodes)} elements " <>
           "and #{length(filtered_nodes)} of them matched the text filter #{inspect(text_filter)}: \n\n " <>
           DOM.inspect_html(filtered_nodes)}
    end
  end

  defp select_node(root, {_, _, selector}) do
    if selector do
      root |> DOM.child_nodes() |> DOM.maybe_one(selector)
    else
      {:ok, root}
    end
  end

  defp maybe_event(:upload_progress, node, %Element{} = element) do
    if ref = DOM.attribute(node, @data_phx_upload_ref) do
      {:upload_progress, proxy_topic(element), ref}
    else
      {:error, :invalid,
       "element selected by #{inspect(element.selector)} does not have a #{@data_phx_upload_ref} attribute"}
    end
  end

  defp maybe_event(:allow_upload, node, %Element{} = element) do
    if ref = DOM.attribute(node, @data_phx_upload_ref) do
      {:allow_upload, proxy_topic(element), ref}
    else
      {:error, :invalid,
       "element selected by #{inspect(element.selector)} does not have a #{@data_phx_upload_ref} attribute"}
    end
  end

  defp maybe_event(:hook, node, %Element{event: event} = element) do
    true = is_binary(event)

    if DOM.attribute(node, "phx-hook") do
      if DOM.attribute(node, "id") do
        {:ok, event}
      else
        {:error, :invalid,
         "element selected by #{inspect(element.selector)} for phx-hook does not have an ID"}
      end
    else
      {:error, :invalid,
       "element selected by #{inspect(element.selector)} does not have phx-hook attribute"}
    end
  end

  defp maybe_event(:click, {"a", _, _} = node, element) do
    cond do
      event = DOM.attribute(node, "phx-click") ->
        {:ok, event}

      to = DOM.attribute(node, "href") ->
        case DOM.attribute(node, "data-phx-link") do
          "patch" ->
            {:patch, proxy_topic(element), to}

          "redirect" ->
            kind = DOM.attribute(node, "data-phx-link-state") || "push"
            {:stop, proxy_topic(element), {:live_redirect, %{to: to, kind: String.to_atom(kind)}}}

          nil ->
            {:stop, proxy_topic(element), {:redirect, %{to: to}}}
        end

      true ->
        {:error, :invalid,
         "clicked link selected by #{inspect(element.selector)} does not have phx-click or href attributes"}
    end
  end

  defp maybe_event(type, node, element) when type in [:keyup, :keydown] do
    cond do
      event = DOM.attribute(node, "phx-#{type}") ->
        {:ok, event}

      event = DOM.attribute(node, "phx-window-#{type}") ->
        {:ok, event}

      true ->
        {:error, :invalid,
         "element selected by #{inspect(element.selector)} does not have " <>
           "phx-#{type} or phx-window-#{type} attributes"}
    end
  end

  defp maybe_event(type, node, element) do
    if event = DOM.attribute(node, "phx-#{type}") do
      {:ok, event}
    else
      {:error, :invalid,
       "element selected by #{inspect(element.selector)} does not have phx-#{type} attribute"}
    end
  end

  defp maybe_enabled(_type, {tag, _, _}, %{form_data: form_data})
       when tag != "form" and form_data != nil do
    {:error, :invalid,
     "a form element was given but the selected node is not a form, got #{inspect(tag)}}"}
  end

  defp maybe_enabled(type, node, element) do
    if DOM.attribute(node, "disabled") do
      {:error, :invalid,
       "cannot #{type} element #{inspect(element.selector)} because it is disabled"}
    else
      :ok
    end
  end

  defp maybe_values(:hook, _node, _element), do: {:ok, %{}}

  defp maybe_values(type, {tag, _, _} = node, element) when type in [:change, :submit] do
    if tag == "form" do
      defaults =
        node
        |> DOM.reverse_filter(fn node ->
          DOM.tag(node) in ~w(input textarea select) and is_nil(DOM.attribute(node, "disabled"))
        end)
        |> Enum.reduce(%{}, &form_defaults/2)

      case fill_in_map(Enum.to_list(element.form_data || %{}), "", node, []) do
        {:ok, value} -> {:ok, DOM.deep_merge(defaults, value)}
        {:error, _, _} = error -> error
      end
    else
      {:error, :invalid, "phx-#{type} is only allowed in forms, got #{inspect(tag)}"}
    end
  end

  defp maybe_values(_type, node, _element) do
    {:ok, DOM.all_values(node)}
  end

  defp maybe_push_events(diff, state) do
    case diff do
      %{@events => events} ->
        for [name, payload] <- events, do: send_caller(state, {:push_event, name, payload})
        Map.delete(diff, @events)

      %{} ->
        diff
    end
  end

  defp maybe_push_reply(diff, state) do
    case diff do
      %{@reply => reply} ->
        send_caller(state, {:reply, reply})
        Map.delete(diff, @reply)

      %{} ->
        diff
    end
  end

  defp maybe_push_title(diff, state) do
    case diff do
      %{@title => title} -> {Map.delete(diff, @title), %{state | page_title: title}}
      %{} -> {diff, state}
    end
  end

  defp form_defaults(node, acc) do
    if name = DOM.attribute(node, "name") do
      form_defaults(node, name, acc)
    else
      acc
    end
  end

  defp form_defaults({"select", _, _} = node, name, acc) do
    options = DOM.filter(node, &(DOM.tag(&1) == "option"))

    all_selected =
      if DOM.attribute(node, "multiple") do
        Enum.filter(options, &DOM.attribute(&1, "selected"))
      else
        List.wrap(Enum.find(options, &DOM.attribute(&1, "selected")) || List.first(options))
      end

    all_selected
    |> Enum.reverse()
    |> Enum.reduce(acc, fn selected, acc ->
      Plug.Conn.Query.decode_pair({name, DOM.attribute(selected, "value")}, acc)
    end)
  end

  defp form_defaults({"textarea", _, [value]}, name, acc) do
    Plug.Conn.Query.decode_pair({name, String.replace_prefix(value, "\n", "")}, acc)
  end

  defp form_defaults({"input", _, _} = node, name, acc) do
    type = DOM.attribute(node, "type") || "text"
    value = DOM.attribute(node, "value") || ""

    cond do
      type in ["radio", "checkbox"] ->
        if DOM.attribute(node, "checked") do
          Plug.Conn.Query.decode_pair({name, value}, acc)
        else
          acc
        end

      type in ["image", "submit"] ->
        acc

      true ->
        Plug.Conn.Query.decode_pair({name, value}, acc)
    end
  end

  defp fill_in_map([{key, value} | rest], prefix, node, acc) do
    key = to_string(key)

    case fill_in_type(value, fill_in_name(prefix, key), node) do
      {:ok, value} -> fill_in_map(rest, prefix, node, [{key, value} | acc])
      {:error, _, _} = error -> error
    end
  end

  defp fill_in_map([], _prefix, _node, acc) do
    {:ok, Map.new(acc)}
  end

  defp fill_in_type([{_, _} | _] = value, key, node), do: fill_in_map(value, key, node, [])
  defp fill_in_type(%_{} = value, key, node), do: fill_in_value(value, key, node)
  defp fill_in_type(%{} = value, key, node), do: fill_in_map(Map.to_list(value), key, node, [])
  defp fill_in_type(value, key, node), do: fill_in_value(value, key, node)

  @limited ["select", "multiple select", "checkbox", "radio", "hidden"]
  @forbidden ["submit", "image"]

  defp fill_in_value(non_string_value, name, node) do
    value = stringify(non_string_value, &to_string/1)
    name = if is_list(value), do: name <> "[]", else: name

    {types, dom_values} =
      node
      |> DOM.filter(fn node ->
        DOM.attribute(node, "name") == name and is_nil(DOM.attribute(node, "disabled"))
      end)
      |> collect_values([], [])

    limited? = Enum.all?(types, &(&1 in @limited))

    cond do
      calendar_value = calendar_value(types, non_string_value, name, node) ->
        {:ok, calendar_value}

      types == [] ->
        {:error, :invalid,
         "could not find non-disabled input, select or textarea with name #{inspect(name)} within:\n\n" <>
           DOM.inspect_html(DOM.all(node, "[name]"))}

      forbidden_type = Enum.find(types, &(&1 in @forbidden)) ->
        {:error, :invalid,
         "cannot provide value to #{inspect(name)} because #{forbidden_type} inputs are never submitted"}

      forbidden_value = limited? && value |> List.wrap() |> Enum.find(&(&1 not in dom_values)) ->
        {:error, :invalid,
         "value for #{hd(types)} #{inspect(name)} must be one of #{inspect(dom_values)}, " <>
           "got: #{inspect(forbidden_value)}"}

      true ->
        {:ok, value}
    end
  end

  @calendar_fields ~w(year month day hour minute second)a

  defp calendar_value([], %{calendar: _} = calendar_type, name, node) do
    @calendar_fields
    |> Enum.flat_map(fn field ->
      string_field = Atom.to_string(field)

      with value when not is_nil(value) <- Map.get(calendar_type, field),
           {:ok, string_value} <- fill_in_value(value, name <> "[" <> string_field <> "]", node) do
        [{string_field, string_value}]
      else
        _ -> []
      end
    end)
    |> case do
      [] -> nil
      pairs -> Map.new(pairs)
    end
  end

  defp calendar_value(_, _, _, _) do
    nil
  end

  defp collect_values([{"textarea", _, _} | nodes], types, values) do
    collect_values(nodes, ["textarea" | types], values)
  end

  defp collect_values([{"input", _, _} = node | nodes], types, values) do
    type = DOM.attribute(node, "type") || "text"

    if type in ["radio", "checkbox", "hidden"] do
      value = DOM.attribute(node, "value") || ""
      collect_values(nodes, [type | types], [value | values])
    else
      collect_values(nodes, [type | types], values)
    end
  end

  defp collect_values([{"select", _, _} = node | nodes], types, values) do
    options =
      node
      |> DOM.filter(&(DOM.tag(&1) == "option"))
      |> Enum.map(&(DOM.attribute(&1, "value") || ""))

    if DOM.attribute(node, "multiple") do
      collect_values(nodes, ["multiple select" | types], Enum.reverse(options, values))
    else
      collect_values(nodes, ["select" | types], Enum.reverse(options, values))
    end
  end

  defp collect_values([_ | nodes], types, values) do
    collect_values(nodes, types, values)
  end

  defp collect_values([], types, values) do
    {types, Enum.reverse(values)}
  end

  defp fill_in_name("", name), do: name
  defp fill_in_name(prefix, name), do: prefix <> "[" <> name <> "]"

  defp stringify(%Upload{}, _fun), do: %{}

  defp stringify(%{__struct__: _} = struct, fun),
    do: stringify_value(struct, fun)

  defp stringify(%{} = params, fun),
    do: Enum.into(params, %{}, &stringify_kv(&1, fun))

  defp stringify([{_, _} | _] = params, fun),
    do: Enum.into(params, %{}, &stringify_kv(&1, fun))

  defp stringify(params, fun) when is_list(params),
    do: Enum.map(params, &stringify(&1, fun))

  defp stringify(other, fun),
    do: stringify_value(other, fun)

  defp stringify_value(other, fun), do: fun.(other)
  defp stringify_kv({k, v}, fun), do: {to_string(k), stringify(v, fun)}

  defp maybe_put_uploads(state, view, payload, %Upload{} = upload) do
    {:ok, node} = state |> root(view) |> select_node(upload.element)
    ref = DOM.attribute(node, "data-phx-upload-ref")
    Map.put(payload, "uploads", %{ref => upload.entries})
  end

  defp maybe_put_uploads(_state, _view, payload, nil), do: payload

  defp put_cid(payload, nil), do: payload
  defp put_cid(payload, cid), do: Map.put(payload, "cid", cid)

  defp root_page_title(root_html) do
    case DOM.maybe_one(root_html, "title") do
      {:ok, {"title", _, [text]}} -> text
      {:error, _kind, _desc} -> nil
    end
  end
end
