defmodule Phoenix.LiveViewTest.E2E.Issue3686Test do
  use Phoenix.LiveViewTest.E2E.Case

  # https://github.com/phoenixframework/phoenix_live_view/issues/3686
  test "flash is copied across fallback redirect", %{page: page} do
    Page.goto!(page, "/issues/3686/a")
    sync_lv(page)
    page |> Page.locator("#flash") |> Expect.to_have_text!("%{}")

    page |> Page.get_by_role(:button, name: "To B") |> Locator.click!()
    sync_lv(page)
    page |> Page.locator("#flash") |> Expect.to_contain_text!("Flash from A")

    page |> Page.get_by_role(:button, name: "To C") |> Locator.click!()
    sync_lv(page)
    page |> Page.locator("#flash") |> Expect.to_contain_text!("Flash from B")

    page |> Page.get_by_role(:button, name: "To A") |> Locator.click!()
    sync_lv(page)
    page |> Page.locator("#flash") |> Expect.to_contain_text!("Flash from C")
  end
end
