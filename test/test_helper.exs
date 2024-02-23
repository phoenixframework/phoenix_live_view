after_verify_exclude =
  if Version.match?(System.version(), ">= 1.14.0-dev"), do: [], else: [:after_verify]

Application.put_env(:phoenix_live_view, :debug_heex_annotations, true)
Code.require_file("test/support/live_views/debug_anno.exs")
Application.put_env(:phoenix_live_view, :debug_heex_annotations, false)

{:ok, _} = Phoenix.LiveViewTest.Endpoint.start_link()
ExUnit.start(exclude: after_verify_exclude)
