Application.put_env(:phoenix_live_view, :debug_heex_annotations, true)
Application.put_env(:phoenix_live_view, :debug_attributes, true)
Code.require_file("test/support/live_views/debug_anno.exs")
Code.require_file("test/support/live_views/debug_anno_opt_out.exs")
Application.put_env(:phoenix_live_view, :debug_attributes, false)
Application.put_env(:phoenix_live_view, :debug_heex_annotations, false)

Application.put_env(:phoenix_live_view, :root_tag_attribute, "phx-r")
Code.require_file("test/support/live_views/root_tag_attr.exs")
Application.delete_env(:phoenix_live_view, :root_tag_attribute)

{:ok, _} = Phoenix.LiveViewTest.Support.Endpoint.start_link()
ExUnit.start()
