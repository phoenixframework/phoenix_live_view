defmodule Phoenix.LiveViewTest.E2E.Issue3719Test do
  use Phoenix.LiveViewTest.E2E.Case

  # https://github.com/phoenixframework/phoenix_live_view/issues/3719
  test "target is properly decoded", %{page: page} do
    logs = array()
    Page.on(page, :console, fn e -> push(logs, ConsoleMessage.text(e)) end)

    Page.goto!(page, "/issues/3719")
    sync_lv(page)
    page |> Page.locator("#a") |> Locator.fill!("foo")
    sync_lv(page)
    page |> Page.locator("#target") |> Expect.to_have_text!(~s(["foo"]))

    page |> Page.locator("#b") |> Locator.fill!("foo")
    sync_lv(page)
    page |> Page.locator("#target") |> Expect.to_have_text!(~s(["foo", "bar"]))

    refute Enum.any?(values(logs), &(&1 =~ ~r/view crashed/))
  end
end
