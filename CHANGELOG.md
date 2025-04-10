# Changelog for v1.1

## v1.1.0

### Moving from Floki to LazyHTML

LiveView 1.1 moves to [LazyHTML](https://hexdocs.pm/lazy_html/) as the HTML engine used by `LiveViewTest`. LazyHTML is based on [lexbor](https://github.com/lexbor/lexbor) and allows the use of modern CSS selector features, like `:is()`, `:has()`, etc. to target elements. Lexbor's stated goal is to create output that "should match that of modern browsers, meeting industry specifications".

This is a mostly backwards compatible change. The only way in which this affects LiveView projects is when using Floki specific selectors (`fl-contains`, `fl-icontains`), which will not work any more in selectors passed to LiveViewTest's [`element/3`](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html#element/3) function. In most cases, the `text_filter` option of [`element/3`](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html#element/3) should be a sufficient replacement, which has been a feature since LiveView 
v0.12.0. Note that in Phoenix versions prior to v1.8, the `phx.gen.auth` generator used the Floki specific `fl-contains` selector in its generated tests in two instances, so if you used the `phx.gen.auth` generator to scaffold your authentication solution, those tests will need to be adjusted when updating to LiveView v1.1. In both cases, changing to use the `text_filter` option is enough to get you going again:

```diff
 {:ok, _login_live, login_html} =
   lv
-  |> element(~s|main a:fl-contains("Sign up")|)
+  |> element("main a", "Sign up")
   |> render_click()
   |> follow_redirect(conn, ~p"<%= schema.route_prefix %>/register")
```

If you're using Floki itself in your tests through its API (`Floki.parse_document`, `Floki.find`, etc.), you can continue to do so.

### Enhancements

* Normalize whitespace in LiveViewTest's text filters ([#3621](https://github.com/phoenixframework/phoenix_live_view/pull/3621))
* Raise by default when LiveViewTest detects duplicate DOM or LiveComponent IDs. This can be changed by passing `on_error` to `Phoenix.LiveViewTest.live/3` / `Phoenix.LiveViewTest.live_isolated/3`
* Use [`LazyHTML`](https://hexdocs.pm/lazy_html/) instead of [Floki](https://hexdocs.pm/floki) internally for LiveViewTest

## v1.0

The CHANGELOG for v1.0 and earlier releases can be found in the [v1.0 branch](https://github.com/phoenixframework/phoenix_live_view/blob/v1.0/CHANGELOG.md).
