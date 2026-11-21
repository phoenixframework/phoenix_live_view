defmodule Phoenix.LiveViewTest.E2E.Issue3919Test do
  use Phoenix.LiveViewTest.E2E.Case

  # https://github.com/phoenixframework/phoenix_live_view/issues/3919
  test "attribute defaults are properly considered as changed", %{page: page} do
    Page.goto!(page, "/issues/3919")
    sync_lv(page)

    styled_div = Page.locator(page, "div[style]")

    Expect.to_contain_text!(styled_div, "No red")

    styled_div
    |> Expect.not_()
    |> Expect.to_have_attribute!("style", "background-color: red;")

    page |> Page.get_by_role(:button, name: "toggle") |> Locator.click!()
    sync_lv(page)

    styled_div |> Expect.not_() |> Expect.to_contain_text!("No red")
    Expect.to_have_attribute!(styled_div, "style", "background-color: red;")
    page |> Page.get_by_role(:button, name: "toggle") |> Locator.click!()
    sync_lv(page)

    # bug: previously, the red background remained
    Expect.to_contain_text!(styled_div, "No red")

    styled_div
    |> Expect.not_()
    |> Expect.to_have_attribute!("style", "background-color: red;")
  end
end
