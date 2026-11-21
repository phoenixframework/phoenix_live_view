defmodule Phoenix.LiveViewTest.E2E.Issue3814Test do
  use Phoenix.LiveViewTest.E2E.Case

  # https://github.com/phoenixframework/phoenix_live_view/issues/3814
  test "submitter is sent when using phx-trigger-action", %{page: page} do
    Page.goto!(page, "/issues/3814")
    sync_lv(page)

    page |> Page.locator("button") |> Locator.click!()

    page
    |> Page.locator("body")
    |> Expect.to_contain_text!(~s("i-am-the-submitter":"submitter-value"))
  end
end
