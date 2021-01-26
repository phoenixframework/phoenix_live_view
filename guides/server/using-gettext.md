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
