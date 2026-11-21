defmodule Phoenix.LiveViewTest.E2E.Issue3651Test do
  use Phoenix.LiveViewTest.E2E.Case

  # https://github.com/phoenixframework/phoenix_live_view/issues/3651
  test "locked hook with dynamic id is properly cleared", %{page: page} do
    Page.goto!(page, "/issues/3651")
    sync_lv(page)

    page |> Page.locator("#notice") |> Expect.to_be_hidden!()

    # we want to wait for some events to have been pushed
    Page.wait_for_timeout!(page, 100)

    assert Page.evaluate!(
             page,
             ~s|() => parseInt(document.querySelector("#total").textContent)|
           ) <= 50
  end
end
