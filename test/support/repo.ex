defmodule Phoenix.LiveViewTest.Support.Repo do
  use Ecto.Repo,
    otp_app: :phoenix_live_view,
    adapter: Ecto.Adapters.SQLite3
end
