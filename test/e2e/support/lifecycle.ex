defmodule Phoenix.LiveViewTest.E2E.LifecycleLive do
  use Phoenix.LiveView

  @impl Phoenix.LiveView
  def mount(params, _session, socket) do
    auto_connect =
      case params do
        %{"auto_connect" => "false"} -> false
        _ -> true
      end

    {:ok, socket, auto_connect: auto_connect}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div>Hello!</div>
    <.link navigate="/lifecycle">Navigate to self (auto_connect=true)</.link>
    <.link navigate="/lifecycle?auto_connect=false">Navigate to self (auto_connect=false)</.link>
    """
  end
end
