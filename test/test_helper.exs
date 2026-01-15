Application.put_env(:phoenix_live_view, :debug_heex_annotations, true)
Application.put_env(:phoenix_live_view, :debug_attributes, true)
Code.require_file("test/support/live_views/debug_anno.exs")
Application.put_env(:phoenix_live_view, :debug_attributes, false)
Application.put_env(:phoenix_live_view, :debug_heex_annotations, false)

Application.put_env(:phoenix_live_view, :root_tag_annotation, "phx-r")
Code.require_file("test/support/live_views/root_tag_anno.exs")
Application.delete_env(:phoenix_live_view, :root_tag_annotation)

{:ok, _} = Phoenix.LiveViewTest.Support.Endpoint.start_link()
ExUnit.start()
