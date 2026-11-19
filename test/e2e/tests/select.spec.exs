defmodule Phoenix.LiveViewTest.E2E.SelectTest do
  use Phoenix.LiveViewTest.E2E.Case

  # this tests issue #2659
  # https://github.com/phoenixframework/phoenix_live_view/pull/2659
  test "select shows error when invalid option is selected", %{page: page} do
    Page.goto!(page, "/select")
    sync_lv(page)

    select3 = Page.locator(page, "#select_form_select3")
    Expect.to_have_value!(select3, "2")
    select3 |> Expect.not_() |> Expect.to_have_class!("has-error")

    # 5 or below should be invalid
    Locator.select_option!(select3, "3")
    sync_lv(page)
    Expect.to_have_class!(select3, "has-error")

    # 6 or above should be valid
    Locator.select_option!(select3, "6")
    sync_lv(page)
    select3 |> Expect.not_() |> Expect.to_have_class!("has-error")
  end
end
