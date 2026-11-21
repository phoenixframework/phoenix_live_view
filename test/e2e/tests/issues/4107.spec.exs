defmodule Phoenix.LiveViewTest.E2E.Issue4107Test do
  use Phoenix.LiveViewTest.E2E.Case

  # https://github.com/phoenixframework/phoenix_live_view/issues/4107
  test "external form submission from teleported form is successful", %{page: page} do
    Page.goto!(page, "/issues/4107")
    sync_lv(page)

    page |> Page.locator("button") |> Locator.click!()

    # With the bug, the form would not be submitted, because
    # the form element was not part of the DOM any more.
    Expect.to_have_url!(page, "/api/test")
  end
end
