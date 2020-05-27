defmodule Phoenix.LiveView.Diff do
  # The diff engine is responsible for tracking the rendering state.
  # Given that components are part of said state, they are also
  # handled here.
  @moduledoc false

  alias Phoenix.LiveView.{Utils, Rendered, Comprehension, Component}

  @components :c
  @static :s
  @dynamics :d

  @doc """
  Returns the diff component state.
  """
  def new_components(uuids \\ 0) do
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
    to_iodata(map, Map.get(map, @components, %{}), component_mapper)
  end

  defp to_iodata(%{@dynamics => dynamics, @static => static}, components, mapper) do
    for dynamic <- dynamics do
      many_to_iodata(static, dynamic, components, mapper)
    end
  end

  defp to_iodata(%{@static => static} = parts, components, mapper) do
    one_to_iodata(find_static(static, components), parts, 0, components, mapper)
  end

  defp to_iodata(cid, components, mapper) when is_integer(cid) do
    mapper.(cid, to_iodata(Map.fetch!(components, cid), components, mapper))
  end

  defp to_iodata(binary, _components, _mapper) when is_binary(binary) do
    binary
  end

  defp find_static(cid, components) when is_integer(cid),
    do: find_static(components[cid][@static], components)

  defp find_static(list, _components) when is_list(list),
    do: list

  defp one_to_iodata([last], _parts, _counter, _components, _mapper) do
    [last]
  end

  defp one_to_iodata([head | tail], parts, counter, components, mapper) do
    [
      head,
      to_iodata(Map.fetch!(parts, counter), components, mapper)
      | one_to_iodata(tail, parts, counter + 1, components, mapper)
    ]
  end

  defp many_to_iodata([shead | stail], [dhead | dtail], components, mapper) do
    [
      shead,
      to_iodata(dhead, components, mapper)
      | many_to_iodata(stail, dtail, components, mapper)
    ]
  end

  defp many_to_iodata([shead], [], _components, _mapper) do
    [shead]
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
    {diff, prints, pending, components} = traverse(socket, rendered, prints, %{}, components)

    {component_diffs, components} =
      render_pending_components(socket, pending, %{}, %{}, components)

    socket = %{socket | fingerprints: prints}

    diff =
      if Utils.changed?(socket, :page_title) do
        Map.put(diff, :title, socket.assigns.page_title)
      else
        diff
      end

    if map_size(component_diffs) == 0 do
      {socket, diff, components}
    else
      {socket, Map.put(diff, @components, component_diffs), components}
    end
  end

  @doc """
  Execute the `fun` with the component `cid` with the given `socket` as template.

  It will store the result under the `cid` key in the `component_diffs` map.

  It returns the updated `component_diffs` and the updated `components` or
  `:error` if the component cid does not exist.
  """
  def with_component(socket, cid, component_diffs, components, fun) when is_integer(cid) do
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
            component_diffs,
            components
          )

        {component_diffs, components} =
          render_pending_components(socket, pending, %{}, component_diffs, components)

        {%{@components => component_diffs}, components, extra}

      %{} ->
        :error
    end
  end

  @doc """
  Sends an update to a component.

  Like `with_component/5`, it will store the result under the `cid
   key in the `component_diffs` map.

  If the component exists, a `{:diff, component_diff, updated_components}` tuple
  is returned. Otherwise, `:noop` is returned.

  The component is preloaded before the update callback is invoked.

  ## Example

      {:diff, diff, new_components} = Diff.update_components(socket, state.components, update)
  """
  def update_component(socket, components, {module, id, updated_assigns}) do
    case fetch_cid(module, id, components) do
      {:ok, cid} ->
        updated_assigns = maybe_call_preload!(module, updated_assigns)

        {diff, new_components, :noop} =
          with_component(socket, cid, %{}, components, fn component_socket, component ->
            {Utils.maybe_call_update!(component_socket, component, updated_assigns), :noop}
          end)

        {diff, new_components}

      :error ->
        :noop
    end
  end

  @doc """
  Deletes a component by `cid`.
  """
  def delete_component(cid, {cid_to_component, id_to_cid, uuids}) do
    case Map.pop(cid_to_component, cid) do
      {{component, id, _, _, _}, cid_to_component} ->
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

        {cid_to_component, id_to_cid, uuids}

      _ ->
        {cid_to_component, id_to_cid, uuids}
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
         components
       ) do
    {_counter, diff, children, pending, components} =
      traverse_dynamic(socket, dynamic.(true), children, pending, components)

    {diff, {fingerprint, children}, pending, components}
  end

  defp traverse(
         socket,
         %Rendered{fingerprint: fingerprint, static: static, dynamic: dynamic},
         _,
         pending,
         components
       ) do
    {_counter, diff, children, pending, components} =
      traverse_dynamic(socket, dynamic.(false), %{}, pending, components)

    {Map.put(diff, @static, static), {fingerprint, children}, pending, components}
  end

  defp traverse(
         socket,
         %Component{id: nil, component: component, assigns: assigns},
         fingerprints_tree,
         pending,
         components
       ) do
    rendered = component_to_rendered(socket, component, assigns, %{})
    traverse(socket, rendered, fingerprints_tree, pending, components)
  end

  defp traverse(
         socket,
         %Component{} = component,
         fingerprints_tree,
         pending,
         components
       ) do
    {cid, pending, components} = traverse_component(socket, component, pending, components)

    {cid, fingerprints_tree, pending, components}
  end

  defp traverse(
         socket,
         %Comprehension{dynamics: dynamics, fingerprint: fingerprint},
         fingerprint,
         pending,
         components
       ) do
    {dynamics, {pending, components}} =
      traverse_comprehension(socket, dynamics, pending, components)

    {%{@dynamics => dynamics}, fingerprint, pending, components}
  end

  defp traverse(_socket, %Comprehension{dynamics: []}, _, pending, components) do
    # The comprehension has no elements and it was not rendered yet, so we skip it.
    {"", nil, pending, components}
  end

  defp traverse(
         socket,
         %Comprehension{static: static, dynamics: dynamics, fingerprint: fingerprint},
         _,
         pending,
         components
       ) do
    {dynamics, {pending, components}} =
      traverse_comprehension(socket, dynamics, pending, components)

    {%{@dynamics => dynamics, @static => static}, fingerprint, pending, components}
  end

  defp traverse(_socket, nil, fingerprint_tree, pending, components) do
    {nil, fingerprint_tree, pending, components}
  end

  defp traverse(_socket, iodata, _, pending, components) do
    {IO.iodata_to_binary(iodata), nil, pending, components}
  end

  defp traverse_dynamic(socket, dynamic, children, pending, components) do
    Enum.reduce(dynamic, {0, %{}, children, pending, components}, fn
      entry, {counter, diff, children, pending, components} ->
        {serialized, child_fingerprint, pending, components} =
          traverse(socket, entry, Map.get(children, counter), pending, components)

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
          traverse(socket, rendered, {nil, %{}}, pending, components)

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

  defp render_pending_components(_, pending, _seen_ids, component_diffs, components)
       when map_size(pending) == 0 do
    {component_diffs, components}
  end

  defp render_pending_components(socket, pending, seen_ids, component_diffs, components) do
    {cid_to_component, _, _} = components
    acc = {{%{}, component_diffs, components}, seen_ids}

    {{pending, component_diffs, components}, seen_ids} =
      Enum.reduce(pending, acc, fn {component, entries}, acc ->
        entries = maybe_preload_components(component, Enum.reverse(entries))

        Enum.reduce(entries, acc, fn {cid, id, new?, new_assigns}, {triplet, seen_ids} ->
          {pending, component_diffs, components} = triplet

          if Map.has_key?(seen_ids, [component | id]) do
            raise "found duplicate ID #{inspect(id)} " <>
                    "for component #{inspect(component)} when rendering template"
          end

          {socket, components} =
            case cid_to_component do
              %{^cid => {_component, _id, assigns, private, prints}} ->
                {configure_socket_for_component(socket, assigns, private, prints), components}

              %{} ->
                {mount_component(socket, component, %{myself: cid}),
                 put_cid(components, component, id, cid)}
            end

          triplet =
            socket
            |> Utils.maybe_call_update!(component, new_assigns)
            |> render_component(component, id, cid, new?, pending, component_diffs, components)

          {triplet, Map.put(seen_ids, [component | id], true)}
        end)
      end)

    render_pending_components(socket, pending, seen_ids, component_diffs, components)
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

  defp render_component(socket, component, id, cid, new?, pending, component_diffs, components) do
    {socket, pending, diff, {cid_to_component, id_to_cid, uuids}} =
      if new? or Utils.changed?(socket) do
        rendered = Utils.to_rendered(socket, component)

        {diff, component_prints, pending, components} =
          traverse(socket, rendered, socket.fingerprints, pending, components)

        socket = Utils.clear_changed(%{socket | fingerprints: component_prints})
        {socket, pending, diff, components}
      else
        {socket, pending, %{}, components}
      end

    component_diffs =
      if diff != %{} or new? do
        diff = reuse_static(diff, socket, component, cid_to_component, id_to_cid)
        Map.put(component_diffs, cid, diff)
      else
        component_diffs
      end

    cid_to_component = Map.put(cid_to_component, cid, dump_component(socket, component, id))
    {pending, component_diffs, {cid_to_component, id_to_cid, uuids}}
  end

  @attempts 3

  # If the component has a static part, we see if other component has the same
  # static part. If so, we will simply point to the static part of the other cid.
  # We don't want to traverse the all components, so we will try it @attempts times.
  defp reuse_static(diff, socket, component, cid_to_component, id_to_cid) do
    with %{@static => _} <- diff,
         {print, _} = socket.fingerprints,
         iterator = :maps.iterator(Map.fetch!(id_to_cid, component)),
         {:ok, cid} <- find_same_component_print(print, iterator, cid_to_component, @attempts) do
      Map.put(diff, @static, cid)
    else
      _ -> diff
    end
  end

  defp find_same_component_print(_print, _iterator, _cid_to_component, 0), do: :none

  defp find_same_component_print(print, iterator, cid_to_component, attempts) do
    case :maps.next(iterator) do
      {_, cid, iterator} ->
        case cid_to_component do
          %{^cid => {_, _, _, _, {^print, _}}} -> {:ok, cid}
          %{} -> find_same_component_print(print, iterator, cid_to_component, attempts - 1)
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
    socket =
      configure_socket_for_component(
        socket,
        assigns,
        Map.take(socket.private, [:conn_session]),
        new_fingerprints()
      )
      |> Utils.assign(:flash, %{})

    Utils.maybe_call_mount!(socket, component, [socket])
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
