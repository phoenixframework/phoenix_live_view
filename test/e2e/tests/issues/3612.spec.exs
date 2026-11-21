defmodule Phoenix.LiveViewTest.E2E.Issue3612Test do
  use Phoenix.LiveViewTest.E2E.Case

  # https://github.com/phoenixframework/phoenix_live_view/issues/3612
  test "sticky LiveView stays connected when using push_navigate", %{page: page} do
    Page.goto!(page, "/issues/3612/a")
    sync_lv(page)
    page |> Page.locator("h1") |> Expect.to_have_text!("Page A")
    page |> Page.get_by_role(:link, name: "Go to page B") |> Locator.click!()
    sync_lv(page)
    page |> Page.locator("h1") |> Expect.to_have_text!("Page B")
    page |> Page.get_by_role(:link, name: "Go to page A") |> Locator.click!()
    sync_lv(page)
    page |> Page.locator("h1") |> Expect.to_have_text!("Page A")
  end
end
