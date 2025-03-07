defmodule Phoenix.LiveViewTest.E2E.Issue3709Live do
  # https://github.com/phoenixframework/phoenix_live_view/issues/3709
  use Phoenix.LiveView

  defmodule SomeComponent do
    use Phoenix.LiveComponent

    def render(assigns) do
      ~H"""
      <div>
        Hello
      </div>
      """
    end
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, id: nil)}
  end

  def handle_params(params, _, socket) do
    {:noreply, assign(socket, :id, params["id"])}
  end

  def render(assigns) do
    ~H"""
    <ul>
      <li :for={i <- 1..10}>
        <.link patch={"/issues/3709/#{i}"}>Link {i}</.link>
      </li>
    </ul>
    <div>
      <.live_component module={SomeComponent} id={"user-#{@id}"} /> id: {@id}
      <div>
        Click the button, then click any link.
        <button onclick="document.querySelectorAll('li a').forEach((x) => x.click())">
          Break Stuff
        </button>
      </div>
    </div>
    """
  end
end
