defmodule Phoenix.LiveViewTest.E2E.Issue4095Test do
  use Phoenix.LiveViewTest.E2E.Case

  # https://github.com/phoenixframework/phoenix_live_view/issues/4095
  test "events for disconnected elements are ignored", %{page: page} do
    Page.goto!(page, "/issues/4095")
    sync_lv(page)

    page |> Page.locator("button") |> Expect.to_be_visible!()
    Page.evaluate!(page, "() => window.liveSocket.enableLatencySim(50)")

    page |> Page.locator("input") |> Locator.fill!("1")
    page |> Page.locator("input") |> Locator.fill!("12")

    sync_lv(page)

    page |> Page.locator("button") |> Expect.to_have_text!("Show?")
    page |> Page.locator("button") |> Expect.not_() |> Expect.to_have_attribute!("data-phx-skip")
  end
end
