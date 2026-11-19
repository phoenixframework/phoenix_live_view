defmodule Phoenix.LiveViewTest.E2E.Issue3819Test do
  use Phoenix.LiveViewTest.E2E.Case

  # https://github.com/phoenixframework/phoenix_live_view/issues/3819
  test "form recovery aborts early when form is empty", %{page: page} do
    Page.goto!(page, "/issues/3819")
    sync_lv(page)

    Page.evaluate!(
      page,
      "() => new Promise((resolve) => window.liveSocket.disconnect(resolve))"
    )

    page |> Page.locator(".phx-loading") |> Expect.to_have_count!(1)

    Page.evaluate!(page, """
    () => {
      window.addEventListener("phx:page-loading-stop", () => {
        window.liveSocket.js().push(window.liveSocket.main.el, "reconnected");
      });
      window.liveSocket.connect();
    }
    """)

    page |> Page.locator(".phx-loading") |> Expect.to_have_count!(0)
    page |> Page.locator("#reconnected") |> Expect.to_be_visible!()
  end
end
