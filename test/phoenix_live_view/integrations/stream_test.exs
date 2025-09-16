defmodule Phoenix.LiveView.StreamTest do
  use ExUnit.Case, async: true

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Phoenix.LiveViewTest.{DOM, TreeDOM}
  alias Phoenix.LiveViewTest.Support.{StreamLive, Endpoint}

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

  test "updates attributes on reset", %{conn: conn} do
    {:ok, lv, _} = live(conn, "/stream")

    assert lv |> render() |> users_in_dom("users") == [
             {"users-1", "chris"},
             {"users-2", "callan"}
           ]

    html = render(lv)
    tree = TreeDOM.normalize_to_tree(html)
    assert TreeDOM.by_id!(tree, "users-1") |> TreeDOM.attribute("data-count") == "0"
    assert TreeDOM.by_id!(tree, "users-2") |> TreeDOM.attribute("data-count") == "0"

    lv |> render_hook("reset-users-reorder", %{})

    assert lv |> render() |> users_in_dom("users") == [
             {"users-3", "peter"},
             {"users-1", "chris"},
             {"users-4", "mona"}
           ]

    html = render(lv)
    tree = TreeDOM.normalize_to_tree(html)
    assert TreeDOM.by_id!(tree, "users-1") |> TreeDOM.attribute("data-count") == "1"
    assert TreeDOM.by_id!(tree, "users-3") |> TreeDOM.attribute("data-count") == "1"
    assert TreeDOM.by_id!(tree, "users-4") |> TreeDOM.attribute("data-count") == "1"
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

  describe "within nested lv" do
    test "does not clear stream when parent updates", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/stream/nested")
      lv = find_live_child(lv, "nested")

      # let the parent update
      Process.sleep(100)

      assert ul_list_children(render(lv)) == [
               {"items-a", "A"},
               {"items-b", "B"},
               {"items-c", "C"},
               {"items-d", "D"}
             ]

      html = assert lv |> element("button", "Filter") |> render_click()

      assert ul_list_children(html) == [
               {"items-b", "B"},
               {"items-c", "C"},
               {"items-d", "D"}
             ]

      html = assert lv |> element("button", "Reset") |> render_click()

      assert ul_list_children(html) == [
               {"items-a", "A"},
               {"items-b", "B"},
               {"items-c", "C"},
               {"items-d", "D"}
             ]
    end
  end

  describe "issue #2994" do
    test "can filter and reset a stream", %{conn: conn} do
      {:ok, lv, html} = live(conn, "/stream/reset")

      assert ul_list_children(html) == [
               {"items-a", "A"},
               {"items-b", "B"},
               {"items-c", "C"},
               {"items-d", "D"}
             ]

      html = assert lv |> element("button", "Filter") |> render_click()

      assert ul_list_children(html) == [
               {"items-b", "B"},
               {"items-c", "C"},
               {"items-d", "D"}
             ]

      html = assert lv |> element("button", "Reset") |> render_click()

      assert ul_list_children(html) == [
               {"items-a", "A"},
               {"items-b", "B"},
               {"items-c", "C"},
               {"items-d", "D"}
             ]
    end

    test "can reorder stream", %{conn: conn} do
      {:ok, lv, html} = live(conn, "/stream/reset")

      assert ul_list_children(html) == [
               {"items-a", "A"},
               {"items-b", "B"},
               {"items-c", "C"},
               {"items-d", "D"}
             ]

      html = assert lv |> element("button", "Reorder") |> render_click()

      assert ul_list_children(html) == [
               {"items-b", "B"},
               {"items-a", "A"},
               {"items-c", "C"},
               {"items-d", "D"}
             ]
    end

    test "can filter and then prepend / append stream", %{conn: conn} do
      {:ok, lv, html} = live(conn, "/stream/reset")

      assert ul_list_children(html) == [
               {"items-a", "A"},
               {"items-b", "B"},
               {"items-c", "C"},
               {"items-d", "D"}
             ]

      html = assert lv |> element("button", "Filter") |> render_click()

      assert ul_list_children(html) == [
               {"items-b", "B"},
               {"items-c", "C"},
               {"items-d", "D"}
             ]

      html = assert lv |> element(~s(button[phx-click="prepend"]), "Prepend") |> render_click()

      assert [
               {<<"items-a-", _::binary>>, _},
               {"items-b", "B"},
               {"items-c", "C"},
               {"items-d", "D"}
             ] = ul_list_children(html)

      html = assert lv |> element("button", "Reset") |> render_click()

      assert ul_list_children(html) == [
               {"items-a", "A"},
               {"items-b", "B"},
               {"items-c", "C"},
               {"items-d", "D"}
             ]

      html = assert lv |> element(~s(button[phx-click="append"]), "Append") |> render_click()

      assert [
               {"items-a", "A"},
               {"items-b", "B"},
               {"items-c", "C"},
               {"items-d", "D"},
               {<<"items-a-", _::binary>>, _}
             ] =
               ul_list_children(html)
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

      Phoenix.LiveView.send_update(lv.pid, Phoenix.LiveViewTest.Support.StreamComponent,
        id: "stream-component",
        reset: {:c_users, []}
      )

      assert lv |> render() |> users_in_dom("c_users") == []

      Phoenix.LiveView.send_update(lv.pid, Phoenix.LiveViewTest.Support.StreamComponent,
        id: "stream-component",
        send_assigns_to: self()
      )

      assert_receive {:assigns, %{streams: streams}}
      assert streams.c_users.inserts == []
      assert streams.c_users.deletes == []
      assert_pruned_stream(lv)
    end

    test "issue #2982 - can reorder a stream with LiveComponents as direct stream children", %{
      conn: conn
    } do
      {:ok, lv, html} = live(conn, "/stream/reset-lc")

      assert ul_list_children(html) == [
               {"items-a", "A"},
               {"items-b", "B"},
               {"items-c", "C"},
               {"items-d", "D"}
             ]

      html = assert lv |> element("button", "Reorder") |> render_click()

      assert ul_list_children(html) == [
               {"items-e", "E"},
               {"items-a", "A"},
               {"items-f", "F"},
               {"items-g", "G"}
             ]
    end
  end

  test "issue #3023 - can bulk insert at index != -1", %{conn: conn} do
    {:ok, lv, html} = live(conn, "/stream/reset")

    assert ul_list_children(html) == [
             {"items-a", "A"},
             {"items-b", "B"},
             {"items-c", "C"},
             {"items-d", "D"}
           ]

    html = assert lv |> element("button", "Bulk insert") |> render_click()

    assert ul_list_children(html) == [
             {"items-a", "A"},
             {"items-e", "E"},
             {"items-f", "F"},
             {"items-g", "G"},
             {"items-b", "B"},
             {"items-c", "C"},
             {"items-d", "D"}
           ]
  end

  test "any stream insert for elements already in the DOM does not reorder", %{conn: conn} do
    {:ok, lv, html} = live(conn, "/stream/reset")

    assert ul_list_children(html) == [
             {"items-a", "A"},
             {"items-b", "B"},
             {"items-c", "C"},
             {"items-d", "D"}
           ]

    html = assert lv |> element("button", "Prepend C") |> render_click()

    assert ul_list_children(html) == [
             {"items-a", "A"},
             {"items-b", "B"},
             {"items-c", "C"},
             {"items-d", "D"}
           ]

    html = assert lv |> element("button", "Append C") |> render_click()

    assert ul_list_children(html) == [
             {"items-a", "A"},
             {"items-b", "B"},
             {"items-c", "C"},
             {"items-d", "D"}
           ]

    html = assert lv |> element("button", "Insert C at 1") |> render_click()

    assert ul_list_children(html) == [
             {"items-a", "A"},
             {"items-b", "B"},
             {"items-c", "C"},
             {"items-d", "D"}
           ]

    html = assert lv |> element("button", "Insert at 1") |> render_click()

    assert [{"items-a", "A"}, _, {"items-b", "B"}, {"items-c", "C"}, {"items-d", "D"}] =
             ul_list_children(html)

    html = assert lv |> element("button", "Reset") |> render_click()

    assert [{"items-a", "A"}, {"items-b", "B"}, {"items-c", "C"}, {"items-d", "D"}] =
             ul_list_children(html)

    html = assert lv |> element("button", "Delete C and insert at 1") |> render_click()

    assert [{"items-a", "A"}, {"items-c", "C"}, {"items-b", "B"}, {"items-d", "D"}] =
             ul_list_children(html)
  end

  test "stream raises when attempting to consume ahead of for", %{conn: conn} do
    {:ok, lv, _html} = live(conn, "/stream")

    assert Phoenix.LiveViewTest.Support.HooksLive.exits_with(lv, ArgumentError, fn ->
             render_click(lv, "consume-stream-invalid", %{})
           end) =~ ~r/streams can only be consumed directly by a for comprehension/
  end

  test "stream raises when nodes without id are in container", %{conn: conn} do
    {:ok, lv, _html} = live(conn, "/stream")

    assert Phoenix.LiveViewTest.Support.HooksLive.exits_with(lv, ArgumentError, fn ->
             render_click(lv, "stream-no-id", %{})
           end) =~
             ~r/setting phx-update to "stream" requires setting an ID on each child/
  end

  test "issue #3260 - supports non-stream items with id in stream container", %{conn: conn} do
    {:ok, lv, _html} = live(conn, "/stream")

    render_click(lv, "stream-extra-with-id", %{})
    html = render(lv)

    assert [{"users-1", "chris"}, {"users-2", "callan"}, {"users-empty", "Empty!"}] =
             users_in_dom(html, "users")

    assert render_click(lv, "reset-users", %{}) |> users_in_dom("users") == [
             {"users-empty", "Empty!"}
           ]

    assert render_click(lv, "append-users", %{}) |> users_in_dom("users") == [
             {"users-empty", "Empty!"},
             {"users-4", "foo"},
             {"users-3", "last_user"}
           ]
  end

  test "handles high frequency updates properly", %{conn: conn} do
    {:ok, lv, _html} = live(conn, "/stream/high-frequency-stream-and-non-stream-updates")

    for _i <- 1..50 do
      assert lv |> render_hook("insert_item")
      Process.sleep(10)
    end

    {_tag, _attributes, children} =
      render(lv) |> TreeDOM.normalize_to_tree() |> TreeDOM.by_id!("mystream")

    assert length(children) == 50

    # wait for more updates
    Process.sleep(100)

    # we should still have 50 items
    {_tag, _attributes, children} =
      render(lv) |> TreeDOM.normalize_to_tree() |> TreeDOM.by_id!("mystream")

    assert length(children) == 50
  end

  describe "limit" do
    test "limit is enforced on mount, but not dead render", %{conn: conn} do
      conn = get(conn, "/stream/limit")

      assert html_response(conn, 200) |> ul_list_children() == [
               {"items-1", "1"},
               {"items-2", "2"},
               {"items-3", "3"},
               {"items-4", "4"},
               {"items-5", "5"},
               {"items-6", "6"},
               {"items-7", "7"},
               {"items-8", "8"},
               {"items-9", "9"},
               {"items-10", "10"}
             ]

      {:ok, _lv, html} = live(conn)

      assert ul_list_children(html) == [
               {"items-6", "6"},
               {"items-7", "7"},
               {"items-8", "8"},
               {"items-9", "9"},
               {"items-10", "10"}
             ]
    end

    test "removes item at front when appending and limit is negative", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/stream/limit")

      assert lv
             |> render_hook("configure", %{"at" => "-1", "limit" => "-5"})
             |> ul_list_children() ==
               [
                 {"items-6", "6"},
                 {"items-7", "7"},
                 {"items-8", "8"},
                 {"items-9", "9"},
                 {"items-10", "10"}
               ]

      assert lv |> render_hook("insert_1") |> ul_list_children() == [
               {"items-7", "7"},
               {"items-8", "8"},
               {"items-9", "9"},
               {"items-10", "10"},
               {"items-11", "11"}
             ]

      assert lv |> render_hook("insert_10") |> ul_list_children() == [
               {"items-17", "17"},
               {"items-18", "18"},
               {"items-19", "19"},
               {"items-20", "20"},
               {"items-21", "21"}
             ]
    end

    test "removes item at back when prepending and limit is positive", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/stream/limit")

      assert lv |> render_hook("configure", %{"at" => "0", "limit" => "5"}) |> ul_list_children() ==
               [
                 {"items-10", "10"},
                 {"items-9", "9"},
                 {"items-8", "8"},
                 {"items-7", "7"},
                 {"items-6", "6"}
               ]

      assert lv |> render_hook("insert_1") |> ul_list_children() == [
               {"items-11", "11"},
               {"items-10", "10"},
               {"items-9", "9"},
               {"items-8", "8"},
               {"items-7", "7"}
             ]

      assert lv |> render_hook("insert_10") |> ul_list_children() == [
               {"items-21", "21"},
               {"items-20", "20"},
               {"items-19", "19"},
               {"items-18", "18"},
               {"items-17", "17"}
             ]
    end

    test "does nothing if appending and positive limit is reached", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/stream/limit")

      assert lv |> render_hook("configure", %{"at" => "-1", "limit" => "5"}) |> ul_list_children() ==
               [
                 {"items-1", "1"},
                 {"items-2", "2"},
                 {"items-3", "3"},
                 {"items-4", "4"},
                 {"items-5", "5"}
               ]

      # adding new items should do nothing, as the limit is reached
      assert lv |> render_hook("insert_1") |> ul_list_children() == [
               {"items-1", "1"},
               {"items-2", "2"},
               {"items-3", "3"},
               {"items-4", "4"},
               {"items-5", "5"}
             ]

      assert lv |> render_hook("insert_10") |> ul_list_children() == [
               {"items-1", "1"},
               {"items-2", "2"},
               {"items-3", "3"},
               {"items-4", "4"},
               {"items-5", "5"}
             ]
    end

    test "does nothing if prepending and negative limit is reached", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/stream/limit")

      assert lv |> render_hook("configure", %{"at" => "0", "limit" => "-5"}) |> ul_list_children() ==
               [
                 {"items-5", "5"},
                 {"items-4", "4"},
                 {"items-3", "3"},
                 {"items-2", "2"},
                 {"items-1", "1"}
               ]

      # adding new items should do nothing, as the limit is reached
      assert lv |> render_hook("insert_1") |> ul_list_children() == [
               {"items-5", "5"},
               {"items-4", "4"},
               {"items-3", "3"},
               {"items-2", "2"},
               {"items-1", "1"}
             ]

      assert lv |> render_hook("insert_10") |> ul_list_children() == [
               {"items-5", "5"},
               {"items-4", "4"},
               {"items-3", "3"},
               {"items-2", "2"},
               {"items-1", "1"}
             ]
    end

    test "arbitrary index", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/stream/limit")

      assert lv |> render_hook("configure", %{"at" => "1", "limit" => "5"}) |> ul_list_children() ==
               [
                 {"items-1", "1"},
                 {"items-10", "10"},
                 {"items-9", "9"},
                 {"items-8", "8"},
                 {"items-7", "7"}
               ]

      assert lv |> render_hook("insert_10") |> ul_list_children() == [
               {"items-1", "1"},
               {"items-20", "20"},
               {"items-19", "19"},
               {"items-18", "18"},
               {"items-17", "17"}
             ]

      assert lv |> render_hook("configure", %{"at" => "1", "limit" => "-5"}) |> ul_list_children() ==
               [
                 {"items-10", "10"},
                 {"items-5", "5"},
                 {"items-4", "4"},
                 {"items-3", "3"},
                 {"items-2", "2"}
               ]

      assert lv |> render_hook("insert_10") |> ul_list_children() == [
               {"items-20", "20"},
               {"items-5", "5"},
               {"items-4", "4"},
               {"items-3", "3"},
               {"items-2", "2"}
             ]
    end
  end

  test "stream nested in a LiveComponent is properly restored on reset", %{conn: conn} do
    {:ok, lv, _html} = live(conn, "/stream/nested-component-reset")

    childItems = fn html, id ->
      html
      |> TreeDOM.normalize_to_tree()
      |> TreeDOM.by_id!(id)
      |> TreeDOM.filter(fn node ->
        TreeDOM.tag(node) == "div" && TreeDOM.attribute(node, "phx-update") == "stream"
      end)
      |> case do
        [{_tag, _attrs, children}] -> children
      end
      |> Enum.map(fn {_tag, _attrs, [text | _children]} = child ->
        {TreeDOM.attribute(child, "id"), String.trim(text)}
      end)
    end

    assert render(lv) |> ul_list_children() == [
             {"items-a", "A"},
             {"items-b", "B"},
             {"items-c", "C"},
             {"items-d", "D"}
           ]

    for id <- ["a", "b", "c", "d"] do
      assert render(lv) |> childItems.("items-#{id}") == [
               {"nested-items-#{id}-a", "N-A"},
               {"nested-items-#{id}-b", "N-B"},
               {"nested-items-#{id}-c", "N-C"},
               {"nested-items-#{id}-d", "N-D"}
             ]
    end

    # now reorder the nested stream of items-a
    assert lv |> element("#items-a button") |> render_click() |> childItems.("items-a") == [
             {"nested-items-a-e", "N-E"},
             {"nested-items-a-a", "N-A"},
             {"nested-items-a-f", "N-F"},
             {"nested-items-a-g", "N-G"}
           ]

    # unchanged
    for id <- ["b", "c", "d"] do
      assert render(lv) |> childItems.("items-#{id}") == [
               {"nested-items-#{id}-a", "N-A"},
               {"nested-items-#{id}-b", "N-B"},
               {"nested-items-#{id}-c", "N-C"},
               {"nested-items-#{id}-d", "N-D"}
             ]
    end

    # now reorder the parent stream
    assert lv |> element("#parent-reorder") |> render_click() |> ul_list_children() == [
             {"items-e", "E"},
             {"items-a", "A"},
             {"items-f", "F"},
             {"items-g", "G"}
           ]

    # the new children's stream items have the correct order
    for id <- ["e", "f", "g"] do
      assert render(lv) |> childItems.("items-#{id}") == [
               {"nested-items-#{id}-a", "N-A"},
               {"nested-items-#{id}-b", "N-B"},
               {"nested-items-#{id}-c", "N-C"},
               {"nested-items-#{id}-d", "N-D"}
             ]
    end

    # Item A has the same children as before, still reordered
    assert render(lv) |> childItems.("items-a") == [
             {"nested-items-a-e", "N-E"},
             {"nested-items-a-a", "N-A"},
             {"nested-items-a-f", "N-F"},
             {"nested-items-a-g", "N-G"}
           ]
  end

  test "issue #3129 - streams asynchronously assigned and rendered inside a comprehension", %{
    conn: conn
  } do
    {:ok, lv, _html} = live(conn, "/stream/inside-for")

    html = render_async(lv)

    assert ul_list_children(html) == [
             {"items-a", "A"},
             {"items-b", "B"},
             {"items-c", "C"},
             {"items-d", "D"}
           ]
  end

  test "update_only", %{conn: conn} do
    {:ok, lv, html} = live(conn, "/stream/reset")

    assert ul_list_children(html) == [
             {"items-a", "A"},
             {"items-b", "B"},
             {"items-c", "C"},
             {"items-d", "D"}
           ]

    html = assert lv |> element("button", "Add E (update only)") |> render_click()

    assert ul_list_children(html) == [
             {"items-a", "A"},
             {"items-b", "B"},
             {"items-c", "C"},
             {"items-d", "D"}
           ]

    html = assert lv |> element("button", "Update C (update only)") |> render_click()

    assert [
             {"items-a", "A"},
             {"items-b", "B"},
             {"items-c", "C " <> _},
             {"items-d", "D"}
           ] = ul_list_children(html)
  end

  test "issue #3993 - stream reset + keyed comprehensions", %{conn: conn} do
    {:ok, lv, _html} = live(conn, "/healthy/fruits")

    assert has_element?(lv, "h1", "Fruits")
    assert has_element?(lv, "li", "Apples")
    assert has_element?(lv, "li", "Oranges")

    html = render_hook(lv, "load-more", %{})

    assert html =~ "Apples"
    assert html =~ "Oranges"
    assert html =~ "Pumpkins"
    assert html =~ "Melons"
  end

  defp assert_pruned_stream(lv) do
    stream = StreamLive.run(lv, fn socket -> {:reply, socket.assigns.streams.users, socket} end)
    assert stream.inserts == []
    assert stream.deletes == []
  end

  defp users_in_dom(html, parent_id) do
    html
    |> DOM.parse_document()
    |> elem(0)
    |> DOM.all("##{parent_id} > *")
    |> DOM.to_tree()
    |> Enum.map(fn {_tag, _attrs, [text | _children]} = child ->
      {TreeDOM.attribute(child, "id"), String.trim(text)}
    end)
  end

  defp ul_list_children(html) do
    html
    |> DOM.parse_document()
    |> elem(0)
    |> DOM.all("ul > li")
    |> DOM.to_tree()
    |> Enum.map(fn {_tag, _attrs, [text | _children]} = child ->
      {TreeDOM.attribute(child, "id"), String.trim(text)}
    end)
  end
end
