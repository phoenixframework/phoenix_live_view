defmodule Phoenix.LiveViewTest.E2E.Issue3169Live.Components do
  use Phoenix.Component

  def input(assigns) do
    ~H"""
    <div>
      <%= @field.value %>
      <input type="text" value={@field.value} />
      <.input_two field={@field} />
    </div>
    """
  end

  def input_two(assigns) do
    ~H"""
    <div>
      <%= @field.value %>
      <input type="text" value={@field.value} />
    </div>
    """
  end

  def test(assigns) do
    ~H"""
    This is a test!
    <%= @var %>
    """
  end
end

defmodule Phoenix.LiveViewTest.E2E.Issue3169Live.FormColumn do
  use Phoenix.LiveComponent
  import Phoenix.LiveViewTest.E2E.Issue3169Live.Components

  def render(assigns) do
    ~H"""
    <div>
      FormColumn (c3)
      <input type="text" value={@form[:name].value} />
      <.input field={@form[:name]} />
      <.test var="foo" />
    </div>
    """
  end
end

defmodule Phoenix.LiveViewTest.E2E.Issue3169Live.FormCore do
  use Phoenix.LiveComponent

  alias Phoenix.LiveViewTest.E2E.Issue3169Live.FormColumn

  def mount(socket) do
    {:ok, assign(socket, record: nil)}
  end

  def update(%{record: record}, socket) do
    {:ok, assign(socket, record: record)}
  end

  def render(assigns) do
    ~H"""
    <div>
      FormCore (c2)
      <.form :let={form} for={@record}>
        <.live_component module={FormColumn} id={"column-#{@record["id"]}"} form={form} />
      </.form>
    </div>
    """
  end
end


defmodule Phoenix.LiveViewTest.E2E.Issue3169Live.FormComponent do
  use Phoenix.LiveComponent

  alias Phoenix.LiveViewTest.E2E.Issue3169Live.FormCore

  def mount(socket) do
    {:ok, assign(socket, record: nil)}
  end

  def update(%{selected: nil}, socket) do
    {:ok, socket}
  end

  def update(%{selected: name} = assigns, socket) do
    send_update(__MODULE__, id: assigns.id, action: {:load, name})
    {:ok, assign(socket, record: nil)}
  end

  def update(%{action: {:load, name}}, socket) do
    :timer.sleep(50)
    record = %{"id" => :rand.uniform(1_000_000), "name" => "Record #{name}"}
    {:ok, assign(socket, record: record)}
  end

  def render(assigns) do
    ~H"""
    <div>
      FormComponent (c1)
      <div :if={@record}>
        <.live_component module={FormCore} id="core" record={@record} />
      </div>
      <hr />
    </div>
    """
  end
end


defmodule Phoenix.LiveViewTest.E2E.Issue3169Live do
  use Phoenix.LiveView, layout: {__MODULE__, :live}

  alias Phoenix.LiveViewTest.E2E.Issue3169Live.FormComponent

  def render("live.html", assigns) do
    ~H"""
    <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
    <script src="/assets/phoenix/phoenix.min.js">
    </script>
    <script src="/assets/phoenix_live_view/phoenix_live_view.js">
    </script>
    <script>
      let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
      let liveSocket = new window.LiveView.LiveSocket("/live", window.Phoenix.Socket, {
        params: {_csrf_token: csrfToken},
      })
      liveSocket.connect()
    </script>
    <%= @inner_content %>
    """
  end

  def render(assigns) do
    ~H"""
    HomeLive
    <.live_component module={FormComponent} id="form_view" selected={@selected}/>
    <button id="select-a" phx-click="select" phx-value-name="a">Select A</button>
    <button id="select-b" phx-click="select" phx-value-name="b">Select B</button>
    <button id="select-z" phx-click="select" phx-value-name="z">Select Z</button>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, selected: nil)}
  end

  def handle_event("select", %{"name" => value}, socket) do
    {:noreply, assign(socket, :selected, value)}
  end
end
