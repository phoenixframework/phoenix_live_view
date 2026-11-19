defmodule Phoenix.LiveViewTest.E2E.Issue3647Test do
  use Phoenix.LiveViewTest.E2E.Case

  # https://github.com/phoenixframework/phoenix_live_view/issues/3647
  test "upload works when input event follows immediately afterwards", %{page: page} do
    Page.goto!(page, "/issues/3647")
    sync_lv(page)

    page |> Page.locator("ul li") |> Expect.to_have_count!(0)
    page |> Page.locator(~s(input[name="user[name]"])) |> Expect.to_have_value!("")

    page |> Page.get_by_role(:button, name: "Upload then Input") |> Locator.click!()
    sync_lv(page)

    page |> Page.locator("ul li") |> Expect.to_have_count!(1)
    page |> Page.locator(~s(input[name="user[name]"])) |> Expect.to_have_value!("0")
  end
end
