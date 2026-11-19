defmodule Phoenix.LiveViewTest.E2E.Issue2787Test do
  use Phoenix.LiveViewTest.E2E.Case

  defp select_options(locator) do
    Locator.evaluate_all!(locator, "(list) => list.map((option) => option.value)")
  end

  test "select is properly cleared on submit", %{page: page} do
    Page.goto!(page, "/issues/2787")
    sync_lv(page)

    select1 = Page.locator(page, "#demo_select1")
    select2 = Page.locator(page, "#demo_select2")

    # at the beginning, both selects are empty
    Expect.to_have_value!(select1, "")
    assert select_options(Locator.locator(select1, "option")) == ["", "greetings", "goodbyes"]
    Expect.to_have_value!(select2, "")
    assert select_options(Locator.locator(select2, "option")) == [""]

    # now we select greetings in the first select
    Locator.select_option!(select1, "greetings")
    sync_lv(page)
    # now the second select should have some greeting options
    assert select_options(Locator.locator(select2, "option")) == ["", "hello", "hallo", "hei"]
    Locator.select_option!(select2, "hei")
    sync_lv(page)

    # now we submit the form
    page |> Page.locator("button") |> Locator.click!()

    # now, both selects should be empty again (this was the bug in #2787)
    Expect.to_have_value!(select1, "")
    Expect.to_have_value!(select2, "")

    # now we select goodbyes in the first select
    Locator.select_option!(select1, "goodbyes")
    sync_lv(page)

    assert select_options(Locator.locator(select2, "option")) == [
             "",
             "goodbye",
             "auf wiedersehen",
             "ha det bra"
           ]
  end
end
