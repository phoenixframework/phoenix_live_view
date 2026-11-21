defmodule Phoenix.LiveViewTest.E2E.KeyedComprehensionTest do
  use Phoenix.LiveViewTest.E2E.Case

  for tab <- ["all_keyed", "rows_keyed", "no_keyed"] do
    test "renders correctly - #{tab}", %{page: page} do
      Page.goto!(page, "/keyed-comprehension?tab=#{unquote(tab)}")
      sync_lv(page)

      for _i <- 0..9 do
        page |> Page.get_by_role(:button, name: "randomize") |> Locator.click!()
        sync_lv(page)
      end

      order = eval_lv(page, "socket.assigns.items")

      the_text = fn page, i, index ->
        page
        |> Page.locator("table")
        |> Locator.nth(i)
        |> Locator.locator("tbody tr")
        |> Locator.nth(index)
        |> Locator.text_content!()
        |> String.replace(~r/\s+/, " ")
      end

      order
      |> Enum.with_index()
      |> Enum.map(fn {item, index} ->
        Promise.async(fn ->
          text0 = the_text.(page, 0, index)
          text1 = the_text.(page, 1, index)
          assert text0 == " Count: 10 Name: #{item["entry"]["foo"]["bar"]} 1 10 "
          assert text1 == " Count: 10 Name: #{item["entry"]["foo"]["bar"]} 2 10 "
        end)
      end)
      |> Promise.all()
      |> Promise.await!()
    end
  end
end
