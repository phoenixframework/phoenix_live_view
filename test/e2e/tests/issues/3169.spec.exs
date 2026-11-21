defmodule Phoenix.LiveViewTest.E2E.Issue3169Test do
  use Phoenix.LiveViewTest.E2E.Case

  defp input_vals(page) do
    page
    |> Page.locator(~s(input[type="text"]))
    |> Locator.evaluate_all!("(list) => list.map((i) => i.value)")
  end

  test "updates which add cids back on page are properly magic id change tracked", %{
    page: page
  } do
    Page.goto!(page, "/issues/3169")
    sync_lv(page)

    page |> Page.locator("#select-a") |> Locator.click!()
    sync_lv(page)
    page |> Page.locator("body") |> Expect.to_contain_text!("FormColumn (c3)")
    assert input_vals(page) == ["Record a", "Record a", "Record a"]

    page |> Page.locator("#select-b") |> Locator.click!()
    sync_lv(page)
    page |> Page.locator("body") |> Expect.to_contain_text!("FormColumn (c3)")
    assert input_vals(page) == ["Record b", "Record b", "Record b"]

    page |> Page.locator("#select-z") |> Locator.click!()
    sync_lv(page)
    page |> Page.locator("body") |> Expect.to_contain_text!("FormColumn (c3)")
    assert input_vals(page) == ["Record z", "Record z", "Record z"]
  end
end
