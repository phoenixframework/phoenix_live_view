defmodule Phoenix.LiveViewTest.E2E.Issue3199Test do
  use Phoenix.LiveViewTest.E2E.Case

  # https://github.com/phoenixframework/phoenix_live_view/issues/3199
  describe "Issue #3199" do
    test "runs an item's phx-remove transition when it is deleted from a stream", %{page: page} do
      Page.goto!(page, "/issues/3199")
      sync_lv(page)

      item = Page.locator(page, "#items-1")
      item |> Locator.get_by_role(:button, name: "Delete") |> Locator.click!()

      Expect.to_have_class!(item, ~r/item-removing/)
      Expect.to_have_count!(item, 0)
      page |> Page.locator("#items-2") |> Expect.to_have_count!(1)
    end

    test "also runs the item transitions when live navigation removes their container", %{
      page: page
    } do
      Page.goto!(page, "/issues/3199")
      sync_lv(page)

      page |> Page.get_by_role(:link, name: "Navigate away") |> Locator.click!()

      # This is the behavior reported in #3199: replaceMain finds every
      # phx-remove element in the outgoing LiveView, so both item transitions
      # run and delay replacing the old page even though neither item was
      # individually deleted from the stream.
      page |> Page.locator("#items > li.item-removing") |> Expect.to_have_count!(2)
      page |> Page.get_by_role(:heading, name: "Items") |> Expect.to_be_visible!()

      page |> Page.get_by_role(:heading, name: "Away") |> Expect.to_be_visible!()
      sync_lv(page)
    end

    test "can limit phx-remove to the LiveView container during navigation", %{page: page} do
      Page.goto!(page, "/issues/3199?cascadePhxRemoveOnNavigation=false")
      sync_lv(page)

      page |> Page.get_by_role(:link, name: "Navigate away") |> Locator.click!()

      page |> Page.locator("[data-phx-main].view-removing") |> Expect.to_have_count!(1)
      page |> Page.locator("#items > li.item-removing") |> Expect.to_have_count!(0)
      page |> Page.get_by_role(:heading, name: "Away") |> Expect.to_be_visible!()
      sync_lv(page)
    end
  end
end
