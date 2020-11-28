defmodule Phoenix.LiveView.Diff do
  # The diff engine is responsible for tracking the rendering state.
  # Given that components are part of said state, they are also
  # handled here.
  @moduledoc false

  alias Phoenix.LiveView.{Utils, Rendered, Comprehension, Component}

  @components :c
  @static :s
  @dynamics :d
  @events :e
  @reply :r
  @title :t

  # We use this to track which components have been marked
  # for deletion. If the component is used after being marked,
  # it should not be deleted.
  @marked_for_deletion :marked_for_deletion

  @doc """
  Returns the diff component state.
  """
  def new_components(uuids \\ 1) do
    {_cid_to_component = %{}, _id_to_cid = %{}, uuids}
  end

  @doc """
  Returns the diff fingerprint state.
  """
  def new_fingerprints do
    {nil, %{}}
  end

  @doc """
  Converts a diff into iodata.

  It only accepts a full render diff.
  """
  def to_iodata(map, component_mapper \\ fn _cid, content -> content end) do
    to_iodata(map, Map.get(map, @components, %{}), component_mapper) |> elem(0)
  end

  defp to_iodata(%{@dynamics => dynamics, @static => static}, components, mapper) do
    Enum.map_reduce(dynamics, components, fn dynamic, components ->
      many_to_iodata(static, dynamic, [], components, mapper)
    end)
  end

  defp to_iodata(%{@static => static} = parts, components, mapper) do
    one_to_iodata(static, parts, 0, [], components, mapper)
  end

  defp to_iodata(cid, components, mapper) when is_integer(cid) do
    # Resolve component pointers and update the component entries
    components = resolve_components_xrefs(cid, components)
    {iodata, components} = to_iodata(Map.fetch!(components, cid), components, mapper)
    {mapper.(cid, iodata), components}
  end

  defp to_iodata(binary, components, _mapper) when is_binary(binary) do
    {binary, components}
  end

  defp one_to_iodata([last], _parts, _counter, acc, components, _mapper) do
    {Enum.reverse([last | acc]), components}
  end

  defp one_to_iodata([head | tail], parts, counter, acc, components, mapper) do
    {iodata, components} = to_iodata(Map.fetch!(parts, counter), components, mapper)
    one_to_iodata(tail, parts, counter + 1, [iodata, head | acc], components, mapper)
  end

  defp many_to_iodata([shead | stail], [dhead | dtail], acc, components, mapper) do
    {iodata, components} = to_iodata(dhead, components, mapper)
    many_to_iodata(stail, dtail, [iodata, shead | acc], components, mapper)
  end

  defp many_to_iodata([shead], [], acc, components, _mapper) do
    {Enum.reverse([shead | acc]), components}
  end

  defp resolve_components_xrefs(cid, components) do
    case components[cid] do
      %{@static => static} = diff when is_integer(static) ->
        static = abs(static)
        components = resolve_components_xrefs(static, components)
        Map.put(components, cid, deep_merge(components[static], Map.delete(diff, @static)))

      %{} ->
        components
    end
  end

  defp deep_merge(_original, %{@static => _} = extra), do: extra

  defp deep_merge(original, extra) do
    Map.merge(original, extra, fn
      _, %{} = original, %{} = extra -> deep_merge(original, extra)
      _, _original, extra -> extra
    end)
  end

  @doc """
  Render information stored in private changed.
  """
  def render_private(socket, diff) do
    {_, diff} =
      diff
      |> maybe_put_reply(socket)
      |> maybe_put_events(socket)

    diff
  end

  @doc """
  Renders a diff for the rendered struct in regards to the given socket.
  """
  def render(
        %{fingerprints: {expected, _}} = socket,
        %Rendered{fingerprint: actual} = rendered,
        {_, _, uuids}
      )
      when expected != nil and expected != actual do
    render(%{socket | fingerprints: new_fingerprints()}, rendered, new_components(uuids))
  end

  def render(%{fingerprints: prints} = socket, %Rendered{} = rendered, components) do
    {diff, prints, pending, components} =
      traverse(socket, rendered, prints, %{}, components, true)

    {component_diffs, components} = render_pending_components(socket, pending, %{}, components)
    socket = %{socket | fingerprints: prints}

    diff = maybe_put_title(diff, socket)
    {diff, component_diffs} = extract_events({diff, component_diffs})

    if map_size(component_diffs) == 0 do
      {socket, diff, components}
    else
      {socket, Map.put(diff, @components, component_diffs), components}
    end
  end

  defp maybe_put_title(diff, socket) do
    if Utils.changed?(socket, :page_title) do
      Map.put(diff, @title, socket.assigns.page_title)
    else
      diff
    end
  end

  defp maybe_put_events(diff, socket) do
    case Utils.get_push_events(socket) do
      [_ | _] = events -> {true, Map.put(diff, @events, events)}
      [] -> {false, diff}
    end
  end

  defp extract_events({diff, component_diffs}) do
    case component_diffs do
      %{@events => component_events} ->
        {Map.update(diff, @events, component_events, &(&1 ++ component_events)),
         Map.delete(component_diffs, @events)}

      %{} ->
        {diff, component_diffs}
    end
  end

  defp maybe_put_reply(diff, socket) do
    case Utils.get_reply(socket) do
      nil -> diff
      reply -> Map.put(diff, @reply, reply)
    end
  end

  @doc """
  Execute the `fun` with the component `cid` with the given `socket` as template.

  It will store the result under the `cid` key in the `component_diffs` map.

  It returns the updated `component_diffs` and the updated `components` or
  `:error` if the component cid does not exist.
  """
  def write_component(socket, cid, component_diffs, components, fun) when is_integer(cid) do
    {cid_to_component, _id_to_cid, _} = components

    case cid_to_component do
      %{^cid => {component, id, assigns, private, fingerprints}} ->
        {component_socket, extra} =
          socket
          |> configure_socket_for_component(assigns, private, fingerprints)
          |> fun.(component)

        {pending, component_diffs, components} =
          render_component(
            component_socket,
            component,
            id,
            cid,
            false,
            %{},
            cid_to_component,
            component_diffs,
            components
          )

        diff = maybe_put_reply(%{}, socket)

        {component_diffs, components} =
          render_pending_components(socket, pending, component_diffs, components)

        {diff, component_diffs} = extract_events({diff, component_diffs})

        {Map.put(diff, @components, component_diffs), components, extra}

      %{} ->
        :error
    end
  end

  @doc """
  Execute the `fun` with the component `cid` with the given `socket` and returns the result.

  `:error` if the component cid does not exist.
  """
  def read_component(socket, cid, components, fun) when is_integer(cid) do
    {cid_to_component, _id_to_cid, _} = components

    case cid_to_component do
      %{^cid => {component, _id, assigns, private, fingerprints}} ->
          socket
          |> configure_socket_for_component(assigns, private, fingerprints)
          |> fun.(component)

      %{} ->
        :error
    end
  end


  @doc """
  Sends an update to a component.

  Like `write_component/5`, it will store the result under the `cid
   key in the `component_diffs` map.

  If the component exists, a `{diff, new_components}` tuple
  is returned. Otherwise, `:noop` is returned.

  The component is preloaded before the update callback is invoked.

  ## Example

      {diff, new_components} = Diff.update_component(socket, state.components, update)
  """
  def update_component(socket, components, {module, id, updated_assigns}) do
    case fetch_cid(module, id, components) do
      {:ok, cid} ->
        updated_assigns = maybe_call_preload!(module, updated_assigns)

        {diff, new_components, :noop} =
          write_component(socket, cid, %{}, components, fn component_socket, component ->
            {Utils.maybe_call_update!(component_socket, component, updated_assigns), :noop}
          end)

        {diff, new_components}

      :error ->
        :noop
    end
  end

  @doc """
  Marks a component for deletion.

  It won't be deleted if the component is used meanwhile.
  """
  def mark_for_deletion_component(cid, {cid_to_component, id_to_cid, uuids}) do
    cid_to_component =
      case cid_to_component do
        %{^cid => {component, id, assigns, private, prints}} ->
          private = Map.put(private, @marked_for_deletion, true)
          Map.put(cid_to_component, cid, {component, id, assigns, private, prints})

        %{} ->
          cid_to_component
      end

    {cid_to_component, id_to_cid, uuids}
  end

  @doc """
  Deletes a component by `cid` if it has not been used meanwhile.
  """
  def delete_component(cid, {cid_to_component, id_to_cid, uuids}) do
    case cid_to_component do
      %{^cid => {component, id, _, %{@marked_for_deletion => true}, _}} ->
        id_to_cid =
          case id_to_cid do
            %{^component => inner} ->
              case Map.delete(inner, id) do
                inner when inner == %{} -> Map.delete(id_to_cid, component)
                inner -> Map.put(id_to_cid, component, inner)
              end

            %{} ->
              id_to_cid
          end

        {[cid], {Map.delete(cid_to_component, cid), id_to_cid, uuids}}

      _ ->
        {[], {cid_to_component, id_to_cid, uuids}}
    end
  end

  @doc """
  Converts a component to a rendered struct.
  """
  def component_to_rendered(socket, component, assigns, mount_assigns) when is_map(assigns) do
    socket = mount_component(socket, component, mount_assigns)
    assigns = maybe_call_preload!(component, assigns)

    socket
    |> Utils.maybe_call_update!(component, assigns)
    |> Utils.to_rendered(component)
  end

  ## Traversal

  defp traverse(
         socket,
         %Rendered{fingerprint: fingerprint, dynamic: dynamic},
         {fingerprint, children},
         pending,
         components,
         changed?
       ) do
    {_counter, diff, children, pending, components} =
      traverse_dynamic(socket, dynamic.(changed?), children, pending, components, changed?)

    {diff, {fingerprint, children}, pending, components}
  end

  defp traverse(
         socket,
         %Rendered{fingerprint: fingerprint, static: static, dynamic: dynamic},
         _,
         pending,
         components,
         changed?
       ) do
    {_counter, diff, children, pending, components} =
      traverse_dynamic(socket, dynamic.(false), %{}, pending, components, changed?)

    {Map.put(diff, @static, static), {fingerprint, children}, pending, components}
  end

  defp traverse(
         socket,
         %Component{id: nil, component: component, assigns: assigns},
         fingerprints_tree,
         pending,
         components,
         changed?
       ) do
    rendered = component_to_rendered(socket, component, assigns, %{})
    traverse(socket, rendered, fingerprints_tree, pending, components, changed?)
  end

  defp traverse(
         socket,
         %Component{} = component,
         _fingerprints_tree,
         pending,
         components,
         _changed?
       ) do
    {cid, pending, components} = traverse_component(socket, component, pending, components)
    {cid, nil, pending, components}
  end

  defp traverse(
         socket,
         %Comprehension{dynamics: dynamics, fingerprint: fingerprint},
         fingerprint,
         pending,
         components,
         _changed?
       ) do
    {dynamics, {pending, components}} =
      traverse_comprehension(socket, dynamics, pending, components)

    {%{@dynamics => dynamics}, fingerprint, pending, components}
  end

  defp traverse(_socket, %Comprehension{dynamics: []}, _, pending, components, _changed?) do
    # The comprehension has no elements and it was not rendered yet, so we skip it.
    {"", nil, pending, components}
  end

  defp traverse(
         socket,
         %Comprehension{static: static, dynamics: dynamics, fingerprint: fingerprint},
         _,
         pending,
         components,
         _changed?
       ) do
    {dynamics, {pending, components}} =
      traverse_comprehension(socket, dynamics, pending, components)

    {%{@dynamics => dynamics, @static => static}, fingerprint, pending, components}
  end

  defp traverse(_socket, nil, fingerprint_tree, pending, components, _changed?) do
    {nil, fingerprint_tree, pending, components}
  end

  defp traverse(_socket, iodata, _, pending, components, _changed?) do
    {IO.iodata_to_binary(iodata), nil, pending, components}
  end

  defp traverse_dynamic(socket, dynamic, children, pending, components, changed?) do
    Enum.reduce(dynamic, {0, %{}, children, pending, components}, fn
      entry, {counter, diff, children, pending, components} ->
        {serialized, child_fingerprint, pending, components} =
          traverse(socket, entry, Map.get(children, counter), pending, components, changed?)

        # If serialized is nil, it means no changes.
        # If it is an empty map, then it means it is a rendered struct
        # that did not change, so we don't have to emit it either.
        diff =
          if serialized != nil and serialized != %{} do
            Map.put(diff, counter, serialized)
          else
            diff
          end

        children =
          if child_fingerprint do
            Map.put(children, counter, child_fingerprint)
          else
            Map.delete(children, counter)
          end

        {counter + 1, diff, children, pending, components}
    end)
  end

  defp traverse_comprehension(socket, dynamics, pending, components) do
    Enum.map_reduce(dynamics, {pending, components}, fn list, acc ->
      Enum.map_reduce(list, acc, fn rendered, {pending, components} ->
        {diff, _, pending, components} =
          traverse(socket, rendered, {nil, %{}}, pending, components, false)

        {diff, {pending, components}}
      end)
    end)
  end

  ## Stateful components helpers

  defp traverse_component(
         _socket,
         %Component{id: id, assigns: assigns, component: component},
         pending,
         {cid_to_component, id_to_cid, uuids}
       ) do
    {cid, new?, components} =
      case id_to_cid do
        %{^component => %{^id => cid}} -> {cid, false, {cid_to_component, id_to_cid, uuids}}
        %{} -> {uuids, true, {cid_to_component, id_to_cid, uuids + 1}}
      end

    entry = {cid, id, new?, assigns}
    pending = Map.update(pending, component, [entry], &[entry | &1])
    {cid, pending, components}
  end

  ## Component rendering

  defp render_pending_components(socket, pending, diffs, components) do
    # We keep the original `cid_to_component`. This helps us to guarantee
    # that we are not rebuilding the same component multiple times and it
    # also helps with optimizations.
    {cid_to_component, _, _} = components
    render_pending_components(socket, pending, %{}, cid_to_component, diffs, components)
  end

  defp render_pending_components(_, pending, _seen_ids, _cids, diffs, components)
       when map_size(pending) == 0 do
    {diffs, components}
  end

  defp render_pending_components(socket, pending, seen_ids, cids, diffs, components) do
    acc = {{%{}, diffs, components}, seen_ids}

    {{pending, diffs, components}, seen_ids} =
      Enum.reduce(pending, acc, fn {component, entries}, acc ->
        entries = maybe_preload_components(component, Enum.reverse(entries))

        Enum.reduce(entries, acc, fn {cid, id, new?, new_assigns}, {triplet, seen_ids} ->
          {pending, diffs, components} = triplet

          if Map.has_key?(seen_ids, [component | id]) do
            raise "found duplicate ID #{inspect(id)} " <>
                    "for component #{inspect(component)} when rendering template"
          end

          {socket, components} =
            case cids do
              %{^cid => {_component, _id, assigns, private, prints}} ->
                private = Map.delete(private, @marked_for_deletion)
                {configure_socket_for_component(socket, assigns, private, prints), components}

              %{} ->
                myself_assigns = %{myself: %Phoenix.LiveComponent.CID{cid: cid}}

                {mount_component(socket, component, myself_assigns),
                 put_cid(components, component, id, cid)}
            end

          triplet =
            socket
            |> Utils.maybe_call_update!(component, new_assigns)
            |> render_component(component, id, cid, new?, pending, cids, diffs, components)

          {triplet, Map.put(seen_ids, [component | id], true)}
        end)
      end)

    render_pending_components(socket, pending, seen_ids, cids, diffs, components)
  end

  defp maybe_preload_components(component, entries) do
    if function_exported?(component, :preload, 1) do
      list_of_assigns = Enum.map(entries, fn {_cid, _id, _new?, new_assigns} -> new_assigns end)
      result = component.preload(list_of_assigns)
      zip_preloads(result, entries, component, result)
    else
      entries
    end
  end

  defp maybe_call_preload!(module, assigns) do
    if function_exported?(module, :preload, 1) do
      [new_assigns] = module.preload([assigns])
      new_assigns
    else
      assigns
    end
  end

  defp zip_preloads([new_assigns | assigns], [{cid, id, new?, _} | entries], component, preloaded)
       when is_map(new_assigns) do
    [{cid, id, new?, new_assigns} | zip_preloads(assigns, entries, component, preloaded)]
  end

  defp zip_preloads([], [], _component, _preloaded) do
    []
  end

  defp zip_preloads(_, _, component, preloaded) do
    raise ArgumentError,
          "expected #{inspect(component)}.preload/1 to return a list of maps of the same length " <>
            "as the list of assigns given, got: #{inspect(preloaded)}"
  end

  defp render_component(socket, component, id, cid, new?, pending, cids, diffs, components) do
    {events?, diffs} = maybe_put_events(diffs, socket)
    changed? = new? or Utils.changed?(socket)

    {socket, pending, diff, {cid_to_component, id_to_cid, uuids}} =
      if changed? do
        rendered = Utils.to_rendered(socket, component)

        {changed?, linked_cid, prints} =
          maybe_reuse_static(rendered, socket, component, cids, components)

        {diff, component_prints, pending, components} =
          traverse(socket, rendered, prints, pending, components, changed?)

        diff = if linked_cid, do: Map.put(diff, @static, linked_cid), else: diff
        {%{socket | fingerprints: component_prints}, pending, diff, components}
      else
        {socket, pending, %{}, components}
      end

    socket =
      if changed? or events? do
        Utils.clear_changed(socket)
      else
        socket
      end

    diffs =
      if diff != %{} or new? do
        Map.put(diffs, cid, diff)
      else
        diffs
      end

    cid_to_component = Map.put(cid_to_component, cid, dump_component(socket, component, id))
    {pending, diffs, {cid_to_component, id_to_cid, uuids}}
  end

  @attempts 3

  # If the component is new or is getting a new static root, we search if another
  # component has the same tree root. If so, we will point to the whole existing
  # component tree but say all entries require a full render.
  #
  # When looking up for an existing component, we first look into the tree from the
  # previous render, then we look at the new render. This is to avoid using a tree
  # that will be changed before it is sent to the client.
  #
  # We don't want to traverse all of the components, so we will try it @attempts times.
  defp maybe_reuse_static(rendered, socket, component, old_cids, components) do
    {new_cids, id_to_cid, _uuids} = components
    %{fingerprint: print} = rendered
    %{fingerprints: {socket_print, _} = socket_prints} = socket

    with true <- socket_print != print,
         iterator = :maps.iterator(Map.fetch!(id_to_cid, component)),
         {cid, existing_prints} <-
           find_same_component_print(print, iterator, old_cids, new_cids, @attempts) do
      {false, cid, existing_prints}
    else
      _ -> {true, nil, socket_prints}
    end
  end

  defp find_same_component_print(_print, _iterator, _old_cids, _new_cids, 0), do: :none

  defp find_same_component_print(print, iterator, old_cids, new_cids, attempts) do
    case :maps.next(iterator) do
      {_, cid, iterator} ->
        case old_cids do
          %{^cid => {_, _, _, _, {^print, _} = tree}} ->
            {-cid, tree}

          %{} ->
            case new_cids do
              %{^cid => {_, _, _, _, {^print, _} = tree}} -> {cid, tree}
              %{} -> find_same_component_print(print, iterator, old_cids, new_cids, attempts - 1)
            end
        end

      :none ->
        :none
    end
  end

  defp put_cid({id_to_components, id_to_cid, uuids}, component, id, cid) do
    inner = Map.get(id_to_cid, component, %{})
    {id_to_components, Map.put(id_to_cid, component, Map.put(inner, id, cid)), uuids}
  end

  defp fetch_cid(component, id, {_cid_to_components, id_to_cid, _} = _components) do
    case id_to_cid do
      %{^component => %{^id => cid}} -> {:ok, cid}
      %{} -> :error
    end
  end

  defp mount_component(socket, component, assigns) do
    private =
      socket.private
      |> Map.take([:conn_session])
      |> Map.put(:changed, %{})

    socket =
      configure_socket_for_component(socket, assigns, private, new_fingerprints())
      |> Utils.assign(:flash, %{})

    Utils.maybe_call_live_component_mount!(socket, component)
  end

  defp configure_socket_for_component(socket, assigns, private, prints) do
    %{
      socket
      | assigns: assigns,
        private: private,
        fingerprints: prints,
        changed: %{}
    }
  end

  defp dump_component(socket, component, id) do
    {component, id, socket.assigns, socket.private, socket.fingerprints}
  end
end
