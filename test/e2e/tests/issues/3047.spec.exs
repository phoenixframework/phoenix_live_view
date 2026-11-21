defmodule Phoenix.LiveViewTest.E2E.Issue3047Test do
  use Phoenix.LiveViewTest.E2E.Case

  defp list_items(page) do
    page
    |> Page.locator(~s([phx-update="stream"] > span))
    |> Locator.evaluate_all!("(list) => list.map((el) => el.id)")
  end

  test "streams are not cleared in sticky live views", %{page: page} do
    Page.goto!(page, "/issues/3047/a")
    sync_lv(page)
    page |> Page.locator("#page") |> Expect.to_contain_text!("Page A")

    assert list_items(page) == [
             "items-1",
             "items-2",
             "items-3",
             "items-4",
             "items-5",
             "items-6",
             "items-7",
             "items-8",
             "items-9",
             "items-10"
           ]

    page |> Page.get_by_role(:button, name: "Reset") |> Locator.click!()
    sync_lv(page)

    assert list_items(page) == [
             "items-5",
             "items-6",
             "items-7",
             "items-8",
             "items-9",
             "items-10",
             "items-11",
             "items-12",
             "items-13",
             "items-14",
             "items-15"
           ]

    page |> Page.get_by_role(:link, name: "Page B") |> Locator.click!()
    sync_lv(page)

    # stream items should still be visible
    page |> Page.locator("#page") |> Expect.to_contain_text!("Page B")

    assert list_items(page) == [
             "items-5",
             "items-6",
             "items-7",
             "items-8",
             "items-9",
             "items-10",
             "items-11",
             "items-12",
             "items-13",
             "items-14",
             "items-15"
           ]
  end
end
