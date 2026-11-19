defmodule Phoenix.LiveViewTest.E2E.Issue3117Test do
  use Phoenix.LiveViewTest.E2E.Case

  test "LiveComponent with static FC root is not reset", %{page: page} do
    errors = array()
    Page.on(page, :page_error, fn err -> push(errors, err) end)

    Page.goto!(page, "/issues/3117")
    sync_lv(page)

    # clicking the button performs a live navigation
    page |> Page.locator("#navigate") |> Locator.click!()
    sync_lv(page)

    # the FC root should still be visible and not empty/skipped
    page |> Page.locator("#row-1 .static") |> Expect.to_be_visible!()
    page |> Page.locator("#row-2 .static") |> Expect.to_be_visible!()
    page |> Page.locator("#row-1 .static") |> Expect.to_have_text!("static content")
    page |> Page.locator("#row-2 .static") |> Expect.to_have_text!("static content")

    # no js errors should be thrown
    assert values(errors) == []
  end
end
