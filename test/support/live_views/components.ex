defmodule Phoenix.LiveViewTest.FunctionComponent do
  import Phoenix.LiveView.Helpers

  def render(assigns) do
    ~H"""
    COMPONENT:<%= @value %>
    """
  end

  def render_with_inner_content(assigns) do
    ~H"""
    COMPONENT:<%= @value %>, Content: <%= render_slot(@default_slot) %>
    """
  end
end

defmodule Phoenix.LiveViewTest.StatefulComponent do
  use Phoenix.LiveComponent

  def mount(socket) do
    {:ok, assign(socket, name: "unknown", dup_name: nil, parent_id: nil)}
  end

  def update(assigns, socket) do
    if from = assigns[:from] do
      send(from, {:updated, assigns})
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
      <%= if @dup_name, do: live_component __MODULE__, id: @dup_name, name: @dup_name %>
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

      "push_redirect" ->
        {:noreply, push_redirect(socket, to: "/components?redirect=push")}

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
      assign(socket, [
        names: names,
        from: from,
        disabled: [],
        message: nil,
        parent_selector: Map.get(session, "parent_selector", "#parent_id")
      ])
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
