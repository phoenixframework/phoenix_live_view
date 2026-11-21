defmodule Phoenix.LiveViewTest.E2E.Issue3083Test do
  use Phoenix.LiveViewTest.E2E.Case

  test "select multiple handles option updates properly", %{page: page} do
    Page.goto!(page, "/issues/3083?auto=false")
    sync_lv(page)

    page |> Page.locator("select") |> Expect.to_have_values!([])

    eval_lv(page, "send(self(), {:select, [1,2]}); nil")
    page |> Page.locator("select") |> Expect.to_have_values!(["1", "2"])
    eval_lv(page, "send(self(), {:select, [2,3]}); nil")
    page |> Page.locator("select") |> Expect.to_have_values!(["2", "3"])

    # now focus the select by interacting with it
    page |> Page.locator("select") |> Locator.click!(position: %{x: 1, y: 1})
    page |> Page.locator("select") |> Expect.to_have_values!(["1"])
    eval_lv(page, "send(self(), {:select, [1,2]}); nil")
    # because the select is focused, we do not expect the values to change
    page |> Page.locator("select") |> Expect.to_have_values!(["1"])
    # now blur the select by clicking on the body
    page |> Page.locator("body") |> Locator.click!()
    page |> Page.locator("select") |> Expect.to_have_values!(["1"])
    # now update the selected values again
    eval_lv(page, "send(self(), {:select, [3,4]}); nil")
    # we had a bug here, where the select was focused, despite the blur
    page |> Page.locator("select") |> Expect.not_() |> Expect.to_be_focused!()
    page |> Page.locator("select") |> Expect.to_have_values!(["3", "4"])
    Page.wait_for_timeout!(page, 1000)
  end
end
