defmodule Phoenix.LiveViewTest.E2E.Issue3719Live do
  # https://github.com/phoenixframework/phoenix_live_view/issues/3719
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :target, nil)}
  end

  def handle_event("inc", %{"_target" => target}, socket) do
    {:noreply, assign(socket, :target, target)}
  end

  def render(assigns) do
    ~H"""
    <form phx-change="inc">
      <input id="a" type="text" name="foo" />
      <input id="b" type="text" name="foo[bar]" />
    </form>
    <span id="target">{inspect(@target)}</span>
    """
  end
end
