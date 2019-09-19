defmodule Phoenix.LiveViewTest.Endpoint do
  def url(), do: "http://localhost:4000"
  def instrument(_, _, _, func), do: func.()
  def config(:live_view), do: [signing_salt: "112345678212345678312345678412"]
  def config(:secret_key_base), do: "5678567899556789656789756789856789956789"

  def init(opts), do: opts

  @parsers Plug.Parsers.init(
             parsers: [:urlencoded, :multipart, :json],
             pass: ["*/*"],
             json_decoder: Phoenix.json_library()
           )

  def call(conn, _) do
    conn
    |> Plug.Parsers.call(@parsers)
    |> Plug.Conn.put_private(:phoenix_endpoint, __MODULE__)
    |> Phoenix.LiveViewTest.Router.call([])
  end
end
