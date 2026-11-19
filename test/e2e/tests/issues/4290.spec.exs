defmodule Phoenix.LiveViewTest.E2E.Issue4290Test do
  use Phoenix.LiveViewTest.E2E.Case

  # https://github.com/phoenixframework/phoenix_live_view/issues/4290
  test "events from the old view are not routed to the new view during live navigation", %{
    page: page
  } do
    Page.goto!(page, "/issues/4290/a")
    sync_lv(page)

    page |> Page.get_by_role(:button, name: "Navigate") |> Locator.click!()

    # The new LiveView is registered and joins immediately, but the DOM swap
    # is delayed by the phx-remove transition. The old page stays visible and
    # interactive during that window.
    Page.wait_for_timeout!(page, 500)
    page |> Page.locator("h1") |> Expect.to_have_text!("A")

    # interact with the old form while the navigation is still in progress;
    # the resulting change event must not be pushed to the new LiveView
    page |> Page.locator("input[name=name]") |> Locator.fill!("hello")

    page |> Page.locator("h1") |> Expect.to_have_text!("B")
    sync_lv(page)

    page |> Page.locator("#event-count") |> Expect.to_have_text!("0")
  end
end
