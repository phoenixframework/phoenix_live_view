defmodule Phoenix.LiveViewTest.E2E.Issue3941Test do
  use Phoenix.LiveViewTest.E2E.Case

  # https://github.com/phoenixframework/phoenix_live_view/issues/3941
  test "component-only patch in locked tree works", %{page: page} do
    Page.goto!(page, "/issues/3941")
    sync_lv(page)

    # the bug was that, because the parent container was locked,
    # the component only patch was applied and later on the (stale) locked
    # tree was applied, erasing the patch
    page |> Page.locator("#Item_1") |> Expect.to_contain_text!("I AM LOADED")
    page |> Page.locator("#Item_2") |> Expect.to_contain_text!("I AM LOADED")

    page |> Page.locator("#select-Item_1") |> Locator.uncheck!()
    page |> Page.locator("#select-Item_2") |> Locator.uncheck!()

    page |> Page.locator("#Item_1") |> Expect.to_have_count!(0)
    page |> Page.locator("#Item_2") |> Expect.to_have_count!(0)

    page |> Page.locator("#select-Item_1") |> Locator.check!()
    page |> Page.locator("#Item_1") |> Expect.to_contain_text!("I AM LOADED")
    page |> Page.locator("#Item_2") |> Expect.to_have_count!(0)

    page |> Page.locator("#select-Item_2") |> Locator.check!()
    page |> Page.locator("#Item_1") |> Expect.to_contain_text!("I AM LOADED")
    page |> Page.locator("#Item_2") |> Expect.to_contain_text!("I AM LOADED")
  end
end
