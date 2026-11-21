defmodule Phoenix.LiveViewTest.E2E.Issue3931Test do
  use Phoenix.LiveViewTest.E2E.Case

  alias Playwright.WebSocket

  # https://github.com/phoenixframework/phoenix_live_view/issues/3931
  test "dynamic attributes reset __changed__ and properly re-render", %{page: page} do
    web_socket_events = array()

    Page.on(page, :web_socket, fn ws ->
      WebSocket.on(ws, :frame_sent, fn event ->
        push(web_socket_events, %{type: "sent", payload: event.payload})
      end)

      WebSocket.on(ws, :frame_received, fn event ->
        push(web_socket_events, %{type: "received", payload: event.payload})
      end)

      WebSocket.on(ws, :close, fn _ -> push(web_socket_events, %{type: "close"}) end)
    end)

    Page.goto!(page, "/issues/3931")
    sync_lv(page)

    # it should be updated asynchronously
    page
    |> Page.locator("#async")
    |> Expect.to_contain_text!("This was loaded asynchronously!")

    assert_equal(
      values(web_socket_events),
      array_containing([
        %{type: "sent", payload: string_containing("phx_join")},
        %{type: "received", payload: string_containing("phx_reply")},
        %{type: "received", payload: string_containing("diff")}
      ])
    )
  end
end
