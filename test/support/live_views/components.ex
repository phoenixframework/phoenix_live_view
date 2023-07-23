defmodule Phoenix.LiveViewTest.FunctionComponent do
  use Phoenix.Component

  def render(assigns) do
    ~H"""
    COMPONENT:<%= @value %>
    """
  end

  def render_with_inner_content(assigns) do
    ~H"""
    COMPONENT:<%= @value %>, Content: <%= render_slot(@inner_block) %>
    """
  end
end

defmodule Phoenix.LiveViewTest.FunctionComponentWithAttrs do
  use Phoenix.Component

  defmodule Struct do
    defstruct []
  end

  def identity(var), do: var
  def map_identity(%{} = map), do: map

  attr :attr, :any
  def fun_attr_any(assigns), do: ~H[]

  attr :attr, :string
  def fun_attr_string(assigns), do: ~H[]

  attr :attr, :atom
  def fun_attr_atom(assigns), do: ~H[]

  attr :attr, :boolean
  def fun_attr_boolean(assigns), do: ~H[]

  attr :attr, :integer
  def fun_attr_integer(assigns), do: ~H[]

  attr :attr, :float
  def fun_attr_float(assigns), do: ~H[]

  attr :attr, :map
  def fun_attr_map(assigns), do: ~H[]

  attr :attr, :list
  def fun_attr_list(assigns), do: ~H[]

  attr :attr, :global
  def fun_attr_global(assigns), do: ~H[]

  attr :attr, Struct
  def fun_attr_struct(assigns), do: ~H[]

  attr :attr, :any, required: true
  def fun_attr_required(assigns), do: ~H[]

  attr :attr, :any, default: %{}
  def fun_attr_default(assigns), do: ~H[]

  attr :attr1, :any
  attr :attr2, :any
  def fun_multiple_attr(assigns), do: ~H[]

  attr :attr, :any, doc: "attr docs"
  def fun_with_attr_doc(assigns), do: ~H[]

  attr :attr, :any, default: "foo", doc: "attr docs."
  def fun_with_attr_doc_period(assigns), do: ~H[]

  attr :attr, :any,
    default: "foo",
    doc: """
    attr docs with bullets:

      * foo
      * bar

    and that's it.
    """

  def fun_with_attr_doc_multiline(assigns), do: ~H[]

  attr :attr1, :any
  attr :attr2, :any, doc: false
  def fun_with_hidden_attr(assigns), do: ~H[]

  attr :attr, :any
  @doc "fun docs"
  def fun_with_doc(assigns), do: ~H[]

  attr :attr, :any

  @doc """
  fun docs
  [INSERT LVATTRDOCS]
  fun docs
  """
  def fun_doc_injection(assigns), do: ~H[]

  attr :attr, :any
  @doc false
  def fun_doc_false(assigns), do: ~H[]

  attr :attr, :any
  defp private_fun(assigns), do: ~H[]

  slot :inner_block
  def fun_slot(assigns), do: ~H[]

  slot :inner_block, doc: "slot docs"
  def fun_slot_doc(assigns), do: ~H[]

  slot :inner_block, required: true
  def fun_slot_required(assigns), do: ~H[]

  slot :named, required: true, doc: "a named slot" do
    attr :attr1, :any, required: true, doc: "a slot attr doc"
    attr :attr2, :any, doc: "a slot attr doc"
  end

  def fun_slot_with_attrs(assigns), do: ~H[]

  slot :named, required: true do
    attr :attr1, :any, required: true, doc: "a slot attr doc"
    attr :attr2, :any, doc: "a slot attr doc"
  end

  def fun_slot_no_doc_with_attrs(assigns), do: ~H[]

  slot :named,
    required: true,
    doc: """
    Important slot:

    * for a
    * for b
    """ do
    attr :attr1, :any, required: true, doc: "a slot attr doc"
    attr :attr2, :any, doc: "a slot attr doc"
  end

  def fun_slot_doc_multiline_with_attrs(assigns), do: ~H[]

  slot :named, required: true do
    attr :attr1, :any,
      required: true,
      doc: """
      attr docs with bullets:

        * foo
        * bar

      and that's it.
      """

    attr :attr2, :any, doc: "a slot attr doc"
  end

  def fun_slot_doc_with_attrs_multiline(assigns), do: ~H[]

  attr :attr1, :atom, values: [:foo, :bar, :baz]
  attr :attr2, :atom, examples: [:foo, :bar, :baz]
  attr :attr3, :list, values: [[60, 40]]
  attr :attr4, :list, examples: [[60, 40]]

  def fun_attr_values_examples(assigns), do: ~H[]
end

defmodule Phoenix.LiveViewTest.StatefulComponent do
  use Phoenix.LiveComponent

  def mount(socket) do
    {:ok, assign(socket, name: "unknown", dup_name: nil, parent_id: nil)}
  end

  def update(assigns, socket) do
    if from = assigns[:from] do
      sent_assigns = Map.merge(assigns, %{id: socket.assigns[:id], myself: socket.assigns.myself})
      send(from, {:updated, sent_assigns})
    end

    {:ok, assign(socket, assigns)}
  end

  def preload([assigns | _] = lists_of_assigns) do
    if from = assigns[:from] do
      send(from, {:preload, lists_of_assigns})
    end

    lists_of_assigns
  end

  def render(%{disabled: true} = assigns) do
    ~H"""
    <div>
      DISABLED
    </div>
    """
  end

  def render(%{socket: _} = assigns) do
    ~H"""
    <div phx-click="transform" id={@id} phx-target={"#" <> @id <> include_parent_id(@parent_id)}>
      <%= @name %> says hi
      <%= if @dup_name, do: live_component(__MODULE__, id: @dup_name, name: @dup_name) %>
    </div>
    """
  end

  defp include_parent_id(nil), do: ""
  defp include_parent_id(parent_id), do: ",#{parent_id}"

  def handle_event("transform", %{"op" => op}, socket) do
    case op do
      "upcase" ->
        {:noreply, update(socket, :name, &String.upcase(&1))}

      "title-case" ->
        {:noreply,
         update(socket, :name, fn <<first::binary-size(1), rest::binary>> ->
           String.upcase(first) <> rest
         end)}

      "dup" ->
        {:noreply, assign(socket, :dup_name, socket.assigns.name <> "-dup")}

      "push_navigate" ->
        {:noreply, push_navigate(socket, to: "/components?redirect=push")}

      "push_patch" ->
        {:noreply, push_patch(socket, to: "/components?redirect=patch")}

      "redirect" ->
        {:noreply, redirect(socket, to: "/components?redirect=redirect")}
    end
  end
end

defmodule Phoenix.LiveViewTest.WithComponentLive do
  use Phoenix.LiveView

  def render(%{disabled: :all} = assigns) do
    ~H"""
    Disabled
    """
  end

  def render(assigns) do
    ~H"""
    Redirect: <%= @redirect %>
    <%= for name <- @names do %>
      <%= live_component Phoenix.LiveViewTest.StatefulComponent,
            id: name, name: name, from: @from, disabled: name in @disabled, parent_id: nil  %>
    <% end %>
    """
  end

  def mount(_params, %{"names" => names, "from" => from}, socket) do
    {:ok, assign(socket, names: names, from: from, disabled: [])}
  end

  def handle_params(params, _url, socket) do
    {:noreply, assign(socket, redirect: params["redirect"] || "none")}
  end

  def handle_info({:send_update, updates}, socket) do
    Enum.each(updates, fn {module, args} -> send_update(module, args) end)
    {:noreply, socket}
  end

  def handle_event("delete-name", %{"name" => name}, socket) do
    {:noreply, update(socket, :names, &List.delete(&1, name))}
  end

  def handle_event("disable-all", %{}, socket) do
    {:noreply, assign(socket, :disabled, :all)}
  end

  def handle_event("dup-and-disable", %{}, socket) do
    names = socket.assigns.names
    new_socket = assign(socket, disabled: names, names: names ++ Enum.map(names, &(&1 <> "-new")))
    {:noreply, new_socket}
  end
end

defmodule Phoenix.LiveViewTest.WithMultipleTargets do
  use Phoenix.LiveView

  def mount(_params, %{"names" => names, "from" => from} = session, socket) do
    {
      :ok,
      assign(socket,
        names: names,
        from: from,
        disabled: [],
        message: nil,
        parent_selector: Map.get(session, "parent_selector", "#parent_id")
      )
    }
  end

  def render(assigns) do
    ~L"""
    <div id="parent_id" class="parent">
      <%= @message %>
      <%= for name <- @names do %>
        <%= live_component Phoenix.LiveViewTest.StatefulComponent,
              id: name, name: name, from: @from, disabled: name in @disabled, parent_id: @parent_selector %>
      <% end %>
    </div>
    """
  end

  def handle_event("transform", %{"op" => _op}, socket) do
    {:noreply, assign(socket, :message, "Parent was updated")}
  end
end

defmodule Phoenix.LiveViewTest.WithLogOverride do
  use Phoenix.LiveView, log: :warning

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns), do: ~H[]
end

defmodule Phoenix.LiveViewTest.WithLogDisabled do
  use Phoenix.LiveView, log: false

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns), do: ~H[]
end
