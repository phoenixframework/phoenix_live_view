defmodule Phoenix.LiveViewTest.E2E.Issue3814Live do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :trigger_submit, false)}
  end

  def handle_event("submit", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  def render(assigns) do
    ~H"""
    <.form phx-submit="submit" phx-trigger-action={@trigger_submit} action="/submit" method="post">
      <input type="hidden" name="greeting" value="hello" />
      <button type="submit" name="i-am-the-submitter" value="submitter-value">Submit</button>
    </.form>
    """
  end
end
