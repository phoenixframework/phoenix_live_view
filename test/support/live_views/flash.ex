defmodule Phoenix.LiveViewTest.FlashLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~H"""
    uri[<%= @uri %>]
    root[<%= live_flash(@flash, :info) %>]:info
    root[<%= live_flash(@flash, :error) %>]:error
    <%= live_component Phoenix.LiveViewTest.FlashComponent, id: "flash-component" %>
    child[<%= live_render @socket, Phoenix.LiveViewTest.FlashChildLive, id: "flash-child" %>]
    """
  end

  def handle_params(_params, uri, socket) do
    {:noreply, assign(socket, :uri, uri)}
  end

  def mount(_params, _session, socket), do: {:ok, assign(socket, uri: nil)}

  def handle_event("set_error", %{"error" => error}, socket) do
    {:noreply, socket |> put_flash(:error, error)}
  end

  def handle_event("clear_flash", %{"kind" => kind}, socket) do
    {:noreply, socket |> clear_flash(kind)}
  end

  def handle_event("redirect", %{"to" => to, "info" => info}, socket) do
    {:noreply, socket |> put_flash(:info, info) |> redirect(to: to)}
  end

  def handle_event("push_navigate", %{"to" => to, "info" => info}, socket) do
    {:noreply, socket |> put_flash(:info, info) |> push_navigate(to: to)}
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
    ~H"""
    <div id={@id} phx-target={@myself} phx-click="click">
    <span phx-target={@myself} phx-click="lv:clear-flash">Clear all</span>
    <span phx-target={@myself} phx-click="lv:clear-flash" phx-value-key="info">component[<%= live_flash(@flash, :info) %>]:info</span>
    <span phx-target={@myself} phx-click="lv:clear-flash" phx-value-key="error">component[<%= live_flash(@flash, :error) %>]:error</span>
    </div>
    """
  end

  def handle_event("click", %{"type" => "redirect", "to" => to, "info" => info}, socket) do
    {:noreply, socket |> put_flash(:info, info) |> redirect(to: to)}
  end

  def handle_event("click", %{"type" => "push_navigate", "to" => to, "info" => info}, socket) do
    {:noreply, socket |> put_flash(:info, info) |> push_navigate(to: to)}
  end

  def handle_event("click", %{"type" => "push_patch", "to" => to, "info" => info}, socket) do
    {:noreply, socket |> put_flash(:info, info) |> push_patch(to: to)}
  end

  def handle_event("click", %{"type" => "put_flash", "info" => value}, socket) do
    {:noreply, socket |> put_flash(:info, value)}
  end

  def handle_event("click", %{"type" => "put_flash", "error" => value}, socket) do
    {:noreply, socket |> put_flash(:error, value)}
  end
end

defmodule Phoenix.LiveViewTest.FlashChildLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~H"""
    <%= live_flash(@flash, :info) %>
    """
  end

  def mount(%{"mount_redirect" => message}, _uri, socket) do
    {:ok, socket |> redirect(to: "/flash-root") |> put_flash(:info, message)}
  end

  def mount(%{"mount_push_navigate" => message}, _uri, socket) do
    {:ok, socket |> push_navigate(to: "/flash-root") |> put_flash(:info, message)}
  end

  def mount(_params, _session, socket), do: {:ok, socket}

  def handle_event("set_error", %{"error" => error}, socket) do
    {:noreply, socket |> put_flash(:error, error)}
  end

  def handle_event("redirect", %{"to" => to, "info" => info}, socket) do
    {:noreply, socket |> put_flash(:info, info) |> redirect(to: to)}
  end

  def handle_event("push_navigate", %{"to" => to, "info" => info}, socket) do
    {:noreply, socket |> put_flash(:info, info) |> push_navigate(to: to)}
  end

  def handle_event("push_patch", %{"to" => to, "info" => info}, socket) do
    {:noreply, socket |> put_flash(:info, info) |> push_patch(to: to)}
  end
end
