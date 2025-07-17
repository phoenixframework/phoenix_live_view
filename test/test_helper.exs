Application.put_env(:phoenix_live_view, :debug_heex_annotations, true)
Application.put_env(:phoenix_live_view, :debug_attributes, true)
Code.require_file("test/support/live_views/debug_anno.exs")
Application.put_env(:phoenix_live_view, :debug_attributes, false)
Application.put_env(:phoenix_live_view, :debug_heex_annotations, false)

{:ok, _} = Phoenix.LiveViewTest.Support.Endpoint.start_link()
ExUnit.start()
