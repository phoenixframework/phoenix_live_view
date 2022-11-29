defmodule Phoenix.LiveViewTest.ReloadLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    case Application.fetch_env(:phoenix_live_view, :vsn) do
      {:ok, 1} ->
        ~H"""
         <div>Version 1</div>
        """

      {:ok, 2} ->
        ~H"""
         <div>Version 2</div>
        """
    end
  end
end
