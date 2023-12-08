defmodule Phoenix.LiveViewTest.RenderWithLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok,
     render_with(socket, fn assigns ->
       ~H"""
       FROM RENDER WITH!
       """
     end)}
  end
end
