defmodule Phoenix.LiveView.LiveReloadTestHelpers.Endpoint do
  use Phoenix.Endpoint, otp_app: :phoenix_live_view

  @before_compile Phoenix.LiveViewTest.EndpointOverridable

  socket "/live", Phoenix.LiveView.Socket
  socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket

  plug Phoenix.CodeReloader

  defoverridable url: 0, script_name: 0, config: 1, config: 2, static_path: 1
  def url(), do: "http://localhost:4000"
  def script_name(), do: []
  def static_path(path), do: "/static" <> path
  def config(:live_view), do: [signing_salt: "112345678212345678312345678412"]
  def config(:secret_key_base), do: String.duplicate("57689", 50)
  def config(:cache_static_manifest_latest), do: Process.get(:cache_static_manifest_latest)
  def config(:otp_app), do: :phoenix_live_view
  def config(:pubsub_server), do: Phoenix.LiveView.PubSub
  def config(:live_reload), do:
    [
      url: "ws://localhost:4000",
      patterns: [
        ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
        ~r"priv/gettext/.*(po)$",
        ~r"lib/test_auth_web/views/.*(ex)$",
        ~r"lib/test_auth_web/templates/.*(eex)$"
      ],
      notify: [
        live_view: [
          ~r"lib/test_auth_web/components.ex$",
          ~r"lib/test_auth_web/live/.*(ex)$"
        ]
      ]
    ]
  def config(which), do: super(which)
  def config(which, default), do: super(which, default)
end
