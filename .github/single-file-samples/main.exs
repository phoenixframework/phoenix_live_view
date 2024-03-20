Application.put_env(:sample, Example.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 5001],
  server: true,
  live_view: [signing_salt: "aaaaaaaa"],
  secret_key_base: String.duplicate("a", 64)
)

Mix.install([
  {:plug_cowboy, "~> 2.5"},
  {:jason, "~> 1.0"},
  {:phoenix, "~> 1.7"},
  # please test your issue using the latest version of LV from GitHub!
  {:phoenix_live_view, github: "phoenixframework/phoenix_live_view", branch: "main", override: true},
])

# build the LiveView JavaScript assets (this needs mix and npm available in your path!)
path = Phoenix.LiveView.__info__(:compile)[:source] |> Path.dirname() |> Path.join("../")
System.cmd("mix", ["deps.get"], cd: path, into: IO.binstream())
System.cmd("npm", ["install"], cd: Path.join(path, "./assets"), into: IO.binstream())
System.cmd("mix", ["assets.build"], cd: path, into: IO.binstream())

defmodule Example.ErrorView do
  def render(template, _), do: Phoenix.Controller.status_message_from_template(template)
end

defmodule Example.HomeLive do
  use Phoenix.LiveView, layout: {__MODULE__, :live}

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :count, 0)}
  end

  def render("live.html", assigns) do
    ~H"""
    <script src="/assets/phoenix/phoenix.js"></script>
    <script src="/assets/phoenix_live_view/phoenix_live_view.js"></script>
    <%!-- uncomment to use enable tailwind --%>
    <%!-- <script src="https://cdn.tailwindcss.com"></script> --%>
    <script>
      let liveSocket = new window.LiveView.LiveSocket("/live", window.Phoenix.Socket)
      liveSocket.connect()
    </script>
    <style>
      * { font-size: 1.1em; }
    </style>
    <%= @inner_content %>
    """
  end

  def render(assigns) do
    ~H"""
    <%= @count %>
    <button phx-click="inc">+</button>
    <button phx-click="dec">-</button>
    """
  end

  def handle_event("inc", _params, socket) do
    {:noreply, assign(socket, :count, socket.assigns.count + 1)}
  end

  def handle_event("dec", _params, socket) do
    {:noreply, assign(socket, :count, socket.assigns.count - 1)}
  end
end

defmodule Example.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug(:accepts, ["html"])
  end

  scope "/", Example do
    pipe_through(:browser)

    live("/", HomeLive, :index)
  end
end

defmodule Example.Endpoint do
  use Phoenix.Endpoint, otp_app: :sample
  socket("/live", Phoenix.LiveView.Socket)

  plug Plug.Static, from: {:phoenix, "priv/static"}, at: "/assets/phoenix"
  plug Plug.Static, from: {:phoenix_live_view, "priv/static"}, at: "/assets/phoenix_live_view"

  plug(Example.Router)
end

{:ok, _} = Supervisor.start_link([Example.Endpoint], strategy: :one_for_one)
Process.sleep(:infinity)
