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
    {_ids_to_state = %{}, _cids_to_id = %{}, uuids}
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
  def to_iodata(map) do
    to_iodata(map, Map.get(map, @components, %{}))
  end

  defp to_iodata(%{@dynamics => dynamics, @static => static}, components) do
    for dynamic <- dynamics do
      comprehension_to_iodata(static, dynamic, components)
    end
  end

  defp to_iodata(%{@static => static} = parts, components) do
    parts_to_iodata(static, parts, 0, components)
  end

  defp to_iodata(int, components) when is_integer(int) do
    to_iodata(Map.fetch!(components, int), components)
  end

  defp to_iodata(binary, _components) when is_binary(binary) do
    binary
  end

  defp parts_to_iodata([last], _parts, _counter, _components) do
    [last]
  end

  defp parts_to_iodata([head | tail], parts, counter, components) do
    [
      head,
      to_iodata(Map.fetch!(parts, counter), components)
      | parts_to_iodata(tail, parts, counter + 1, components)
    ]
  end

  defp comprehension_to_iodata([static_head | static_tail], [dyn_head | dyn_tail], components) do
    [
      static_head,
      to_iodata(dyn_head, components)
      | comprehension_to_iodata(static_tail, dyn_tail, components)
    ]
  end

  defp comprehension_to_iodata([static_head], [], _components) do
    [static_head]
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
    {diff, prints, pending_components, components} =
      traverse(socket, rendered, prints, %{}, components)

    {component_diffs, components} =
      render_pending_components(socket, pending_components, %{}, %{}, components)

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
    {id_to_components, cid_to_ids, _} = components

    case cid_to_ids do
      %{^cid => {component, _} = id} ->
        {^cid, assigns, private, fingerprints} = Map.fetch!(id_to_components, id)

        {component_socket, extra} =
          socket
          |> configure_socket_for_component(assigns, private, fingerprints)
          |> fun.(component)

        {pending_components, component_diffs, components} =
          render_component(component_socket, id, cid, false, %{}, component_diffs, components)

        {component_diffs, components} =
          render_pending_components(socket, pending_components, %{}, component_diffs, components)

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
  def delete_component(cid, {id_to_components, cid_to_ids, uuids}) do
    {id, cid_to_ids} = Map.pop(cid_to_ids, cid)
    {Map.delete(id_to_components, id), cid_to_ids, uuids}
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
         pending_components,
         components
       ) do
    {_counter, diff, children, pending_components, components} =
      traverse_dynamic(socket, dynamic.(true), children, pending_components, components)

    {diff, {fingerprint, children}, pending_components, components}
  end

  defp traverse(
         socket,
         %Rendered{fingerprint: fingerprint, static: static, dynamic: dynamic},
         _,
         pending_components,
         components
       ) do
    {_counter, diff, children, pending_components, components} =
      traverse_dynamic(socket, dynamic.(false), %{}, pending_components, components)

    {Map.put(diff, @static, static), {fingerprint, children}, pending_components, components}
  end

  defp traverse(
         socket,
         %Component{id: nil, component: component, assigns: assigns},
         fingerprints_tree,
         pending_components,
         components
       ) do
    rendered = component_to_rendered(socket, component, assigns, %{})
    traverse(socket, rendered, fingerprints_tree, pending_components, components)
  end

  defp traverse(
         socket,
         %Component{} = component,
         fingerprints_tree,
         pending_components,
         components
       ) do
    {cid, pending_components, components} =
      traverse_component(socket, component, pending_components, components)

    {cid, fingerprints_tree, pending_components, components}
  end

  defp traverse(
         socket,
         %Comprehension{dynamics: dynamics, fingerprint: fingerprint},
         fingerprint,
         pending_components,
         components
       ) do
    {dynamics, {pending_components, components}} =
      comprehension_to_iodata(socket, dynamics, pending_components, components)

    {%{@dynamics => dynamics}, fingerprint, pending_components, components}
  end

  defp traverse(_socket, %Comprehension{dynamics: []}, _, pending_components, components) do
    # The comprehension has no elements and it was not rendered yet, so we skip it.
    {"", nil, pending_components, components}
  end

  defp traverse(
         socket,
         %Comprehension{static: static, dynamics: dynamics, fingerprint: fingerprint},
         _,
         pending_components,
         components
       ) do
    {dynamics, {pending_components, components}} =
      comprehension_to_iodata(socket, dynamics, pending_components, components)

    {%{@dynamics => dynamics, @static => static}, fingerprint, pending_components, components}
  end

  defp traverse(_socket, nil, fingerprint_tree, pending_components, components) do
    {nil, fingerprint_tree, pending_components, components}
  end

  defp traverse(_socket, iodata, _, pending_components, components) do
    {IO.iodata_to_binary(iodata), nil, pending_components, components}
  end

  defp traverse_dynamic(socket, dynamic, children, pending_components, components) do
    Enum.reduce(dynamic, {0, %{}, children, pending_components, components}, fn
      entry, {counter, diff, children, pending_components, components} ->
        {serialized, child_fingerprint, pending_components, components} =
          traverse(socket, entry, Map.get(children, counter), pending_components, components)

        diff =
          if serialized do
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

        {counter + 1, diff, children, pending_components, components}
    end)
  end

  defp comprehension_to_iodata(socket, dynamics, pending_components, components) do
    Enum.map_reduce(dynamics, {pending_components, components}, fn list, acc ->
      Enum.map_reduce(list, acc, fn rendered, {pending_components, components} ->
        {diff, _, pending_components, components} =
          traverse(socket, rendered, {nil, %{}}, pending_components, components)

        {diff, {pending_components, components}}
      end)
    end)
  end

  ## Stateful components helpers

  defp traverse_component(
         socket,
         %Component{id: id, assigns: assigns, component: component},
         pending_components,
         components
       ) do
    {cid, new?, components} = ensure_component(socket, {component, id}, components)
    entry = {id, new?, assigns}
    pending_components = Map.update(pending_components, component, [entry], &[entry | &1])
    {cid, pending_components, components}
  end

  defp ensure_component(socket, {component, _} = id, {id_to_components, cid_to_ids, uuids}) do
    case id_to_components do
      %{^id => {cid, _assigns, _private, _component_prints}} ->
        {cid, false, {id_to_components, cid_to_ids, uuids}}

      %{} ->
        cid = uuids
        socket = mount_component(socket, component, %{myself: cid})
        id_to_components = Map.put(id_to_components, id, dump_component(socket, cid))
        cid_to_ids = Map.put(cid_to_ids, cid, id)
        {cid, true, {id_to_components, cid_to_ids, uuids + 1}}
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

  defp dump_component(socket, cid) do
    {cid, socket.assigns, socket.private, socket.fingerprints}
  end

  ## Component rendering

  defp render_pending_components(_, pending_components, _seen_ids, component_diffs, components)
       when map_size(pending_components) == 0 do
    {component_diffs, components}
  end

  defp render_pending_components(
         socket,
         pending_components,
         seen_ids,
         component_diffs,
         components
       ) do
    {id_to_components, _, _} = components
    acc = {{%{}, component_diffs, components}, seen_ids}

    {{pending_components, component_diffs, components}, seen_ids} =
      Enum.reduce(pending_components, acc, fn {component, entries}, acc ->
        entries = maybe_preload_components(component, Enum.reverse(entries))

        Enum.reduce(entries, acc, fn {id, new?, new_assigns}, {triplet, seen_ids} ->
          {pending_components, component_diffs, components} = triplet
          id = {component, id}
          %{^id => {cid, assigns, private, component_prints}} = id_to_components

          if Map.has_key?(seen_ids, id) do
            raise "found duplicate ID #{inspect(elem(id, 1))} " <>
                    "for component #{inspect(elem(id, 0))} when rendering template"
          end

          triplet =
            socket
            |> configure_socket_for_component(assigns, private, component_prints)
            |> Utils.maybe_call_update!(component, new_assigns)
            |> render_component(id, cid, new?, pending_components, component_diffs, components)

          {triplet, Map.put(seen_ids, id, true)}
        end)
      end)

    render_pending_components(socket, pending_components, seen_ids, component_diffs, components)
  end

  defp maybe_preload_components(component, entries) do
    if function_exported?(component, :preload, 1) do
      list_of_assigns = Enum.map(entries, fn {_id, _new?, new_assigns} -> new_assigns end)
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

  defp zip_preloads([new_assigns | assigns], [{id, new?, _} | entries], component, preloaded)
       when is_map(new_assigns) do
    [{id, new?, new_assigns} | zip_preloads(assigns, entries, component, preloaded)]
  end

  defp zip_preloads([], [], _component, _preloaded) do
    []
  end

  defp zip_preloads(_, _, component, preloaded) do
    raise ArgumentError,
          "expected #{inspect(component)}.preload/1 to return a list of maps of the same length " <>
            "as the list of assigns given, got: #{inspect(preloaded)}"
  end

  defp render_component(socket, id, cid, new?, pending_components, component_diffs, components) do
    {component, _} = id

    {socket, pending_components, component_diffs, {id_to_components, cid_to_ids, uuids}} =
      if new? or Utils.changed?(socket) do
        rendered = Utils.to_rendered(socket, component)

        {diff, component_prints, pending_components, components} =
          traverse(socket, rendered, socket.fingerprints, pending_components, components)

        socket = Utils.clear_changed(%{socket | fingerprints: component_prints})
        {socket, pending_components, Map.put(component_diffs, cid, diff), components}
      else
        {socket, pending_components, Map.put(component_diffs, cid, %{}), components}
      end

    id_to_components = Map.put(id_to_components, id, dump_component(socket, cid))
    {pending_components, component_diffs, {id_to_components, cid_to_ids, uuids}}
  end

  defp fetch_cid(module, id, {id_to_components, _cid_to_ids, _} = _components) do
    case Map.fetch(id_to_components, {module, id}) do
      {:ok, {cid, _, _, _}} -> {:ok, cid}
      :error -> :error
    end
  end
end
