defmodule Phoenix.LiveViewTest.FlashLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
    uri[<%= @uri %>]
    root[<%= live_flash(@flash, :info) %>]:info
    root[<%= live_flash(@flash, :error) %>]:error
    <%= live_component Phoenix.LiveViewTest.FlashComponent, id: "flash-component" %>
    child[<%= live_render @socket, Phoenix.LiveViewTest.FlashChildLive, id: "flash-child" %>]
    <%= live_component Phoenix.LiveViewTest.StatelessFlashComponent, flash: @flash %>
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
    <div id="<%= @id %>" phx-target="<%= @myself %>" phx-click="click">
    <span phx-click="lv:clear-flash">Clear all</span>
    <span phx-click="lv:clear-flash" phx-value-key="info">component[<%= live_flash(@flash, :info) %>]:info</span>
    <span phx-click="lv:clear-flash" phx-value-key="error">component[<%= live_flash(@flash, :error) %>]:error</span>
    </div>
    """
  end

  def handle_event("click", %{"type" => "redirect", "to" => to, "info" => info}, socket) do
    {:noreply, socket |> put_flash(:info, info) |> redirect(to: to)}
  end

  def handle_event("click", %{"type" => "push_redirect", "to" => to, "info" => info}, socket) do
    {:noreply, socket |> put_flash(:info, info) |> push_redirect(to: to)}
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

defmodule Phoenix.LiveViewTest.StatelessFlashComponent do
  use Phoenix.LiveComponent

  @spec render(any) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~L"""
    <div id="<%= @id %>">
    stateless_component[<%= live_flash(@flash, :info) %>]:info
    stateless_component[<%= live_flash(@flash, :error) %>]:error
    </div>
    """
  end
end

defmodule Phoenix.LiveViewTest.FlashChildLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~L"""
    <%= live_flash(@flash, :info) %>
    """
  end

  def mount(%{"mount_redirect" => message}, _uri, socket) do
    {:ok, socket |> redirect(to: "/flash-root") |> put_flash(:info, message)}
  end

  def mount(%{"mount_push_redirect" => message}, _uri, socket) do
    {:ok, socket |> push_redirect(to: "/flash-root") |> put_flash(:info, message)}
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
