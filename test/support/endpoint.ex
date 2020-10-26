defmodule Phoenix.LiveViewTest.Endpoint do
  def url(), do: "http://localhost:4000"
  def instrument(_, _, _, func), do: func.()
  def script_name(), do: []
  def config(:live_view), do: [signing_salt: "112345678212345678312345678412"]
  def config(:secret_key_base), do: String.duplicate("57689", 50)
  def config(:cache_static_manifest_latest), do: Process.get(:cache_static_manifest_latest)

  def init(opts), do: opts

  @parsers Plug.Parsers.init(
             parsers: [:urlencoded, :multipart, :json],
             pass: ["*/*"],
             json_decoder: Phoenix.json_library()
           )

  def call(conn, _) do
    %{conn | secret_key_base: config(:secret_key_base)}
    |> Plug.Parsers.call(@parsers)
    |> Plug.Conn.put_private(:phoenix_endpoint, __MODULE__)
    |> Phoenix.LiveViewTest.Router.call([])
  end
end
