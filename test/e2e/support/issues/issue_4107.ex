defmodule Phoenix.LiveViewTest.E2E.Issue4107Live do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <.portal id="test-form-portal" target="body">
        <.form id="test-form" for={%{}} as={:test_form} action="/api/test" method="post">
          <input type="hidden" name="test_input" value="test_value" />
        </.form>
      </.portal>
      <button type="submit" form="test-form">Submit</button>
    </div>
    """
  end
end
