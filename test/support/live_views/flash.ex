defmodule Phoenix.LiveViewTest.FlashLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
    uri[<%= @uri %>]
    root[<%= live_flash(@flash, :info) %>]:info
    root[<%= live_flash(@flash, :error) %>]:error
    <%= live_component @socket, Phoenix.LiveViewTest.FlashComponent, id: "flash-component" %>
    child[<%= live_render @socket, Phoenix.LiveViewTest.FlashChildLive, id: "flash-child" %>]
    """
  end

  def handle_params(_params, uri, socket), do: {:noreply, assign(socket, :uri, uri)}

  def mount(_params, _session, socket), do: {:ok, assign(socket, uri: nil)}

  def handle_event("set_error", %{"error" => error}, socket) do
    {:noreply, socket |> put_flash(:error, error)}
  end

  def handle_event("redirect", %{"to" => to, "info" => info}, socket) do
    {:noreply, socket |> put_flash(:info, info) |> redirect(to: to)}
  end

  def handle_event("push_redirect", %{"to" => to, "info" => info}, socket) do
    {:noreply, socket |> put_flash(:info, info) |> push_redirect(to: to)}
  end

  def handle_event("push_patch", %{"to" => to, "info" => info}, socket) do
    {:noreply, socket |> put_flash(:info, info) |> push_patch(to: to)}
  end

  def handle_event("push_patch", %{"to" => to, "error" => error}, socket) do
    {:noreply, socket |> put_flash(:error, error) |> push_patch(to: to)}
  end
end

defmodule Phoenix.LiveViewTest.FlashComponent do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~L"""
    <div id="<%= @id %>">component[<%= live_flash(@flash, :info) %>]</div>
    """
  end

  def handle_event("redirect", %{"to" => to, "info" => info}, socket) do
    {:noreply, socket |> put_flash(:info, info) |> redirect(to: to)}
  end

  def handle_event("push_redirect", %{"to" => to, "info" => info}, socket) do
    {:noreply, socket |> put_flash(:info, info) |> push_redirect(to: to)}
  end

  def handle_event("push_patch", %{"to" => to, "info" => info}, socket) do
    {:noreply, socket |> put_flash(:info, info) |> push_patch(to: to)}
  end
end

defmodule Phoenix.LiveViewTest.FlashChildLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
    <%= live_flash(@flash, :info) %>
    """
  end

  def mount(_params, _session, socket), do: {:ok, socket}

  def handle_event("set_error", %{"error" => error}, socket) do
    {:noreply, socket |> put_flash(:error, error)}
  end

  def handle_event("redirect", %{"to" => to, "info" => info}, socket) do
    {:noreply, socket |> put_flash(:info, info) |> redirect(to: to)}
  end

  def handle_event("push_redirect", %{"to" => to, "info" => info}, socket) do
    {:noreply, socket |> put_flash(:info, info) |> push_redirect(to: to)}
  end

  def handle_event("push_patch", %{"to" => to, "info" => info}, socket) do
    {:noreply, socket |> put_flash(:info, info) |> push_patch(to: to)}
  end
end
