defmodule Phoenix.LiveViewTest.E2E.Issue4442Test do
  use Phoenix.LiveViewTest.E2E.Case

  # https://github.com/phoenixframework/phoenix_live_view/issues/4442
  for operation <- ["reset", "insert"] do
    test "portal added to an existing stream item with #{operation} is teleported with its content",
         %{page: page} do
      Page.goto!(page, "/issues/4442")
      sync_lv(page)

      teleported = Page.locator(page, "#portal-target #preview-content-1")
      Expect.to_have_count!(teleported, 0)

      page |> Page.locator("##{unquote(operation)}") |> Locator.click!()
      sync_lv(page)

      Expect.to_have_text!(teleported, "Ticket details")
      # the portal template in the DOM must keep its content after teleporting
      assert page
             |> Page.locator("#preview-1")
             |> Locator.evaluate!(
               "(el) => el.content.querySelector(\"#preview-content-1\")?.textContent ?? null"
             ) == "Ticket details"
    end
  end
end
