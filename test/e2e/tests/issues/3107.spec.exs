defmodule Phoenix.LiveViewTest.E2E.Issue3107Test do
  use Phoenix.LiveViewTest.E2E.Case

  test "keeps value when updating select", %{page: page} do
    Page.goto!(page, "/issues/3107")
    sync_lv(page)

    page |> Page.locator("select") |> Expect.to_have_value!("ONE")
    # focus the element and change the value, like a user would
    page |> Page.locator("select") |> Locator.focus!()
    page |> Page.locator("select") |> Locator.select_option!("TWO")
    sync_lv(page)
    page |> Page.locator("select") |> Expect.to_have_value!("TWO")
  end
end
