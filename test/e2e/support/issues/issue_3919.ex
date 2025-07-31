defmodule Phoenix.LiveViewTest.E2E.Issue3919Live do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, assign(socket, action: %{text: "No red"})}
  end

  def handle_event("toggle_special", %{}, socket) do
    new_action =
      if socket.assigns.action[:attrs] do
        %{text: "No red"}
      else
        %{text: "Red", attrs: %{special: true}}
      end

    {:noreply, assign(socket, action: new_action)}
  end

  def render(assigns) do
    ~H"""
    <.my_component {@action[:attrs] || %{}}>{@action.text}</.my_component>

    <button phx-click="toggle_special">toggle</button>
    """
  end

  attr(:special, :boolean, default: false)
  slot(:inner_block)

  defp my_component(assigns) do
    ~H"""
    <div style={if(@special, do: "background-color: red;")}>
      {render_slot(@inner_block)}
    </div>
    """
  end
end
