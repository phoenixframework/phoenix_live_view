defmodule Phoenix.LiveViewTest.E2E.Issue3448Test do
  use Phoenix.LiveViewTest.E2E.Case

  # https://github.com/phoenixframework/phoenix_live_view/issues/3448
  test "focus is handled correctly when patching locked form", %{page: page} do
    Page.goto!(page, "/issues/3448")
    sync_lv(page)

    Page.evaluate!(page, "() => window.liveSocket.enableLatencySim(500)")

    page |> Page.locator("input[type=checkbox]") |> Locator.first() |> Locator.check!()
    page |> Page.locator("input#search") |> Expect.to_be_focused!()
    sync_lv(page)

    # after the patch is applied, the input should still be focused
    page |> Page.locator("input#search") |> Expect.to_be_focused!()
  end
end
