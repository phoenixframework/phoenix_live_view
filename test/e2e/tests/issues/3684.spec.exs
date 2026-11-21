defmodule Phoenix.LiveViewTest.E2E.Issue3684Test do
  use Phoenix.LiveViewTest.E2E.Case

  # https://github.com/phoenixframework/phoenix_live_view/issues/3684
  test "nested clones are correctly applied", %{page: page} do
    Page.goto!(page, "/issues/3684")
    sync_lv(page)

    page |> Page.locator("#dewey") |> Expect.not_() |> Expect.to_have_attribute!("checked")

    page |> Page.locator("#dewey") |> Locator.click!()
    sync_lv(page)

    page |> Page.locator("#dewey") |> Expect.to_have_attribute!("checked")
  end
end
