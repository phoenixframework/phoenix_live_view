Application.put_env(:phoenix_live_view, :debug_heex_annotations, true)
Code.require_file("test/support/live_views/debug_anno.exs")
Application.put_env(:phoenix_live_view, :debug_heex_annotations, false)

Application.put_env(:phoenix_live_view, :strip_test_attributes, true)
Code.require_file("test/support/live_views/test_attributes.exs")
Application.put_env(:phoenix_live_view, :strip_test_attributes, false)

{:ok, _} = Phoenix.LiveViewTest.Support.Endpoint.start_link()
ExUnit.start()
