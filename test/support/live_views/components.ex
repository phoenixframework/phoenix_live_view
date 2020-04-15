defmodule Phoenix.LiveViewTest.StatefulComponent do
  use Phoenix.LiveComponent

  def mount(socket) do
    {:ok, assign(socket, name: "unknown", dup_name: nil)}
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

  def render(assigns) do
    ~L"""
    <div id="<%= @id %>" phx-target="#<%= @id %>" phx-click="transform">
      <%= @name %> says hi with socket: <%= !!@socket %>
      <%= if @dup_name, do: live_component @socket, __MODULE__, id: @dup_name, name: @dup_name %>
    </div>
    """
  end

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

  def render(assigns) do
    ~L"""
    Redirect: <%= @redirect %>
    <%= for name <- @names do %>
      <%= live_component @socket, Phoenix.LiveViewTest.StatefulComponent, id: name, name: name, from: @from %>
    <% end %>
    """
  end

  def mount(_params, %{"names" => names, "from" => from}, socket) do
    {:ok, assign(socket, names: names, from: from)}
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
end
