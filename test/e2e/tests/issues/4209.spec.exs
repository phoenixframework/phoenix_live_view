defmodule Phoenix.LiveViewTest.E2E.Issue4209Test do
  use Phoenix.LiveViewTest.E2E.Case

  test "skipped locked ancestor keeps nested component patches private until unlock", %{
    page: page
  } do
    # This reproduces an issue where a locked element itself was skipped (data-phx-skip).
    # We have a hook on the skip element, which sends an event to a child LiveView.
    # Because the child LiveView is deliberately slow to process that event, the lock
    # stays active for a while. During that time, the child also sends an update to
    # the parent, which bumps a counter both outside and inside the locked panel.
    # The important regression assertion is that the child label remains "child 0"
    # while #locked-panel is still locked:
    # the "child 1" patch must be written to the private locked clone and only become
    # visible after the lock is acked.
    Page.goto!(page, "/issues/4209")
    sync_lv(page)

    page |> Page.locator("#outside-count") |> Expect.to_have_text!("0")
    page |> Page.locator("#locked-child-label") |> Expect.to_have_text!("child 0")

    page |> Page.get_by_role(:button, name: "Start locked update") |> Locator.click!()

    page
    |> Page.locator("#locked-panel")
    |> Expect.to_have_attribute!("data-phx-ref-lock", "0")

    page |> Page.locator("#outside-count") |> Expect.to_have_text!("1")

    Page.wait_for_timeout!(page, 150)

    page
    |> Page.locator("#locked-panel")
    |> Expect.to_have_attribute!("data-phx-ref-lock", "0")

    # This assertion would fail previously, because the locked panel was skipped
    # with the magic ID optimization.
    page |> Page.locator("#locked-child-label") |> Expect.to_have_text!("child 0")

    sync_lv(page)

    page |> Page.locator("#locked-child-label") |> Expect.to_have_text!("child 1")

    page
    |> Page.locator("#locked-panel")
    |> Expect.not_()
    |> Expect.to_have_attribute!("data-phx-ref-lock", "0")
  end
end
