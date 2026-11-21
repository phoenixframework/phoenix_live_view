defmodule Phoenix.LiveViewTest.E2E.Issue4325Test do
  use Phoenix.LiveViewTest.E2E.Case

  # elementHandle.evaluate is inherited from JSHandle
  alias Playwright.JSHandle

  # https://github.com/phoenixframework/phoenix_live_view/issues/4325
  test "setting an id to its current value preserves the element across patches", %{page: page} do
    Page.goto!(page, "/issues/4325")
    sync_lv(page)

    hooked = Page.locator(page, "#hooked")
    original_element = Locator.element_handle!(hooked)

    Expect.to_have_text!(hooked, "count is 0")

    Expect.poll!(
      fn -> Page.evaluate!(page, "() => window.issue4325Lifecycle") end,
      &assert(&1 == %{"mounted" => 1, "updated" => 0, "destroyed" => 0})
    )

    page |> Page.get_by_role(:button, name: "Increment") |> Locator.click!()
    Expect.to_have_text!(hooked, "count is 1")
    sync_lv(page)

    assert JSHandle.evaluate!(original_element, "(element) => element.isConnected") ==
             true

    assert Page.evaluate!(page, "() => window.issue4325Lifecycle") == %{
             "mounted" => 1,
             "updated" => 1,
             "destroyed" => 0
           }
  end
end
