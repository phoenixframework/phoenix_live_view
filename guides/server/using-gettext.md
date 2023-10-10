# Gettext for internationalization

For internationalization with [gettext](https://hexdocs.pm/gettext/Gettext.html),
you must call `Gettext.put_locale/2` on the LiveView mount callback to instruct
the LiveView which locale should be used for rendering the page.

However, one question that has to be answered is how to retrieve the locale in
the first place. There are many approaches to solve this problem:

1. The locale could be stored in the URL as a parameter
2. The locale could be stored in the session
3. The locale could be stored in the database

We will briefly cover these approaches to provide some direction.

## Locale from parameters

You can say all URLs have a locale parameter. In your router:

    scope "/:locale" do
      live ...
      get ...
    end

Accessing a page without a locale should automatically redirect
to a URL with locale (the best locale could be fetched from
HTTP headers, which is outside of the scope of this guide).

Then, assuming all URLs have a locale, you can set the Gettext
locale accordingly:

    def mount(%{"locale" => locale}, _session, socket) do
      Gettext.put_locale(MyApp.Gettext, locale)
      {:ok, socket}
    end


You can also use the [`on_mount`](`Phoenix.LiveView.on_mount/1`) hook to
automatically restore the locale for every LiveView in your application:

    defmodule MyAppWeb.RestoreLocale do
      def on_mount(:default, %{"locale" => locale}, _session, socket) do
        Gettext.put_locale(MyApp.Gettext, locale)
        {:cont, socket}
      end

      # catch-all case
      def on_mount(:default, _params, _session, socket), do: {:cont, socket}
    end

Then, add this hook to `def live_view` under `MyAppWeb`, to run it on all
LiveViews by default:

    def live_view do
      quote do
        use Phoenix.LiveView,
          layout: {MyAppWeb.LayoutView, :live}

        on_mount MyAppWeb.RestoreLocale
        unquote(view_helpers())
      end
    end

Note that, because the Gettext locale is not stored in the assigns, if you
want to change the locale, you must use `<.link navigate={...} />`, instead
of simply patching the page.

## Locale from session

You may also store the locale in the Plug session. For example, in a controller
you might do:

    def put_user_session(conn, current_user) do
      Gettext.put_locale(MyApp.Gettext, current_user.locale)

      conn
      |> put_session(:user_id, current_user.id)
      |> put_session(:locale, current_user.locale)
    end

and then restore the locale from session within your LiveView mount:

    def mount(_params, %{"locale" => locale}, socket) do
      Gettext.put_locale(MyApp.Gettext, locale)
      {:ok, socket}
    end

You can also encapsulate this in a hook, as done in the previous section.

However, if the locale is stored in the session, you can only change it
by using regular controller requests. Therefore you should always use
`<.link to={...} />` to point to a controller that change the session
accordingly, reloading any LiveView.

## Locale from database

You may also allow users to store their locale configuration in the database.
Then, on `mount/3`, you can retrieve the user id from the session and load
the locale:

    def mount(_params, %{"user_id" => user_id}, socket) do
      user = Users.get_user!(user_id)
      Gettext.put_locale(MyApp.Gettext, user.locale)
      {:ok, socket}
    end

In practice, you may end-up mixing more than one approach listed here.
For example, reading from the database is great once the user is logged in
but, before that happens, you may need to store the locale in the session
or in the URL.

Similarly, you can keep the locale in the URL, but change the URL accordingly
to the user preferred locale once they sign in. Hopefully this guide gives
some suggestions on how to move forward and explore the best approach for your
application.
