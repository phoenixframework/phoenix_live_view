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
  Renders a dif for the rendered struct in regards to the given socket.
  """
  def render(%{fingerprints: prints} = socket, %Rendered{} = rendered, components) do
    {diff, prints, component_diffs, components} =
      traverse(socket, rendered, prints, %{}, components)

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

        {diffs, components} =
          socket
          |> configure_socket_for_component(assigns, private, fingerprints)
          |> fun.(component)
          |> render_component(id, cid, false, component_diffs, components)

        {%{@components => diffs}, components}

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

    {Map.put(diff, @static, static), {fingerprint, children}, component_diffs, components}
  end

  defp traverse(
         socket,
         %Component{id: nil, component: component, assigns: assigns},
         fingerprints_tree,
         component_diffs,
         components
       ) do
    rendered = component_to_rendered(socket, component, assigns)
    traverse(socket, rendered, fingerprints_tree, component_diffs, components)
  end

  defp traverse(socket, %Component{} = component, fingerprints_tree, component_diffs, components) do
    {cid, component_diffs, components} =
      traverse_component(socket, component, component_diffs, components)

    {cid, fingerprints_tree, component_diffs, components}
  end

  defp traverse(
         socket,
         %Comprehension{dynamics: dynamics, fingerprint: fingerprint},
         fingerprint,
         component_diffs,
         components
       ) do
    {dynamics, {component_diffs, components}} =
      comprehension_to_iodata(socket, dynamics, component_diffs, components)

    {%{@dynamics => dynamics}, fingerprint, component_diffs, components}
  end

  defp traverse(
         socket,
         %Comprehension{static: static, dynamics: dynamics, fingerprint: fingerprint},
         _,
         component_diffs,
         components
       ) do
    {dynamics, {component_diffs, components}} =
      comprehension_to_iodata(socket, dynamics, component_diffs, components)

    {%{@dynamics => dynamics, @static => static}, fingerprint, component_diffs, components}
  end

  defp traverse(_socket, nil, fingerprint_tree, component_diffs, components) do
    {nil, fingerprint_tree, component_diffs, components}
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

  ## Stateful components helpers

  defp traverse_component(
         socket,
         %Component{id: id, assigns: assigns, component: component},
         component_diffs,
         components
       ) do
    id = {component, id}
    {socket, cid, new?, components} = ensure_component(socket, id, components)

    {component_diffs, components} =
      socket
      |> View.maybe_call_update!(component, assigns)
      |> render_component(id, cid, new?, component_diffs, components)

    {cid, component_diffs, components}
  end

  defp render_component(socket, {component, _} = id, cid, new?, component_diffs, components) do
    {socket, component_diffs, {id_to_components, cid_to_ids, uuids}} =
      if new? or View.changed?(socket) do
        rendered = View.to_rendered(socket, component)

        {diff, component_prints, component_diffs, components} =
          traverse(socket, rendered, socket.fingerprints, component_diffs, components)

        socket = View.clear_changed(%{socket | fingerprints: component_prints})
        component_diffs = Map.put(component_diffs, cid, diff)
        {socket, component_diffs, components}
      else
        {socket, component_diffs, components}
      end

    id_to_components = Map.put(id_to_components, id, dump_component(socket, cid))
    {component_diffs, {id_to_components, cid_to_ids, uuids}}
  end

  defp ensure_component(socket, {component, _} = id, {id_to_components, cid_to_ids, uuids}) do
    case id_to_components do
      %{^id => {cid, assigns, private, component_prints}} ->
        socket = configure_socket_for_component(socket, assigns, private, component_prints)
        {socket, cid, false, {id_to_components, cid_to_ids, uuids}}

      %{} ->
        cid = uuids
        socket = mount_component(socket, component)
        id_to_components = Map.put(id_to_components, id, dump_component(socket, cid))
        cid_to_ids = Map.put(cid_to_ids, cid, id)
        {socket, cid, true, {id_to_components, cid_to_ids, uuids + 1}}
    end
  end

  defp mount_component(socket, component) do
    socket
    |> configure_socket_for_component(%{}, %{}, new_fingerprints())
    |> View.maybe_call_mount!(component, [socket])
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
end
