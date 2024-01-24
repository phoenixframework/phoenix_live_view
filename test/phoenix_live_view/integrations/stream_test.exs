defmodule Phoenix.LiveView.StreamTest do
  use ExUnit.Case, async: true

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Phoenix.LiveViewTest.{StreamLive, DOM, Endpoint}

  @endpoint Endpoint

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

    assert lv |> render() |> users_in_dom("users") == [
             {"users-1", "chris"},
             {"users-2", "callan"}
           ]

    assert lv
           |> element(~S|#users-1 button[phx-click="update"]|)
           |> render_click()
           |> users_in_dom("users") ==
             [{"users-1", "updated"}, {"users-2", "callan"}]

    assert_pruned_stream(lv)

    assert lv
           |> element(~S|#users-2 button[phx-click="move-to-first"]|)
           |> render_click()
           |> users_in_dom("users") ==
             [{"users-2", "updated"}, {"users-1", "updated"}]

    assert lv
           |> element(~S|#users-2 button[phx-click="move-to-last"]|)
           |> render_click()
           |> users_in_dom("users") ==
             [{"users-1", "updated"}, {"users-2", "updated"}]

    assert lv
           |> element(~S|#users-1 button[phx-click="delete"]|)
           |> render_click()
           |> users_in_dom("users") ==
             [{"users-2", "updated"}]

    assert_pruned_stream(lv)

    # second stream in LiveView
    assert lv |> render() |> users_in_dom("admins") == [
             {"admins-1", "chris-admin"},
             {"admins-2", "callan-admin"}
           ]

    assert lv
           |> element(~S|#admins-1 button[phx-click="admin-update"]|)
           |> render_click()
           |> users_in_dom("admins") ==
             [{"admins-1", "updated"}, {"admins-2", "callan-admin"}]

    assert_pruned_stream(lv)

    assert lv
           |> element(~S|#admins-2 button[phx-click="admin-move-to-first"]|)
           |> render_click()
           |> users_in_dom("admins") ==
             [{"admins-2", "updated"}, {"admins-1", "updated"}]

    assert lv
           |> element(~S|#admins-2 button[phx-click="admin-move-to-last"]|)
           |> render_click()
           |> users_in_dom("admins") ==
             [{"admins-1", "updated"}, {"admins-2", "updated"}]

    assert lv
           |> element(~S|#admins-1 button[phx-click="admin-delete"]|)
           |> render_click()
           |> users_in_dom("admins") ==
             [{"admins-2", "updated"}]

    # resets

    assert lv |> render() |> users_in_dom("users") == [{"users-2", "updated"}]

    StreamLive.run(lv, fn socket ->
      {:reply, :ok, Phoenix.LiveView.stream(socket, :users, [], reset: true)}
    end)

    assert lv |> render() |> users_in_dom("users") == []
    assert lv |> render() |> users_in_dom("admins") == [{"admins-2", "updated"}]
  end

  test "should properly reset after a stream has been set after mount", %{conn: conn} do
    {:ok, lv, _} = live(conn, "/stream")
    assert lv |> element("#users div") |> has_element?()

    lv |> render_hook("reset-users", %{})
    refute lv |> element("#users div") |> has_element?()

    lv |> render_hook("stream-users", %{})
    assert lv |> element("#users div") |> has_element?()

    lv |> render_hook("reset-users", %{})
    refute lv |> element("#users div") |> has_element?()
  end

  test "should preserve the order of appended items", %{conn: conn} do
    {:ok, lv, _} = live(conn, "/stream")
    assert lv |> element("#users div:last-child") |> render =~ "callan"

    lv |> render_hook("append-users", %{})
    assert lv |> element("#users div:last-child") |> render =~ "last_user"
  end

  test "properly orders elements on reset", %{conn: conn} do
    {:ok, lv, _} = live(conn, "/stream")

    assert lv |> render() |> users_in_dom("users") == [
             {"users-1", "chris"},
             {"users-2", "callan"}
           ]

    lv |> render_hook("reset-users-reorder", %{})

    assert lv |> render() |> users_in_dom("users") == [
             {"users-3", "peter"},
             {"users-1", "chris"},
             {"users-4", "mona"}
           ]
  end

  test "stream reset on patch", %{conn: conn} do
    {:ok, lv, _html} = live(conn, "/healthy/fruits")

    assert has_element?(lv, "h1", "Fruits")

    assert has_element?(lv, "li", "Apples")
    assert has_element?(lv, "li", "Oranges")

    lv
    |> element("a", "Switch")
    |> render_click()

    assert_patched(lv, "/healthy/veggies")

    assert has_element?(lv, "h1", "Veggies")

    assert has_element?(lv, "li", "Carrots")
    assert has_element?(lv, "li", "Tomatoes")

    refute has_element?(lv, "li", "Apples")
    refute has_element?(lv, "li", "Oranges")

    lv
    |> element("a", "Switch")
    |> render_click()

    assert_patched(lv, "/healthy/fruits")

    assert has_element?(lv, "h1", "Fruits")

    refute has_element?(lv, "li", "Carrots")
    refute has_element?(lv, "li", "Tomatoes")

    assert has_element?(lv, "li", "Apples")
    assert has_element?(lv, "li", "Oranges")
  end

  describe "issue #2994" do
    test "can filter and reset a stream", %{conn: conn} do
      {:ok, lv, html} = live(conn, "/stream/reset")

      assert ids_in_ul_list(html) == ["items-a", "items-b", "items-c", "items-d"]

      html = assert lv |> element("button", "Filter") |> render_click()
      assert ids_in_ul_list(html) == ["items-b", "items-c", "items-d"]

      html = assert lv |> element("button", "Reset") |> render_click()
      assert ids_in_ul_list(html) == ["items-a", "items-b", "items-c", "items-d"]
    end

    test "can reorder stream", %{conn: conn} do
      {:ok, lv, html} = live(conn, "/stream/reset")

      assert ids_in_ul_list(html) == ["items-a", "items-b", "items-c", "items-d"]

      html = assert lv |> element("button", "Reorder") |> render_click()
      assert ids_in_ul_list(html) == ["items-b", "items-a", "items-c", "items-d"]
    end

    test "can filter and then prepend / append stream", %{conn: conn} do
      {:ok, lv, html} = live(conn, "/stream/reset")

      assert ids_in_ul_list(html) == ["items-a", "items-b", "items-c", "items-d"]

      html = assert lv |> element("button", "Filter") |> render_click()
      assert ids_in_ul_list(html) == ["items-b", "items-c", "items-d"]

      html = assert lv |> element("button", "Prepend") |> render_click()
      assert [<<"items-a-", _::binary>>, "items-b", "items-c", "items-d"] = ids_in_ul_list(html)

      html = assert lv |> element("button", "Reset") |> render_click()
      assert ids_in_ul_list(html) == ["items-a", "items-b", "items-c", "items-d"]

      html = assert lv |> element("button", "Append") |> render_click()

      assert ["items-a", "items-b", "items-c", "items-d", <<"items-a-", _::binary>>] =
               ids_in_ul_list(html)
    end
  end

  describe "within live component" do
    test "stream operations", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/stream")

      assert lv |> render() |> users_in_dom("c_users") == [
               {"c_users-1", "chris"},
               {"c_users-2", "callan"}
             ]

      assert lv
             |> element(~S|#c_users-1 button[phx-click="update"]|)
             |> render_click()
             |> users_in_dom("c_users") ==
               [{"c_users-1", "updated"}, {"c_users-2", "callan"}]

      assert_pruned_stream(lv)

      assert lv
             |> element(~S|#c_users-2 button[phx-click="move-to-first"]|)
             |> render_click()
             |> users_in_dom("c_users") ==
               [{"c_users-2", "updated"}, {"c_users-1", "updated"}]

      assert lv
             |> element(~S|#c_users-2 button[phx-click="move-to-last"]|)
             |> render_click()
             |> users_in_dom("c_users") ==
               [{"c_users-1", "updated"}, {"c_users-2", "updated"}]

      assert lv
             |> element(~S|#c_users-1 button[phx-click="delete"]|)
             |> render_click()
             |> users_in_dom("c_users") ==
               [{"c_users-2", "updated"}]

      assert lv |> render() |> users_in_dom("users") == [
               {"users-1", "chris"},
               {"users-2", "callan"}
             ]

      assert lv
             |> element(~S|#users-1 button[phx-click="move"]|)
             |> render_click(%{at: "1", name: "chris-forward"})
             |> users_in_dom("users") ==
               [{"users-2", "callan"}, {"users-1", "chris-forward"}]

      assert lv
             |> element(~S|#users-1 button[phx-click="move"]|)
             |> render_click(%{at: "0", name: "chris-backward"})
             |> users_in_dom("users") ==
               [{"users-1", "chris-backward"}, {"users-2", "callan"}]

      assert lv
             |> element(~S|#users-1 button[phx-click="move"]|)
             |> render_click(%{at: "0", name: "chris-same"})
             |> users_in_dom("users") ==
               [{"users-1", "chris-same"}, {"users-2", "callan"}]

      assert lv
             |> element(~S|#users-2 button[phx-click="move"]|)
             |> render_click(%{at: "1", name: "callan-same"})
             |> users_in_dom("users") ==
               [{"users-1", "chris-same"}, {"users-2", "callan-same"}]

      # resets

      assert lv |> render() |> users_in_dom("c_users") == [{"c_users-2", "updated"}]

      Phoenix.LiveView.send_update(lv.pid, Phoenix.LiveViewTest.StreamComponent,
        id: "stream-component",
        reset: {:c_users, []}
      )

      assert lv |> render() |> users_in_dom("c_users") == []

      Phoenix.LiveView.send_update(lv.pid, Phoenix.LiveViewTest.StreamComponent,
        id: "stream-component",
        send_assigns_to: self()
      )

      assert_receive {:assigns, %{streams: streams}}
      assert streams.c_users.inserts == []
      assert streams.c_users.deletes == []
      assert_pruned_stream(lv)
    end

    test "issue #2982 - can reorder a stream with LiveComponents as direct stream children", %{conn: conn} do
      {:ok, lv, html} = live(conn, "/stream/reset-lc")

      assert ids_in_ul_list(html) == ["items-a", "items-b", "items-c", "items-d"]

      html = assert lv |> element("button", "Reorder") |> render_click()
      assert ids_in_ul_list(html) == ["items-e", "items-a", "items-f", "items-g"]
    end
  end

  test "issue #3023 - can bulk insert at index != -1", %{conn: conn} do
    {:ok, lv, html} = live(conn, "/stream/reset")

    assert ids_in_ul_list(html) == ["items-a", "items-b", "items-c", "items-d"]

    html = assert lv |> element("button", "Bulk insert") |> render_click()
    assert ids_in_ul_list(html) == ["items-a", "items-e", "items-f", "items-g", "items-b", "items-c", "items-d"]
  end

  test "stream raises when attempting to consume ahead of for", %{conn: conn} do
    {:ok, lv, _html} = live(conn, "/stream")

    assert Phoenix.LiveViewTest.HooksLive.exits_with(lv, ArgumentError, fn ->
             render_click(lv, "consume-stream-invalid", %{})
           end) =~ ~r/streams can only be consumed directly by a for comprehension/
  end

  describe "limit" do
    test "limit is enforced on mount, but not dead render", %{conn: conn} do
      conn = get(conn, "/stream/limit")
      assert html_response(conn, 200) |> ids_in_ul_list() == [
               "items-1",
               "items-2",
               "items-3",
               "items-4",
               "items-5",
               "items-6",
               "items-7",
               "items-8",
               "items-9",
               "items-10"
            ]

      {:ok, _lv, html} = live(conn)

      assert ids_in_ul_list(html) == [
        "items-6",
        "items-7",
        "items-8",
        "items-9",
        "items-10"
      ]
    end

    test "removes item at front when appending and limit is negative", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/stream/limit")

      assert lv |> render_hook("configure", %{"at" => "-1", "limit" => "-5"}) |> ids_in_ul_list()== [
        "items-6",
        "items-7",
        "items-8",
        "items-9",
        "items-10"
      ]

      assert lv |> render_hook("insert_1") |> ids_in_ul_list()== [
        "items-7",
        "items-8",
        "items-9",
        "items-10",
        "items-11"
      ]

      assert lv |> render_hook("insert_10") |> ids_in_ul_list()== [
        "items-17",
        "items-18",
        "items-19",
        "items-20",
        "items-21"
      ]
    end

    test "removes item at back when prepending and limit is positive", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/stream/limit")

      assert lv |> render_hook("configure", %{"at" => "0", "limit" => "5"}) |> ids_in_ul_list() == [
        "items-10",
        "items-9",
        "items-8",
        "items-7",
        "items-6"
      ]

      assert lv |> render_hook("insert_1") |> ids_in_ul_list()== [
        "items-11",
        "items-10",
        "items-9",
        "items-8",
        "items-7"
      ]

      assert lv |> render_hook("insert_10") |> ids_in_ul_list()== [
        "items-21",
        "items-20",
        "items-19",
        "items-18",
        "items-17"
      ]
    end

    test "does nothing if appending and positive limit is reached", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/stream/limit")

      assert lv |> render_hook("configure", %{"at" => "-1", "limit" => "5"}) |> ids_in_ul_list() == [
        "items-1",
        "items-2",
        "items-3",
        "items-4",
        "items-5"
      ]

      # adding new items should do nothing, as the limit is reached
      assert lv |> render_hook("insert_1") |> ids_in_ul_list()== [
        "items-1",
        "items-2",
        "items-3",
        "items-4",
        "items-5"
      ]

      assert lv |> render_hook("insert_10") |> ids_in_ul_list() == [
        "items-1",
        "items-2",
        "items-3",
        "items-4",
        "items-5"
      ]
    end

    test "does nothing if prepending and negative limit is reached", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/stream/limit")

      assert lv |> render_hook("configure", %{"at" => "0", "limit" => "-5"}) |> ids_in_ul_list() == [
        "items-5",
        "items-4",
        "items-3",
        "items-2",
        "items-1"
      ]

      # adding new items should do nothing, as the limit is reached
      assert lv |> render_hook("insert_1") |> ids_in_ul_list()== [
        "items-5",
        "items-4",
        "items-3",
        "items-2",
        "items-1"
      ]

      assert lv |> render_hook("insert_10") |> ids_in_ul_list() == [
        "items-5",
        "items-4",
        "items-3",
        "items-2",
        "items-1"
      ]
    end

    test "arbitrary index", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/stream/limit")

      assert lv |> render_hook("configure", %{"at" => "1", "limit" => "5"}) |> ids_in_ul_list() == [
        "items-1",
        "items-10",
        "items-9",
        "items-8",
        "items-7"
      ]

      assert lv |> render_hook("insert_10") |> ids_in_ul_list()== [
        "items-1",
        "items-20",
        "items-19",
        "items-18",
        "items-17"
      ]

      assert lv |> render_hook("configure", %{"at" => "1", "limit" => "-5"}) |> ids_in_ul_list() == [
        "items-10",
        "items-5",
        "items-4",
        "items-3",
        "items-2"
      ]

      assert lv |> render_hook("insert_10") |> ids_in_ul_list() == [
        "items-20",
        "items-5",
        "items-4",
        "items-3",
        "items-2"
      ]
    end
  end

  defp assert_pruned_stream(lv) do
    stream = StreamLive.run(lv, fn socket -> {:reply, socket.assigns.streams.users, socket} end)
    assert stream.inserts == []
    assert stream.deletes == []
  end

  defp users_in_dom(html, parent_id) do
    html
    |> DOM.parse()
    |> DOM.all("##{parent_id} > *")
    |> Enum.map(fn {_tag, _attrs, [text | _children]} = child ->
      {DOM.attribute(child, "id"), String.trim(text)}
    end)
  end

  defp ids_in_ul_list(html) do
    html
    |> DOM.parse()
    |> DOM.all("ul > li")
    |> Enum.map(fn child -> DOM.attribute(child, "id") end)
  end
end
