after_verify_exclude =
  if Version.match?(System.version(), ">= 1.14.0-dev"), do: [], else: [:after_verify]

{:ok, _} = Phoenix.LiveViewTest.Endpoint.start_link()
ExUnit.start(exclude: after_verify_exclude)
