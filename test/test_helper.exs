Application.put_env(:phoenix_live_view, :debug_heex_annotations, true)
Application.put_env(:phoenix_live_view, :debug_attributes, true)
Code.require_file("test/support/live_views/debug_anno.exs")
Code.require_file("test/support/live_views/debug_anno_opt_out.exs")
Application.put_env(:phoenix_live_view, :debug_attributes, false)
Application.put_env(:phoenix_live_view, :debug_heex_annotations, false)

Application.put_env(:phoenix_live_view, :root_tag_attribute, "phx-r")
Code.require_file("test/support/live_views/root_tag_attr.exs")
Application.delete_env(:phoenix_live_view, :root_tag_attribute)

Application.put_env(:phoenix_live_view, Phoenix.LiveViewTest.Support.Repo,
  database: Path.expand("phoenix_live_view_async_sandbox_race.sqlite3", System.tmp_dir!()),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10,
  log: false
)

{:ok, _} = Phoenix.LiveViewTest.Support.Repo.start_link()
Ecto.Adapters.SQL.Sandbox.mode(Phoenix.LiveViewTest.Support.Repo, :manual)

{:ok, _} = Phoenix.LiveViewTest.Support.Endpoint.start_link()
ExUnit.start()
