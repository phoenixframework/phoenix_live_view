defmodule Phoenix.LiveViewTest.E2E.FormUnsavedTest do
  use Phoenix.LiveViewTest.E2E.Case

  alias Playwright.WebSocket

  # each test's events: an `array/0` each, as the listeners run in processes of their own
  setup %{page: page} do
    web_socket_events = array()
    network_events = array()

    Page.on(page, :request, fn request ->
      push(network_events, %{method: Request.method(request), url: Request.url(request)})
    end)

    Page.on(page, :web_socket, fn ws ->
      WebSocket.on(ws, :frame_sent, fn event ->
        push(web_socket_events, %{type: "sent", payload: event.payload})
      end)

      WebSocket.on(ws, :frame_received, fn event ->
        push(web_socket_events, %{type: "received", payload: event.payload})
      end)

      WebSocket.on(ws, :close, fn _ -> push(web_socket_events, %{type: "close"}) end)
    end)

    %{network_events: network_events, web_socket_events: web_socket_events}
  end

  test "can prevent live navigation and beforeunload", %{
    page: page,
    network_events: network_events,
    web_socket_events: web_socket_events
  } do
    Page.goto!(page, "/form-unsaved")
    sync_lv(page)

    assert Page.evaluate!(page, "() => window.unsavedEvents") == []

    page |> Page.locator("#unsaved-note") |> Locator.fill!("draft")
    sync_lv(page)
    page |> Page.locator("#unsaved-value") |> Expect.to_have_text!("Unsaved value: draft")

    clear(network_events)
    clear(web_socket_events)

    confirm_promise = Page.wait_for_event(page, :dialog)

    click_promise =
      Promise.async(fn ->
        page |> Page.get_by_role(:link, name: "Leave form") |> Locator.click!()
      end)

    confirm_dialog = Promise.await!(confirm_promise)
    assert Dialog.type(confirm_dialog) == "confirm"
    assert Dialog.message(confirm_dialog) == "You have unsaved changes. Leave without saving?"
    Dialog.dismiss!(confirm_dialog)
    Promise.await!(click_promise)

    Expect.to_have_url!(page, "/form-unsaved")
    assert values(network_events) == []
    assert values(web_socket_events) == []

    assert Page.evaluate!(page, "() => window.unsavedEvents") == [
             %{
               "type" => "phx",
               "detail" => %{
                 "href" => "http://localhost:4004/form-unsaved/target",
                 "patch" => false,
                 "pop" => false,
                 "direction" => "forward"
               }
             }
           ]

    page |> Page.locator("#unsaved-note") |> Locator.fill!("draft after live nav cancel")
    sync_lv(page)

    page
    |> Page.locator("#unsaved-value")
    |> Expect.to_have_text!("Unsaved value: draft after live nav cancel")

    dialog_promise = Page.wait_for_event(page, :dialog)
    close_promise = Promise.async(fn -> Page.close!(page, run_before_unload: true) end)
    dialog = Promise.await!(dialog_promise)
    assert Dialog.type(dialog) == "beforeunload"
    Dialog.dismiss!(dialog)
    Promise.await!(close_promise)

    assert Page.is_closed(page) == false
    Expect.to_have_url!(page, "/form-unsaved")
    page |> Page.locator("#unsaved-note") |> Expect.to_have_value!("draft after live nav cancel")

    assert Page.evaluate!(page, "() => window.unsavedEvents") == [
             %{
               "type" => "phx",
               "detail" => %{
                 "href" => "http://localhost:4004/form-unsaved/target",
                 "patch" => false,
                 "pop" => false,
                 "direction" => "forward"
               }
             },
             %{"type" => "beforeunload"}
           ]

    assert Page.evaluate!(
             page,
             """
             () => ({
               connected: window.liveSocket.isConnected(),
               unloaded: window.liveSocket.isUnloaded(),
             })
             """
           ) == %{"connected" => true, "unloaded" => false}

    page |> Page.locator("#unsaved-note") |> Locator.fill!("draft after beforeunload cancel")
    sync_lv(page)

    page
    |> Page.locator("#unsaved-value")
    |> Expect.to_have_text!("Unsaved value: draft after beforeunload cancel")
  end
end
