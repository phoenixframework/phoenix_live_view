defmodule Phoenix.LiveView.Diff do
  # The diff engine is responsible for tracking the rendering state.
  # Given that components are part of said state, they are also
  # handled here.
  @moduledoc false

  alias Phoenix.LiveView.{
    Component,
    Comprehension,
    Lifecycle,
    Rendered,
    Utils
  }

  @components :c
  @static :s
  @keyed :k
  @keyed_count :kc
  @events :e
  @reply :r
  @title :t
  @template :p
  @stream :stream

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
    to_iodata(map, Map.get(map, @components, %{}), Map.get(map, @template), component_mapper)
    |> elem(0)
  end

  defp to_iodata(
         %{@static => static, @keyed => keyed} = kc,
         components,
         template,
         mapper
       ) do
    template = template || kc[@template]

    if !keyed or keyed[@keyed_count] == 0 do
      {[], components}
    else
      {diff, {components, _}} =
        Enum.map_reduce(0..(keyed[@keyed_count] - 1), {components, nil}, fn
          index, {components, canonical_diff} ->
            diff = Map.fetch!(keyed, index)
            canonical_diff = canonical_diff || diff
            # merge nested statics from canonical diff
            diff = deep_merge(canonical_diff, diff)

            {iodata, components} =
              to_iodata(Map.put(diff, @static, static), components, template, mapper)

            {iodata, {components, canonical_diff}}
        end)

      {diff, components}
    end
  end

  defp to_iodata(%{@static => static} = parts, components, template, mapper) do
    static = template_static(static, template)
    one_to_iodata(static, parts, 0, [], components, template, mapper)
  end

  defp to_iodata(cid, components, _template, mapper) when is_integer(cid) do
    # Resolve component pointers and update the component entries
    components = resolve_components_xrefs(cid, components)
    {iodata, components} = to_iodata(Map.fetch!(components, cid), components, nil, mapper)
    {mapper.(cid, iodata), components}
  end

  defp to_iodata(binary, components, _template, _mapper) when is_binary(binary) do
    {binary, components}
  end

  defp one_to_iodata([last], _parts, _counter, acc, components, _template, _mapper) do
    {Enum.reverse([last | acc]), components}
  end

  defp one_to_iodata([head | tail], parts, counter, acc, components, template, mapper) do
    {iodata, components} = to_iodata(Map.fetch!(parts, counter), components, template, mapper)
    one_to_iodata(tail, parts, counter + 1, [iodata, head | acc], components, template, mapper)
  end

  defp template_static(static, template) when is_integer(static), do: Map.fetch!(template, static)
  defp template_static(static, _template) when is_list(static), do: static

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
    diff
    |> maybe_put_reply(socket)
    |> maybe_put_events(socket)
  end

  @doc """
  Renders a diff for the rendered struct in regards to the given socket.
  """
  def render(
        socket,
        %Rendered{fingerprint: actual} = rendered,
        {expected, _},
        {_, _, uuids}
      )
      when expected != nil and expected != actual do
    render(socket, rendered, new_fingerprints(), new_components(uuids))
  end

  def render(socket, %Rendered{} = rendered, prints, components) do
    {diff, prints, pending, components, template} =
      traverse(rendered, prints, %{}, components, {%{}, %{}}, true)

    # cid_to_component is used by maybe_reuse_static and it must be a copy before changes.
    # However, given traverse does not change cid_to_component, we can read it now.
    {cid_to_component, _, _} = components

    {cdiffs, components} =
      render_pending_components(socket, pending, cid_to_component, %{}, components)

    diff =
      diff
      |> maybe_add_template(template)
      |> maybe_put_title(socket)

    {diff, cdiffs} = extract_events({diff, cdiffs})
    {maybe_put_cdiffs(diff, cdiffs), prints, components}
  end

  defp maybe_put_cdiffs(diff, cdiffs) when cdiffs == %{}, do: diff
  defp maybe_put_cdiffs(diff, cdiffs), do: Map.put(diff, @components, cdiffs)

  @doc """
  Returns a diff containing only the events that have been pushed.
  """
  def get_push_events_diff(socket) do
    if events = Utils.get_push_events(socket), do: %{@events => events}
  end

  defp maybe_put_title(diff, socket) do
    if Utils.changed?(socket.assigns, :page_title) do
      Map.put(diff, @title, socket.assigns.page_title)
    else
      diff
    end
  end

  defp maybe_put_events(diff, socket) do
    case Utils.get_push_events(socket) do
      [_ | _] = events -> Map.update(diff, @events, events, &(&1 ++ events))
      [] -> diff
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

  It returns the updated `cdiffs` and the updated `components` or
  `:error` if the component cid does not exist.
  """
  def write_component(socket, cid, components, fun) when is_integer(cid) do
    # We need to extract the original cid_to_component for maybe_reuse_static later
    {cids, _, _} = components

    case cids do
      %{^cid => {component, id, assigns, private, prints}} ->
        {csocket, extra} =
          socket
          |> configure_socket_for_component(assigns, private)
          |> fun.(component)

        diff = render_private(csocket, %{})

        {pending, cdiffs, components} =
          render_component(csocket, component, id, prints, cid, false, cids, %{}, components)

        {cdiffs, components} =
          render_pending_components(socket, pending, cids, cdiffs, components)

        {diff, cdiffs} = extract_events({diff, cdiffs})
        {maybe_put_cdiffs(diff, cdiffs), components, extra}

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
      %{^cid => {component, _id, assigns, private, _prints}} ->
        socket
        |> configure_socket_for_component(assigns, private)
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
  def update_component(socket, components, {ref, updated_assigns}) do
    case fetch_cid(ref, components) do
      {:ok, {cid, module}} ->
        updated_assigns = maybe_call_preload!(module, updated_assigns)

        {diff, new_components, :noop} =
          write_component(socket, cid, components, fn component_socket, component ->
            telemetry_metadata = %{
              socket: socket,
              component: component,
              assigns_sockets: [{updated_assigns, component_socket}]
            }

            sockets =
              :telemetry.span([:phoenix, :live_component, :update], telemetry_metadata, fn ->
                {Utils.maybe_call_update!(component_socket, component, updated_assigns),
                 telemetry_metadata}
              end)

            {sockets, :noop}
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
    component_socket = mount_component(socket, component, mount_assigns)
    assigns = maybe_call_preload!(component, assigns)

    telemetry_metadata = %{
      socket: socket,
      component: component,
      assigns_sockets: [{assigns, component_socket}]
    }

    :telemetry.span([:phoenix, :live_component, :update], telemetry_metadata, fn ->
      result =
        component_socket
        |> Utils.maybe_call_update!(component, assigns)
        |> component_to_rendered(component, assigns[:id])

      {result, telemetry_metadata}
    end)
  end

  defp component_to_rendered(socket, component, id) do
    rendered = Phoenix.LiveView.Renderer.to_rendered(socket, component)

    if rendered.root != true and id != nil do
      reason =
        case rendered.root do
          nil -> "Stateful components must return a HEEx template (~H sigil or .heex extension)"
          false -> "Stateful components must have a single static HTML tag at the root"
        end

      raise ArgumentError,
            "error on #{inspect(component)}.render/1 with id of #{inspect(id)}. #{reason}"
    end

    rendered
  end

  ## Traversal

  defp traverse(
         %Rendered{fingerprint: fingerprint} = rendered,
         {fingerprint, children},
         pending,
         components,
         template,
         changed?
       ) do
    {_counter, diff, children, pending, components, template} =
      traverse_dynamic(
        invoke_dynamic(rendered, changed?),
        children,
        pending,
        components,
        template,
        changed?
      )

    {diff, {fingerprint, children}, pending, components, template}
  end

  defp traverse(
         %Rendered{fingerprint: fingerprint, static: static} = rendered,
         _,
         pending,
         components,
         template,
         changed?
       ) do
    {_counter, diff, children, pending, components, template} =
      traverse_dynamic(
        invoke_dynamic(rendered, false),
        %{},
        pending,
        components,
        template,
        changed?
      )

    diff = if rendered.root, do: Map.put(diff, :r, 1), else: diff
    {diff, template} = maybe_share_template(diff, fingerprint, static, template)
    {diff, {fingerprint, children}, pending, components, template}
  end

  defp traverse(
         %Component{} = component,
         _fingerprints_tree,
         pending,
         components,
         template,
         _changed?
       ) do
    {cid, pending, components} = traverse_component(component, pending, components)
    {cid, nil, pending, components, template}
  end

  defp traverse(
         %Comprehension{
           fingerprint: fingerprint,
           entries: entries,
           stream: stream,
           has_key?: has_key?
         },
         {fingerprint, previous_prints},
         pending,
         components,
         template,
         changed?
       ) do
    if template do
      {keyed, keyed_prints, pending, components, template} =
        traverse_keyed(
          entries,
          previous_prints,
          pending,
          components,
          template,
          changed?,
          stream != nil,
          has_key?
        )

      diff =
        %{}
        |> maybe_add_keyed(keyed)
        |> maybe_add_stream(stream)

      {diff, {fingerprint, keyed_prints}, pending, components, template}
    else
      {keyed, keyed_prints, pending, components, template} =
        traverse_keyed(
          entries,
          previous_prints,
          pending,
          components,
          {%{}, %{}},
          changed?,
          stream != nil,
          has_key?
        )

      diff =
        %{}
        |> maybe_add_keyed(keyed)
        |> maybe_add_stream(stream)
        |> maybe_add_template(template)

      {diff, {fingerprint, keyed_prints}, pending, components, nil}
    end
  end

  defp traverse(
         %Comprehension{entries: [], stream: nil},
         _,
         pending,
         components,
         template,
         _changed?
       ) do
    # The comprehension has no elements and it was not rendered yet,
    # so we can skip it as long as it doesn't have a stream.
    {"", nil, pending, components, template}
  end

  defp traverse(
         %Comprehension{
           static: static,
           fingerprint: fingerprint,
           entries: entries,
           stream: stream,
           has_key?: has_key?
         },
         _,
         pending,
         components,
         template,
         changed?
       ) do
    if template do
      {keyed, keyed_prints, pending, components, template} =
        traverse_keyed(
          entries,
          %{},
          pending,
          components,
          template,
          changed?,
          stream != nil,
          has_key?
        )

      {diff, template} =
        %{@keyed => keyed}
        |> maybe_add_stream(stream)
        |> maybe_share_template(fingerprint, static, template)

      {diff, {fingerprint, keyed_prints}, pending, components, template}
    else
      {keyed, keyed_prints, pending, components, template} =
        traverse_keyed(
          entries,
          %{},
          pending,
          components,
          {%{}, %{}},
          changed?,
          stream != nil,
          has_key?
        )

      diff =
        %{@static => static, @keyed => keyed}
        |> maybe_add_stream(stream)
        |> maybe_add_template(template)

      {diff, {fingerprint, keyed_prints}, pending, components, nil}
    end
  end

  defp traverse(nil, fingerprint_tree, pending, components, template, _changed?) do
    {nil, fingerprint_tree, pending, components, template}
  end

  defp traverse(iodata, _, pending, components, template, _changed?) do
    {IO.iodata_to_binary(iodata), nil, pending, components, template}
  end

  defp invoke_dynamic(%Rendered{caller: :not_available, dynamic: dynamic}, changed?) do
    dynamic.(changed?)
  end

  defp invoke_dynamic(%Rendered{caller: caller, dynamic: dynamic}, changed?) do
    try do
      dynamic.(changed?)
    rescue
      e ->
        {mod, {function, arity}, file, line} = caller
        entry = {mod, function, arity, file: String.to_charlist(file), line: line}
        reraise e, inject_stacktrace(__STACKTRACE__, entry)
    end
  end

  defp inject_stacktrace([{__MODULE__, :invoke_dynamic, 2, _} | stacktrace], entry) do
    [entry | Enum.drop_while(stacktrace, &(elem(&1, 0) == __MODULE__))]
  end

  defp inject_stacktrace([head | tail], entry) do
    [head | inject_stacktrace(tail, entry)]
  end

  defp inject_stacktrace([], entry) do
    [entry]
  end

  defp traverse_dynamic(dynamic, children, pending, components, template, changed?) do
    Enum.reduce(dynamic, {0, %{}, children, pending, components, template}, fn
      entry, {counter, diff, children, pending, components, template} ->
        child = Map.get(children, counter)

        {serialized, child_fingerprint, pending, components, template} =
          traverse(entry, child, pending, components, template, changed?)

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

        {counter + 1, diff, children, pending, components, template}
    end)
  end

  defp traverse_keyed(
         entries,
         previous_prints,
         pending,
         components,
         template,
         changed?,
         stream?,
         has_key?
       ) do
    diff = %{}
    new_prints = %{}

    {{diff, count, new_prints, pending, components, template, _canonical_print}, _seen_keys} =
      Enum.reduce(
        entries,
        {{diff, 0, new_prints, pending, components, template, nil}, MapSet.new()},
        fn
          {key, vars, render},
          {{_diff, index, _new_prints, _pending, _components, _template, _canonical_print} = acc,
           seen_keys} ->
            {key, seen_keys} =
              cond do
                not has_key? ->
                  # no need to check for duplicates if we use the index
                  {index, seen_keys}

                MapSet.member?(seen_keys, key) ->
                  raise "found duplicate key #{inspect(key)} in comprehension"

                true ->
                  {key, MapSet.put(seen_keys, key)}
              end

            {process_keyed({key, vars, render}, previous_prints, changed?, stream?, acc),
             seen_keys}
        end
      )

    # we don't need to send the diff if nothing changed;
    if diff == %{} and count > 0 and count == map_size(previous_prints) do
      {nil, new_prints, pending, components, template}
    else
      {Map.put(diff, @keyed_count, count), new_prints, pending, components, template}
    end
  end

  # it's an existing entry
  defp process_keyed({key, new_vars, render}, previous_prints, changed?, stream?, acc)
       when is_map_key(previous_prints, key) and not stream? do
    {diff, index, new_prints, pending, components, template, canonical_print} = acc

    %{vars: previous_vars, index: previous_index, child_prints: child_prints} =
      Map.fetch!(previous_prints, key)

    vars_changed =
      Enum.reduce(new_vars, Map.put(previous_vars, :__changed__, %{}), fn
        {key, value}, acc ->
          Phoenix.Component.assign(acc, key, value)
      end)
      |> Map.fetch!(:__changed__)

    {_counter, child_diff, child_prints, pending, components, template} =
      traverse_dynamic(
        render.(vars_changed, changed?),
        child_prints,
        pending,
        components,
        template,
        changed?
      )

    canonical_print = canonical_print || child_prints

    new_prints =
      Map.put(new_prints, key, %{index: index, vars: new_vars, child_prints: child_prints})

    # if the diff is empty, we need to check if the item moved
    if child_diff == %{} or child_diff == nil do
      # check if the entry moved, then annotate it with the previous index
      diff = if previous_index != index, do: Map.put(diff, index, previous_index), else: diff
      {diff, index + 1, new_prints, pending, components, template, canonical_print}
    else
      child_diff =
        if previous_index != index do
          [previous_index, child_diff]
        else
          child_diff
        end

      {Map.put(diff, index, child_diff), index + 1, new_prints, pending, components, template,
       canonical_print}
    end
  end

  # it's a new entry
  defp process_keyed({key, vars, render}, _previous_prints, _changed?, stream?, acc) do
    {diff, index, new_prints, pending, components, template, canonical_print} = acc

    {_counter, child_diff, child_prints, pending, components, template} =
      traverse_dynamic(
        render.(%{}, false),
        if(canonical_print, do: canonical_print, else: %{}),
        pending,
        components,
        template,
        # we need to disable change-tracking to force a full render,
        # even if some parts of the template might not have changed themselves
        false
      )

    canonical_print = canonical_print || child_prints

    # if this is a stream, we don't store any fingerprints
    new_prints =
      if stream? do
        {%{}, nil}
      else
        Map.put(new_prints, key, %{index: index, vars: vars, child_prints: child_prints})
      end

    diff = Map.put(diff, index, child_diff)

    {diff, index + 1, new_prints, pending, components, template, canonical_print}
  end

  defp maybe_share_template(map, fingerprint, static, {print_to_pos, pos_to_static}) do
    case print_to_pos do
      %{^fingerprint => pos} ->
        {Map.put(map, @static, pos), {print_to_pos, pos_to_static}}

      %{} ->
        pos = map_size(pos_to_static)
        pos_to_static = Map.put(pos_to_static, pos, static)
        print_to_pos = Map.put(print_to_pos, fingerprint, pos)
        {Map.put(map, @static, pos), {print_to_pos, pos_to_static}}
    end
  end

  defp maybe_share_template(map, _fingerprint, static, nil) do
    {Map.put(map, @static, static), nil}
  end

  defp maybe_add_template(map, {_, template}) when template != %{},
    do: Map.put(map, @template, template)

  defp maybe_add_template(map, _new_template), do: map

  defp maybe_add_stream(diff, nil = _stream), do: diff
  defp maybe_add_stream(diff, stream), do: Map.put(diff, @stream, stream)

  defp maybe_add_keyed(diff, nil = _keyed), do: diff
  defp maybe_add_keyed(diff, keyed), do: Map.put(diff, @keyed, keyed)

  ## Stateful components helpers

  defp traverse_component(
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

  defp render_pending_components(socket, pending, cids, diffs, components) do
    render_pending_components(socket, pending, %{}, cids, diffs, components)
  end

  defp render_pending_components(_, pending, _seen_ids, _cids, diffs, components)
       when map_size(pending) == 0 do
    {diffs, components}
  end

  defp render_pending_components(socket, pending, seen_ids, cids, diffs, components) do
    acc = {{%{}, diffs, components}, seen_ids}

    {{pending, diffs, components}, seen_ids} =
      Enum.reduce(pending, acc, fn {component, entries}, acc ->
        {{pending, diffs, components}, seen_ids} = acc
        update_many? = function_exported?(component, :update_many, 1)
        entries = maybe_preload_components(component, Enum.reverse(entries))

        {assigns_sockets, metadata, components, seen_ids} =
          Enum.reduce(entries, {[], [], components, seen_ids}, fn
            {cid, id, new?, new_assigns}, {assigns_sockets, metadata, components, seen_ids} ->
              if Map.has_key?(seen_ids, [component | id]) do
                raise "found duplicate ID #{inspect(id)} " <>
                        "for component #{inspect(component)} when rendering template"
              end

              {socket, components, prints} =
                case cids do
                  %{^cid => {_component, _id, assigns, private, prints}} ->
                    {private, components} = unmark_for_deletion(private, components)
                    {configure_socket_for_component(socket, assigns, private), components, prints}

                  %{} ->
                    myself_assigns = %{myself: %Phoenix.LiveComponent.CID{cid: cid}}

                    {mount_component(socket, component, myself_assigns),
                     put_cid(components, component, id, cid), new_fingerprints()}
                end

              assigns_sockets = [{new_assigns, socket} | assigns_sockets]
              metadata = [{cid, id, prints, new?} | metadata]
              seen_ids = Map.put(seen_ids, [component | id], true)
              {assigns_sockets, metadata, components, seen_ids}
          end)

        assigns_sockets = Enum.reverse(assigns_sockets)

        telemetry_metadata = %{
          socket: socket,
          component: component,
          assigns_sockets: assigns_sockets
        }

        sockets =
          :telemetry.span([:phoenix, :live_component, :update], telemetry_metadata, fn ->
            sockets =
              if update_many? do
                component.update_many(assigns_sockets)
              else
                Enum.map(assigns_sockets, fn {assigns, socket} ->
                  Utils.maybe_call_update!(socket, component, assigns)
                end)
              end

            {sockets, Map.put(telemetry_metadata, :sockets, sockets)}
          end)

        metadata = Enum.reverse(metadata)
        triplet = zip_components(sockets, metadata, component, cids, {pending, diffs, components})
        {triplet, seen_ids}
      end)

    render_pending_components(socket, pending, seen_ids, cids, diffs, components)
  end

  defp zip_components(
         [%{__struct__: Phoenix.LiveView.Socket} = socket | sockets],
         [{cid, id, prints, new?} | metadata],
         component,
         cids,
         {pending, diffs, components}
       ) do
    diffs = maybe_put_events(diffs, socket)

    {new_pending, diffs, components} =
      render_component(socket, component, id, prints, cid, new?, cids, diffs, components)

    pending = Map.merge(pending, new_pending, fn _, v1, v2 -> v2 ++ v1 end)
    zip_components(sockets, metadata, component, cids, {pending, diffs, components})
  end

  defp zip_components([], [], _component, _cids, acc) do
    acc
  end

  defp zip_components(_sockets, _metadata, component, _cids, _acc) do
    raise "#{inspect(component)}.update_many/1 must return a list of Phoenix.LiveView.Socket " <>
            "of the same length as the input list, got mismatched return type"
  end

  defp maybe_preload_components(component, entries) do
    if function_exported?(component, :preload, 1) do
      IO.warn("#{inspect(component)}.preload/1 is deprecated, use update_many/1 instead")
      list_of_assigns = Enum.map(entries, fn {_cid, _id, _new?, new_assigns} -> new_assigns end)
      result = component.preload(list_of_assigns)
      zip_preloads(result, entries, component, result)
    else
      entries
    end
  end

  defp maybe_call_preload!(module, assigns) do
    if function_exported?(module, :preload, 1) do
      IO.warn("#{inspect(module)}.preload/1 is deprecated, use update_many/1 instead")
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

  defp render_component(socket, component, id, prints, cid, new?, cids, diffs, components) do
    changed? = new? or Utils.changed?(socket)

    {socket, prints, pending, diff, components} =
      if changed? do
        rendered = component_to_rendered(socket, component, id)

        {changed?, linked_cid, prints} =
          maybe_reuse_static(rendered, component, prints, cids, components)

        {diff, prints, pending, components, nil} =
          traverse(rendered, prints, %{}, components, nil, changed?)

        children_cids =
          for {_component, list} <- pending,
              entry <- list,
              do: elem(entry, 0)

        diff = if linked_cid, do: Map.put(diff, @static, linked_cid), else: diff

        socket =
          put_in(socket.private.children_cids, children_cids)
          |> Lifecycle.after_render()
          |> Utils.clear_changed()

        {socket, prints, pending, diff, components}
      else
        {socket, prints, %{}, %{}, components}
      end

    diffs =
      if diff != %{} or new? do
        Map.put(diffs, cid, diff)
      else
        diffs
      end

    dump =
      socket
      |> Utils.clear_temp()
      |> dump_component(component, id, prints)

    {cid_to_component, id_to_cid, uuids} = components
    cid_to_component = Map.put(cid_to_component, cid, dump)
    {pending, diffs, {cid_to_component, id_to_cid, uuids}}
  end

  defp unmark_for_deletion(private, {cid_to_component, id_to_cid, uuids}) do
    {private, cid_to_component} = do_unmark_for_deletion(private, cid_to_component)
    {private, {cid_to_component, id_to_cid, uuids}}
  end

  defp do_unmark_for_deletion(private, cids) do
    {marked?, private} = Map.pop(private, @marked_for_deletion, false)

    cids =
      if marked? do
        Enum.reduce(private.children_cids, cids, fn cid, cids ->
          case cids do
            %{^cid => {component, id, assigns, private, prints}} ->
              {private, cids} = do_unmark_for_deletion(private, cids)
              Map.put(cids, cid, {component, id, assigns, private, prints})

            %{} ->
              cids
          end
        end)
      else
        cids
      end

    {private, cids}
  end

  # 32 is one bucket from large maps
  @attempts 32

  # If the component is new or is getting a new static root, we search if another
  # component has the same tree root. If so, we will point to the whole existing
  # component tree but say all entries require a full render.
  #
  # When looking up for an existing component, we first look into the tree from the
  # previous render, then we look at the new render. This is to avoid using a tree
  # that will be changed before it is sent to the client.
  #
  # We don't want to traverse all of the components, so we will try it @attempts times.
  defp maybe_reuse_static(rendered, component, prints, old_cids, components) do
    {new_cids, id_to_cid, _uuids} = components
    {current_print, _} = prints
    %{fingerprint: print} = rendered

    with true <- current_print != print,
         iterator = :maps.iterator(Map.fetch!(id_to_cid, component)),
         {cid, existing_prints} <-
           find_same_component_print(print, iterator, old_cids, new_cids, @attempts) do
      {false, cid, existing_prints}
    else
      _ -> {true, nil, prints}
    end
  end

  defp find_same_component_print(_print, _iterator, _old_cids, _new_cids, 0), do: :none

  defp find_same_component_print(print, iterator, old_cids, new_cids, attempts) do
    case :maps.next(iterator) do
      {_, cid, iterator} ->
        case old_cids do
          # if a component is marked for deletion, we cannot share its statics since it may be removed
          %{^cid => {_, _, _, %{@marked_for_deletion => true}, {^print, _} = _tree}} ->
            find_same_component_print(print, iterator, old_cids, new_cids, attempts - 1)

          %{^cid => {_, _, _, _private, {^print, _} = tree}} ->
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

  defp fetch_cid(
         %Phoenix.LiveComponent.CID{cid: cid},
         {cid_to_components, _id_to_cid, _} = _components
       ) do
    case cid_to_components do
      %{^cid => {component, _id, _assigns, _private, _fingerprints}} -> {:ok, {cid, component}}
      %{} -> :error
    end
  end

  defp fetch_cid({component, id}, {_cid_to_components, id_to_cid, _} = _components) do
    case id_to_cid do
      %{^component => %{^id => cid}} -> {:ok, {cid, component}}
      %{} -> :error
    end
  end

  defp mount_component(socket, component, assigns) do
    private =
      socket.private
      |> Map.take([:conn_session, :root_view])
      |> Map.put(:live_temp, %{})
      |> Map.put(:children_cids, [])
      |> Map.put(:lifecycle, %Phoenix.LiveView.Lifecycle{})

    socket =
      configure_socket_for_component(socket, assigns, private)
      |> Utils.assign(:flash, %{})

    Utils.maybe_call_live_component_mount!(socket, component)
  end

  defp configure_socket_for_component(socket, assigns, private) do
    %{
      socket
      | assigns: Map.put(assigns, :__changed__, %{}),
        private: private,
        redirected: nil
    }
  end

  defp dump_component(socket, component, id, prints) do
    {component, id, socket.assigns, socket.private, prints}
  end
end
