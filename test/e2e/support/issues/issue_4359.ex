defmodule Phoenix.LiveViewTest.E2E.Issue4359Live do
  # https://github.com/phoenixframework/phoenix_live_view/issues/4359

  defmodule ChildLive do
    use Phoenix.LiveView

    def mount(_params, _session, socket), do: {:ok, socket}

    def render(assigns) do
      ~H"child"
    end
  end

  use Phoenix.LiveView

  def mount(params, _session, socket) do
    if connected?(socket) and params["done"] != "1", do: send(self(), :go)
    {:ok, socket}
  end

  def handle_info(:go, socket) do
    # Give the client time to start mounting the child. Its :child_mount call
    # remains blocked until this parent finishes handling the message.
    Process.sleep(2_000)
    {:noreply, push_navigate(socket, to: "/issues/4359?done=1")}
  end

  def render(assigns) do
    ~H"""
    {live_render(@socket, ChildLive, id: "child")}
    """
  end
end
