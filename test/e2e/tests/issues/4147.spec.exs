defmodule Phoenix.LiveViewTest.E2E.Issue4147Test do
  use Phoenix.LiveViewTest.E2E.Case

  # https://github.com/phoenixframework/phoenix_live_view/issues/4147
  test "hook outside of liveview does works when reconnecting", %{page: page} do
    logs = array()

    Page.on(page, :console, fn msg ->
      push(logs, ConsoleMessage.text(msg))
    end)

    errors = array()

    Page.on(page, :page_error, fn err ->
      push(errors, err)
    end)

    Page.goto!(page, "/issues/4147")
    sync_lv(page)

    Page.evaluate!(
      page,
      "() => new Promise((resolve) => window.liveSocket.disconnect(resolve))"
    )

    page |> Page.locator(".phx-loading") |> Expect.to_have_count!(1)

    Page.evaluate!(page, "() => window.liveSocket.connect()")
    sync_lv(page)

    assert length(values(errors)) == 0
    # Hook was mounted once
    assert length(Enum.filter(values(logs), &String.contains?(&1, "HookOutside mounted"))) == 1
  end
end
