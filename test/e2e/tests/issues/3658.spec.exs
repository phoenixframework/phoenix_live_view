defmodule Phoenix.LiveViewTest.E2E.Issue3658Test do
  use Phoenix.LiveViewTest.E2E.Case

  # https://github.com/phoenixframework/phoenix_live_view/issues/3658
  test "phx-remove elements inside sticky LiveViews are not removed when navigating", %{
    page: page
  } do
    Page.goto!(page, "/issues/3658")
    sync_lv(page)

    page |> Page.locator("#foo") |> Expect.to_be_visible!()
    page |> Page.get_by_role(:link, name: "Link 1") |> Locator.click!()

    sync_lv(page)
    # the bug would remove the element
    page |> Page.locator("#foo") |> Expect.to_be_visible!()
  end
end
