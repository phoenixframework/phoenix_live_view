# Using Gettext for internationalization

For internationalization with [gettext](https://hexdocs.pm/gettext/Gettext.html),
the locale used within your Plug pipeline can be stored in the Plug session and
restored within your LiveView mount. For example, after user signs in or preference
changes, you can write the locale to the session:

    def put_user_session(conn, current_user) do
      locale = get_locale_for_user(current_user)
      Gettext.put_locale(MyApp.Gettext, locale)

      conn
      |> put_session(:user_id, current_user.id)
      |> put_session(:locale, locale)
    end

Then in your LiveView `mount/3`, you can restore the locale:

    def mount(_params, %{"locale" => locale}, socket) do
      Gettext.put_locale(MyApp.Gettext, locale)
      {:ok, socket}
    end

You can also use the `on_mount` (`Phoenix.LiveView.on_mount/1`) hook to
automatically restore the locale for every LiveView in your application:

    defmodule MyAppWeb.RestoreLocale do
      import Phoenix.LiveView

      def on_mount(:default, params, %{"locale" => locale} = _session, socket) do
        Gettext.put_locale(MyApp.Gettext, locale)
        {:cont, socket}
      end
    end

Then, add this hook to `def live_view` under `MyAppWeb`, to run it on all
LiveViews by default:

    def live_view do
      quote do
        use Phoenix.LiveView,
          layout: {MyAppWeb.LayoutView, "live.html"}

        on_mount MyAppWeb.RestoreLocale
        unquote(view_helpers())
      end
    end
