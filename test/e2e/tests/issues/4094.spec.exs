defmodule Phoenix.LiveViewTest.E2E.Issue4094Test do
  use Phoenix.LiveViewTest.E2E.Case

  # https://github.com/phoenixframework/phoenix_live_view/issues/4094
  test "no errors when handle_params redirects", %{page: page} do
    js_errors = array()

    Page.on(page, :page_error, fn error ->
      push(js_errors, Exception.message(error))
    end)

    Page.goto!(page, "/issues/4094")
    sync_lv(page)

    # Clicking a link that redirects in handle_params would throw an exception
    # on the client.
    Page.click!(page, "a")

    Expect.to_have_url!(page, "/navigation/a")
    assert length(values(js_errors)) == 0
  end
end
