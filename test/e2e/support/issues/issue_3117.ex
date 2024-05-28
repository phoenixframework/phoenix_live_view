defmodule Phoenix.LiveViewTest.E2E.Issue3117Live do
  use Phoenix.LiveView

  # https://github.com/phoenixframework/phoenix_live_view/issues/3117

  defmodule Row do
    use Phoenix.LiveComponent

    def update(assigns, socket) do
      {:ok, assign(socket, assigns) |> assign_async(:foo, fn -> {:ok, %{foo: :bar}} end)}
    end

    def render(assigns) do
      ~H"""
      <div id={@id}>
        Example LC Row <%= inspect(@foo.result) %>
        <.fc />
      </div>
      """
    end

    defp fc(assigns) do
      ~H"""
      <div class="static">static content</div>
      """
    end
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.link id="navigate" navigate="/issues/3117?nav">Navigate</.link>
    <div :for={i <- [1, 2]}>
      <.live_component module={__MODULE__.Row} id={"row-#{i}"} />
    </div>
    """
  end

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
