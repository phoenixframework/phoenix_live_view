defmodule Phoenix.LiveViewTest.ClockController do
  use Phoenix.Controller

  alias Phoenix.LiveViewTest.ClockLive

  def index(conn, _params) do
    Phoenix.LiveView.Controller.live_render(conn, ClockLive, session: %{})
  end
end
