defmodule Phoenix.LiveView.StreamTest do
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Phoenix.LiveViewTest.{StreamLive, DOM, Endpoint}
  alias Phoenix.LiveView.LiveReloadTestHelpers, as: Helpers

  @endpoint Endpoint

  setup_all do
    Helpers.start_endpoint(@endpoint)
    :ok
  end

  setup do
    {:ok, conn: Plug.Test.init_test_session(build_conn(), %{})}
  end

  test "stream is pruned after render", %{conn: conn} do
    {:ok, lv, html} = live(conn, "/stream")

    users = [{"users-1", "chris"}, {"users-2", "callan"}]

    for {id, name} <- users do
      assert html =~ ~s|id="#{id}"|
      assert html =~ name
    end

    stream = StreamLive.run(lv, fn socket -> {:reply, socket.assigns.streams.users, socket} end)

    assert stream.inserts == []
    assert stream.deletes == []

    assert lv |> render() |> users_in_dom() == [{"users-1", "chris"}, {"users-2", "callan"}]

    assert lv
           |> element(~S|#users-1 button[phx-click="update"]|)
           |> render_click()
           |> users_in_dom() ==
             [{"users-1", "updated"}, {"users-2", "callan"}]

    assert_pruned_stream(lv)

    assert lv
           |> element(~S|#users-2 button[phx-click="move-to-first"]|)
           |> render_click()
           |> users_in_dom() ==
             [{"users-2", "updated"}, {"users-1", "updated"}]

    assert lv
           |> element(~S|#users-2 button[phx-click="move-to-last"]|)
           |> render_click()
           |> users_in_dom() ==
             [{"users-1", "updated"}, {"users-2", "updated"}]

    assert lv
           |> element(~S|#users-1 button[phx-click="delete"]|)
           |> render_click()
           |> users_in_dom() ==
             [{"users-2", "updated"}]

    assert_pruned_stream(lv)
  end

  defp assert_pruned_stream(lv) do
    stream = StreamLive.run(lv, fn socket -> {:reply, socket.assigns.streams.users, socket} end)
    assert stream.inserts == []
    assert stream.deletes == []
  end

  defp users_in_dom(html) do
    html
    |> DOM.parse()
    |> DOM.all("#users > *")
    |> Enum.map(fn {_tag, [{"id", id}], [text | _children]} ->
      {id, String.trim(text)}
    end)
  end
end
