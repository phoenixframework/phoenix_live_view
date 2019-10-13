defmodule Phoenix.LiveView.Diff do
  # The diff engine is responsible for tracking the rendering state.
  # Given that components are part of said state, they are also
  # handled here.
  @moduledoc false

  alias Phoenix.LiveView.{View, Rendered, Comprehension, Component}

  @components :c
  @static :s
  @dynamics :d

  @doc """
  Returns the diff component state.
  """
  def new_components do
    {_ids_to_state = %{}, _cids_to_id = %{}, _uuids = 0}
  end

  @doc """
  Returns the diff fingerprint state.
  """
  def new_fingerprints do
    {nil, %{}}
  end

  @doc """
  Renders a diff for the rendered struct in regards to the given socket.
  """
  def render(%{fingerprints: prints} = socket, %Rendered{} = rendered, components) do
    {diff, prints, pending_components, components} =
      traverse(socket, rendered, prints, %{}, components)

    {component_diffs, components} =
      render_pending_components(socket, pending_components, %{}, components)

    socket = %{socket | fingerprints: prints}

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

  ## Example

      {component_diffs, components} =
        with_component(socket, cid, %{}, state.components, fn socket, component ->
          case component.handle_event("...", ..., socket) do
            {:noreply, socket} -> socket
          end
        end)

  """
  def with_component(socket, cid, component_diffs, components, fun) when is_integer(cid) do
    {id_to_components, cid_to_ids, _} = components

    case cid_to_ids do
      %{^cid => {component, _} = id} ->
        {^cid, assigns, private, fingerprints} = Map.fetch!(id_to_components, id)

        {pending_components, component_diffs, components} =
          socket
          |> configure_socket_for_component(assigns, private, fingerprints)
          |> fun.(component)
          |> render_component(id, cid, false, %{}, component_diffs, components)

        {component_diffs, components} =
          render_pending_components(socket, pending_components, component_diffs, components)

        {%{@components => component_diffs}, components}

      %{} ->
        :error
    end
  end

  @doc """
  Updates the components with a list of `send_update` operations.

  Like `with_component/5`, it will store the result under the `cid
   key in the `component_diffs` map.

  It returns the updated `component_diffs` and the updated `components` or
  raises an `ArgumentError` if no component matching the update `:id` exists.

  Components are preloaded before the update callback.

  ## Example

    {diffs, new_components} = Diff.update_components(socket, state.components, updates)
  """
  def update_components(socket, components, updates) do
    {diffs, new_components} =
      Enum.reduce(updates, {[], components}, fn {module, id, updated_assigns}, {diffs, components_acc} ->
        {cid, existing_assigns} = fetch_component!(module, id, components_acc)
        [new_assigns] = maybe_update_preload(module, Map.merge(existing_assigns, updated_assigns))
        {diff, new_components} =
          with_component(socket, cid, %{}, components_acc, fn component_socket, component ->
            View.maybe_call_update!(component_socket, component, new_assigns)
          end)

        {[diff | diffs], new_components}
      end)

    {Enum.reverse(diffs), new_components}
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
  def component_to_rendered(socket, component, assigns) do
    socket
    |> mount_component(component)
    |> View.maybe_call_update!(component, assigns)
    |> View.to_rendered(component)
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
      traverse_dynamic(socket, dynamic, children, pending_components, components)

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
      traverse_dynamic(socket, dynamic, %{}, pending_components, components)

    {Map.put(diff, @static, static), {fingerprint, children}, pending_components, components}
  end

  defp traverse(
         socket,
         %Component{id: nil, component: component, assigns: assigns},
         fingerprints_tree,
         pending_components,
         components
       ) do
    rendered = component_to_rendered(socket, component, assigns)
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
        socket = mount_component(socket, component)
        id_to_components = Map.put(id_to_components, id, dump_component(socket, cid))
        cid_to_ids = Map.put(cid_to_ids, cid, id)
        {cid, true, {id_to_components, cid_to_ids, uuids + 1}}
    end
  end

  defp mount_component(socket, component) do
    socket = configure_socket_for_component(socket, %{}, %{}, new_fingerprints())
    View.maybe_call_mount!(socket, component, [socket])
  end

  defp configure_socket_for_component(socket, assigns, private, prints) do
    %{
      socket
      | assigns: assigns,
        private: private,
        fingerprints: prints
    }
  end

  defp dump_component(socket, cid) do
    {cid, socket.assigns, socket.private, socket.fingerprints}
  end

  ## Component rendering

  defp render_pending_components(_, pending_components, component_diffs, components)
       when map_size(pending_components) == 0 do
    {component_diffs, components}
  end

  defp render_pending_components(socket, pending_components, component_diffs, components) do
    {id_to_components, _, _} = components
    acc = {%{}, component_diffs, components}

    {pending_components, component_diffs, components} =
      Enum.reduce(pending_components, acc, fn {component, entries}, acc ->
        entries = maybe_preload_components(component, Enum.reverse(entries))

        Enum.reduce(entries, acc, fn {id, new?, new_assigns}, acc ->
          {pending_components, component_diffs, components} = acc
          id = {component, id}
          %{^id => {cid, assigns, private, component_prints}} = id_to_components

          socket
          |> configure_socket_for_component(assigns, private, component_prints)
          |> View.maybe_call_update!(component, new_assigns)
          |> render_component(id, cid, new?, pending_components, component_diffs, components)
        end)
      end)

    render_pending_components(socket, pending_components, component_diffs, components)
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

  # todo potentially batch in the future on send_update
  defp maybe_update_preload(module, assigns) do
    if function_exported?(module, :preload, 1) do
      module.preload([assigns])
    else
      [assigns]
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
      if new? or View.changed?(socket) do
        rendered = View.to_rendered(socket, component)

        {diff, component_prints, pending_components, components} =
          traverse(socket, rendered, socket.fingerprints, pending_components, components)

        socket = View.clear_changed(%{socket | fingerprints: component_prints})
        {socket, pending_components, Map.put(component_diffs, cid, diff), components}
      else
        {socket, pending_components, component_diffs, components}
      end

    id_to_components = Map.put(id_to_components, id, dump_component(socket, cid))
    {pending_components, component_diffs, {id_to_components, cid_to_ids, uuids}}
  end

  defp fetch_component!(module, id, components) do
    {id_to_components, _cid_to_ids, _} = components
    case Map.fetch(id_to_components, {module, id}) do
      {:ok, {cid, assigns, _, _}} -> {cid, assigns}
      :error ->
        raise ArgumentError, "no #{inspect(module)} component found with :id #{inspect(id)}"
    end
  end
end
