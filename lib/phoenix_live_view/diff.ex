defmodule Phoenix.LiveView.Diff do
  # The diff engine is responsible for tracking the rendering state.
  # Given that components are part of said state, they are also
  # handled here.
  @moduledoc false

  alias Phoenix.LiveView.{View, Rendered, Comprehension, Component}

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
  Renders a dif for the rendered struct in regards to the given socket.
  """
  def render(%{fingerprints: prints} = socket, %Rendered{} = rendered, components) do
    {diff, prints, component_diffs, components} =
      traverse(socket, rendered, prints, %{}, components)

    socket = %{socket | fingerprints: prints}

    if map_size(component_diffs) == 0 do
      {socket, diff, components}
    else
      {socket, Map.put(diff, :components, component_diffs), components}
    end
  end

  @doc """
  Execute the `fun` with the component `cid` with the given `socket` as template.

  It will store the result under the `cid` key in the `component_diffs` map.

  It returns the updated `component_diffs` and the updated `components` or
  `:error` if the component cid does not exist.
  """
  def with_component(socket, cid, new?, component_diffs, components, fun) do
    {id_to_components, cid_to_ids, _} = components

    case cid_to_ids do
      %{^cid => id} ->
        {^cid, component, assigns, private, fingerprints} = Map.fetch!(id_to_components, id)

        socket =
          socket
          |> View.configure_component_socket(assigns, private, fingerprints)
          |> fun.(component)

        {socket, component_diffs, {id_to_components, cid_to_ids, uuids}} =
          if new? or View.changed?(socket) do
            rendered = View.to_rendered(socket, component)

            {diff, component_prints, component_diffs, components} =
              traverse(socket, rendered, fingerprints, component_diffs, components)

            socket = View.clear_changed(%{socket | fingerprints: component_prints})
            component_diffs = Map.put(component_diffs, cid, diff)
            {socket, component_diffs, components}
          else
            {socket, component_diffs, components}
          end

        id_to_components = Map.put(id_to_components, id, dump_component(socket, cid, component))
        {component_diffs, {id_to_components, cid_to_ids, uuids}}

      %{} ->
        :error
    end
  end

  @doc """
  Deletes a component by `cid`.
  """
  def delete_component(cid, {id_to_components, cid_to_ids, uuids}) do
    {id, cid_to_ids} = Map.pop(cid_to_ids, cid)
    {Map.delete(id_to_components, id), cid_to_ids, uuids}
  end

  ## Traversal

  defp traverse(
         socket,
         %Rendered{fingerprint: fingerprint, dynamic: dynamic},
         {fingerprint, children},
         component_diffs,
         components
       ) do
    {_counter, diff, children, component_diffs, components} =
      traverse_dynamic(socket, dynamic, children, component_diffs, components)

    {diff, {fingerprint, children}, component_diffs, components}
  end

  defp traverse(
         socket,
         %Rendered{fingerprint: fingerprint, static: static, dynamic: dynamic},
         _,
         component_diffs,
         components
       ) do
    {_counter, diff, children, component_diffs, components} =
      traverse_dynamic(socket, dynamic, %{}, component_diffs, components)

    {Map.put(diff, :static, static), {fingerprint, children}, component_diffs, components}
  end

  defp traverse(socket, %Component{} = component, fingerprints_tree, component_diffs, components) do
    {cid, component_diffs, components} =
      render_component(socket, component, component_diffs, components)

    {cid, fingerprints_tree, component_diffs, components}
  end

  defp traverse(_socket, nil, fingerprint_tree, component_diffs, components) do
    {nil, fingerprint_tree, component_diffs, components}
  end

  defp traverse(
         socket,
         %Comprehension{dynamics: dynamics},
         :comprehension,
         component_diffs,
         components
       ) do
    {dynamics, {component_diffs, components}} =
      comprehension_to_iodata(socket, dynamics, component_diffs, components)

    {%{dynamics: dynamics}, :comprehension, component_diffs, components}
  end

  defp traverse(
         socket,
         %Comprehension{static: static, dynamics: dynamics},
         _,
         component_diffs,
         components
       ) do
    {dynamics, {component_diffs, components}} =
      comprehension_to_iodata(socket, dynamics, component_diffs, components)

    {%{dynamics: dynamics, static: static}, :comprehension, component_diffs, components}
  end

  defp traverse(_socket, iodata, _, component_diffs, components) do
    {IO.iodata_to_binary(iodata), nil, component_diffs, components}
  end

  defp traverse_dynamic(socket, dynamic, children, component_diffs, components) do
    Enum.reduce(dynamic, {0, %{}, children, component_diffs, components}, fn
      entry, {counter, diff, children, component_diffs, components} ->
        {serialized, child_fingerprint, component_diffs, components} =
          traverse(socket, entry, Map.get(children, counter), component_diffs, components)

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

        {counter + 1, diff, children, component_diffs, components}
    end)
  end

  defp comprehension_to_iodata(socket, dynamics, component_diffs, components) do
    Enum.map_reduce(dynamics, {component_diffs, components}, fn list, acc ->
      Enum.map_reduce(list, acc, fn rendered, {component_diffs, components} ->
        {diff, _, component_diffs, components} =
          traverse(socket, rendered, {nil, %{}}, component_diffs, components)

        {diff, {component_diffs, components}}
      end)
    end)
  end

  ## Components helpers

  defp ensure_component(socket, id, component, {id_to_components, cid_to_ids, uuids}) do
    case id_to_components do
      %{^id => {cid, ^component, _assigns, _private, _component_prints}} ->
        {cid, false, {id_to_components, cid_to_ids, uuids}}

      %{^id => {cid, _, _, _, _}} ->
        build_component(socket, id, cid, component, id_to_components, cid_to_ids, uuids)

      %{} ->
        cid_to_ids = Map.put(cid_to_ids, uuids, id)
        build_component(socket, id, uuids, component, id_to_components, cid_to_ids, uuids + 1)
    end
  end

  defp build_component(socket, id, cid, component, id_to_components, cid_to_ids, uuids) do
    socket = View.configure_component_socket(socket, %{}, %{}, new_fingerprints())

    socket =
      if function_exported?(component, :mount, 1) do
        View.call_mount!(component, [socket])
      else
        socket
      end

    id_to_components = Map.put(id_to_components, id, dump_component(socket, cid, component))
    {cid, true, {id_to_components, cid_to_ids, uuids}}
  end

  defp dump_component(socket, cid, component) do
    {cid, component, socket.assigns, socket.private, socket.fingerprints}
  end

  defp render_component(
         socket,
         %Component{id: id, assigns: assigns, component: component},
         component_diffs,
         components
       ) do
    {cid, new?, components} = ensure_component(socket, id, component, components)

    {component_diffs, components} =
      with_component(socket, cid, new?, component_diffs, components, fn socket, component ->
        View.maybe_call_update!(component, assigns, socket)
      end)

    {cid, component_diffs, components}
  end
end
