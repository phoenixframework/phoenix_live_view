defmodule Phoenix.LiveViewTest.E2E.Issue3953Test do
  use Phoenix.LiveViewTest.E2E.Case

  # https://github.com/phoenixframework/phoenix_live_view/issues/3953
  test "component destroy messages respect the parent", %{page: page} do
    Page.goto!(page, "/issues/3953")
    sync_lv(page)
    page |> Page.locator("#nested_view [data-phx-component='1']") |> Expect.to_have_count!(0)

    # the first render works fine
    page |> Page.get_by_role(:button, name: "Show") |> Locator.click!()
    sync_lv(page)
    page |> Page.locator("#nested_view [data-phx-component='1']") |> Expect.to_have_count!(1)

    # the bug was that a cids_destroyed message was sent to the parent view
    page |> Page.get_by_role(:button, name: "Show") |> Locator.click!()
    sync_lv(page)
    page |> Page.locator("#nested_view [data-phx-component='1']") |> Expect.to_have_count!(0)

    # so this failed, as CID 1 was not found when rendering
    page |> Page.get_by_role(:button, name: "Show") |> Locator.click!()
    sync_lv(page)
    page |> Page.locator("#nested_view [data-phx-component='1']") |> Expect.to_have_count!(1)
  end
end
