defmodule Phoenix.LiveViewTest.E2E.Issue4359Test do
  use Phoenix.LiveViewTest.E2E.Case

  # https://github.com/phoenixframework/phoenix_live_view/issues/4359
  test "parent navigation succeeds while a child LiveView is mounting", %{page: page} do
    Page.goto!(page, "/issues/4359")

    Expect.to_have_url!(page, "/issues/4359?done=1")
    sync_lv(page)
    page |> Page.locator("#child") |> Expect.to_contain_text!("child")
    page |> Page.locator("#child") |> Expect.to_have_class!(~r/phx-connected/)
  end
end
