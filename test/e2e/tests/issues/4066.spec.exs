defmodule Phoenix.LiveViewTest.E2E.Issue4066Test do
  use Phoenix.LiveViewTest.E2E.Case

  # https://github.com/phoenixframework/phoenix_live_view/issues/4066
  test "events for disconnected elements are ignored", %{page: page} do
    # The test triggers an input event that triggers an event after a delay
    # and before the delay fires, the element is removed by a button press.
    # Previously, the event would bubble to the parent, crashing the LiveView.
    Page.goto!(page, "/issues/4066?delay=100")
    sync_lv(page)

    render_time =
      page
      |> Page.locator("#render-time")
      |> Locator.evaluate!("(el) => el.innerText")

    page |> Page.locator("input") |> Locator.fill!("123")
    page |> Page.locator("button") |> Locator.click!()
    sync_lv(page)
    page |> Page.locator("input") |> Expect.to_be_hidden!()

    # The hook sets this attribute when the delay fires - we should not crash here
    page |> Page.locator("body") |> Expect.to_have_attribute!("data-pushed", "yes")

    # We can show the input again
    page |> Page.locator("button") |> Locator.click!()
    sync_lv(page)
    page |> Page.locator("input") |> Expect.to_be_visible!()

    # LiveView did not remount
    page |> Page.locator("#render-time") |> Expect.to_have_text!(render_time)
  end
end
