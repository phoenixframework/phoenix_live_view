defmodule Phoenix.LiveViewTest.E2E.Issue3529Test do
  use Phoenix.LiveViewTest.E2E.Case

  defp page_text(page) do
    Page.evaluate!(page, ~s|() => document.querySelector("h1").innerText|)
  end

  # https://github.com/phoenixframework/phoenix_live_view/issues/3529
  # https://github.com/phoenixframework/phoenix_live_view/pull/3625
  test "forward and backward navigation is handled properly (replaceRootHistory)", %{page: page} do
    Page.goto!(page, "/issues/3529")
    sync_lv(page)

    text = page_text(page)
    page |> Page.get_by_role(:link, name: "Navigate") |> Locator.click!()
    sync_lv(page)

    # navigate remounts and changes the text
    refute page_text(page) == text
    text = page_text(page)

    page |> Page.get_by_role(:link, name: "Patch") |> Locator.click!()
    sync_lv(page)
    # patch does not remount
    assert page_text(page) == text

    # now we go back (should be patch again)
    Page.go_back!(page)
    sync_lv(page)
    assert page_text(page) == text

    # and then we back to the initial page and use back/forward
    # this should be a navigate -> remount!
    Page.go_back!(page)
    sync_lv(page)
    refute page_text(page) == text

    # navigate
    Page.go_forward!(page)
    sync_lv(page)
    text = page_text(page)

    # now back again (navigate)
    Page.go_back!(page)
    sync_lv(page)
    refute page_text(page) == text
  end
end
