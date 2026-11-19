defmodule Phoenix.LiveViewTest.E2E.Issue3378Test do
  use Phoenix.LiveViewTest.E2E.Case

  test "can rejoin with nested streams without errors", %{page: page} do
    errors = array()

    Page.on(page, :page_error, fn err ->
      push(errors, err)
    end)

    Page.goto!(page, "/issues/3378")
    sync_lv(page)

    page |> Page.locator("#notifications") |> Expect.to_contain_text!("big")

    Page.evaluate!(
      page,
      "() => new Promise((resolve) => window.liveSocket.disconnect(resolve))"
    )

    Page.evaluate!(page, "() => window.liveSocket.connect()")
    sync_lv(page)

    # no js errors should be thrown
    assert values(errors) == []
  end
end
