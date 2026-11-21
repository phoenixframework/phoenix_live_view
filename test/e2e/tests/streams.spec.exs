defmodule Phoenix.LiveViewTest.E2E.StreamsTest do
  use Phoenix.LiveViewTest.E2E.Case

  defp users_in_dom(page, parent) do
    page
    |> Page.locator("##{parent} > *")
    |> Locator.evaluate_all!("""
    (list) =>
      list.map((el) => ({
        id: el.id,
        text: el.childNodes[0].nodeValue.trim(),
      }))
    """)
  end

  test "renders properly", %{page: page} do
    Page.goto!(page, "/stream")
    sync_lv(page)

    assert users_in_dom(page, "users") == [
             %{"id" => "users-1", "text" => "chris"},
             %{"id" => "users-2", "text" => "callan"}
           ]

    assert users_in_dom(page, "c_users") == [
             %{"id" => "c_users-1", "text" => "chris"},
             %{"id" => "c_users-2", "text" => "callan"}
           ]

    assert users_in_dom(page, "admins") == [
             %{"id" => "admins-1", "text" => "chris-admin"},
             %{"id" => "admins-2", "text" => "callan-admin"}
           ]
  end

  test "elements can be updated and deleted (LV)", %{page: page} do
    Page.goto!(page, "/stream")
    sync_lv(page)

    page
    |> Page.locator("#users-1")
    |> Locator.get_by_role(:button, name: "update")
    |> Locator.click!()

    sync_lv(page)

    assert users_in_dom(page, "users") == [
             %{"id" => "users-1", "text" => "updated"},
             %{"id" => "users-2", "text" => "callan"}
           ]

    assert users_in_dom(page, "c_users") == [
             %{"id" => "c_users-1", "text" => "chris"},
             %{"id" => "c_users-2", "text" => "callan"}
           ]

    assert users_in_dom(page, "admins") == [
             %{"id" => "admins-1", "text" => "chris-admin"},
             %{"id" => "admins-2", "text" => "callan-admin"}
           ]

    page
    |> Page.locator("#users-2")
    |> Locator.get_by_role(:button, name: "update")
    |> Locator.click!()

    sync_lv(page)

    assert users_in_dom(page, "users") == [
             %{"id" => "users-1", "text" => "updated"},
             %{"id" => "users-2", "text" => "updated"}
           ]

    assert users_in_dom(page, "c_users") == [
             %{"id" => "c_users-1", "text" => "chris"},
             %{"id" => "c_users-2", "text" => "callan"}
           ]

    assert users_in_dom(page, "admins") == [
             %{"id" => "admins-1", "text" => "chris-admin"},
             %{"id" => "admins-2", "text" => "callan-admin"}
           ]

    page
    |> Page.locator("#users-1")
    |> Locator.get_by_role(:button, name: "delete")
    |> Locator.click!()

    sync_lv(page)

    assert users_in_dom(page, "users") == [
             %{"id" => "users-2", "text" => "updated"}
           ]
  end

  test "elements can be updated and deleted (LC)", %{page: page} do
    Page.goto!(page, "/stream")
    sync_lv(page)

    page
    |> Page.locator("#c_users-1")
    |> Locator.get_by_role(:button, name: "update")
    |> Locator.click!()

    sync_lv(page)

    assert users_in_dom(page, "c_users") == [
             %{"id" => "c_users-1", "text" => "updated"},
             %{"id" => "c_users-2", "text" => "callan"}
           ]

    assert users_in_dom(page, "users") == [
             %{"id" => "users-1", "text" => "chris"},
             %{"id" => "users-2", "text" => "callan"}
           ]

    assert users_in_dom(page, "admins") == [
             %{"id" => "admins-1", "text" => "chris-admin"},
             %{"id" => "admins-2", "text" => "callan-admin"}
           ]

    page
    |> Page.locator("#c_users-2")
    |> Locator.get_by_role(:button, name: "update")
    |> Locator.click!()

    sync_lv(page)

    assert users_in_dom(page, "c_users") == [
             %{"id" => "c_users-1", "text" => "updated"},
             %{"id" => "c_users-2", "text" => "updated"}
           ]

    assert users_in_dom(page, "users") == [
             %{"id" => "users-1", "text" => "chris"},
             %{"id" => "users-2", "text" => "callan"}
           ]

    assert users_in_dom(page, "admins") == [
             %{"id" => "admins-1", "text" => "chris-admin"},
             %{"id" => "admins-2", "text" => "callan-admin"}
           ]

    page
    |> Page.locator("#c_users-1")
    |> Locator.get_by_role(:button, name: "delete")
    |> Locator.click!()

    sync_lv(page)

    assert users_in_dom(page, "c_users") == [
             %{"id" => "c_users-2", "text" => "updated"}
           ]
  end

  test "move-to-first moves the second element to the first position (LV)", %{page: page} do
    Page.goto!(page, "/stream")
    sync_lv(page)

    assert users_in_dom(page, "c_users") == [
             %{"id" => "c_users-1", "text" => "chris"},
             %{"id" => "c_users-2", "text" => "callan"}
           ]

    page
    |> Page.locator("#c_users-2")
    |> Locator.get_by_role(:button, name: "make first")
    |> Locator.click!()

    sync_lv(page)

    assert users_in_dom(page, "c_users") == [
             %{"id" => "c_users-2", "text" => "updated"},
             %{"id" => "c_users-1", "text" => "chris"}
           ]
  end

  test "stream reset removes items", %{page: page} do
    Page.goto!(page, "/stream")
    sync_lv(page)

    assert users_in_dom(page, "users") == [
             %{"id" => "users-1", "text" => "chris"},
             %{"id" => "users-2", "text" => "callan"}
           ]

    page |> Page.get_by_role(:button, name: "Reset") |> Locator.click!()
    sync_lv(page)

    assert users_in_dom(page, "users") == []
  end

  test "stream reset properly reorders items", %{page: page} do
    Page.goto!(page, "/stream")
    sync_lv(page)

    assert users_in_dom(page, "users") == [
             %{"id" => "users-1", "text" => "chris"},
             %{"id" => "users-2", "text" => "callan"}
           ]

    page |> Page.get_by_role(:button, name: "Reorder") |> Locator.click!()
    sync_lv(page)

    assert users_in_dom(page, "users") == [
             %{"id" => "users-3", "text" => "peter"},
             %{"id" => "users-1", "text" => "chris"},
             %{"id" => "users-4", "text" => "mona"}
           ]
  end

  test "stream reset updates attributes", %{page: page} do
    Page.goto!(page, "/stream")
    sync_lv(page)

    assert users_in_dom(page, "users") == [
             %{"id" => "users-1", "text" => "chris"},
             %{"id" => "users-2", "text" => "callan"}
           ]

    page |> Page.locator("#users-1") |> Expect.to_have_attribute!("data-count", "0")
    page |> Page.locator("#users-2") |> Expect.to_have_attribute!("data-count", "0")

    page |> Page.get_by_role(:button, name: "Reorder") |> Locator.click!()
    sync_lv(page)

    assert users_in_dom(page, "users") == [
             %{"id" => "users-3", "text" => "peter"},
             %{"id" => "users-1", "text" => "chris"},
             %{"id" => "users-4", "text" => "mona"}
           ]

    page |> Page.locator("#users-1") |> Expect.to_have_attribute!("data-count", "1")
    page |> Page.locator("#users-3") |> Expect.to_have_attribute!("data-count", "1")
    page |> Page.locator("#users-4") |> Expect.to_have_attribute!("data-count", "1")
  end

  describe "Issue #2656" do
    test "stream reset works when patching", %{page: page} do
      Page.goto!(page, "/healthy/fruits")
      sync_lv(page)

      page |> Page.locator("h1") |> Expect.to_contain_text!("Fruits")
      page |> Page.locator("ul") |> Expect.to_contain_text!("Apples")
      page |> Page.locator("ul") |> Expect.to_contain_text!("Oranges")

      page |> Page.get_by_role(:link, name: "Switch") |> Locator.click!()
      Expect.to_have_url!(page, "/healthy/veggies")
      sync_lv(page)

      page |> Page.locator("h1") |> Expect.to_contain_text!("Veggies")

      page |> Page.locator("ul") |> Expect.to_contain_text!("Carrots")
      page |> Page.locator("ul") |> Expect.to_contain_text!("Tomatoes")
      page |> Page.locator("ul") |> Expect.not_() |> Expect.to_contain_text!("Apples")
      page |> Page.locator("ul") |> Expect.not_() |> Expect.to_contain_text!("Oranges")

      page |> Page.get_by_role(:link, name: "Switch") |> Locator.click!()
      Expect.to_have_url!(page, "/healthy/fruits")
      sync_lv(page)

      page |> Page.locator("ul") |> Expect.not_() |> Expect.to_contain_text!("Carrots")
      page |> Page.locator("ul") |> Expect.not_() |> Expect.to_contain_text!("Tomatoes")
      page |> Page.locator("ul") |> Expect.to_contain_text!("Apples")
      page |> Page.locator("ul") |> Expect.to_contain_text!("Oranges")
    end
  end

  # helper function used below
  defp list_items(page) do
    page
    |> Page.locator("ul > li")
    |> Locator.evaluate_all!("(list) => list.map((el) => ({ id: el.id, text: el.innerText }))")
  end

  describe "Issue #2994" do
    test "can filter and reset a stream", %{page: page} do
      Page.goto!(page, "/stream/reset")
      sync_lv(page)

      assert list_items(page) == [
               %{"id" => "items-a", "text" => "A"},
               %{"id" => "items-b", "text" => "B"},
               %{"id" => "items-c", "text" => "C"},
               %{"id" => "items-d", "text" => "D"}
             ]

      page |> Page.get_by_role(:button, name: "Filter") |> Locator.click!()
      sync_lv(page)

      assert list_items(page) == [
               %{"id" => "items-b", "text" => "B"},
               %{"id" => "items-c", "text" => "C"},
               %{"id" => "items-d", "text" => "D"}
             ]

      page |> Page.get_by_role(:button, name: "Reset") |> Locator.click!()
      sync_lv(page)

      assert list_items(page) == [
               %{"id" => "items-a", "text" => "A"},
               %{"id" => "items-b", "text" => "B"},
               %{"id" => "items-c", "text" => "C"},
               %{"id" => "items-d", "text" => "D"}
             ]
    end

    test "can reorder stream", %{page: page} do
      Page.goto!(page, "/stream/reset")
      sync_lv(page)

      assert list_items(page) == [
               %{"id" => "items-a", "text" => "A"},
               %{"id" => "items-b", "text" => "B"},
               %{"id" => "items-c", "text" => "C"},
               %{"id" => "items-d", "text" => "D"}
             ]

      page |> Page.get_by_role(:button, name: "Reorder") |> Locator.click!()
      sync_lv(page)

      assert list_items(page) == [
               %{"id" => "items-b", "text" => "B"},
               %{"id" => "items-a", "text" => "A"},
               %{"id" => "items-c", "text" => "C"},
               %{"id" => "items-d", "text" => "D"}
             ]
    end

    test "can filter and then prepend / append stream", %{page: page} do
      Page.goto!(page, "/stream/reset")
      sync_lv(page)

      assert list_items(page) == [
               %{"id" => "items-a", "text" => "A"},
               %{"id" => "items-b", "text" => "B"},
               %{"id" => "items-c", "text" => "C"},
               %{"id" => "items-d", "text" => "D"}
             ]

      page |> Page.get_by_role(:button, name: "Filter") |> Locator.click!()
      sync_lv(page)

      assert list_items(page) == [
               %{"id" => "items-b", "text" => "B"},
               %{"id" => "items-c", "text" => "C"},
               %{"id" => "items-d", "text" => "D"}
             ]

      page |> Page.get_by_role(:button, name: "Prepend", exact: true) |> Locator.click!()
      sync_lv(page)

      assert [
               %{"id" => id, "text" => text},
               %{"id" => "items-b", "text" => "B"},
               %{"id" => "items-c", "text" => "C"},
               %{"id" => "items-d", "text" => "D"}
             ] = list_items(page)

      assert id =~ ~r/items-a-.*/ and is_binary(text)

      page |> Page.get_by_role(:button, name: "Reset") |> Locator.click!()
      sync_lv(page)

      assert list_items(page) == [
               %{"id" => "items-a", "text" => "A"},
               %{"id" => "items-b", "text" => "B"},
               %{"id" => "items-c", "text" => "C"},
               %{"id" => "items-d", "text" => "D"}
             ]

      page |> Page.get_by_role(:button, name: "Append", exact: true) |> Locator.click!()
      sync_lv(page)

      assert [
               %{"id" => "items-a", "text" => "A"},
               %{"id" => "items-b", "text" => "B"},
               %{"id" => "items-c", "text" => "C"},
               %{"id" => "items-d", "text" => "D"},
               %{"id" => id, "text" => text}
             ] = list_items(page)

      assert id =~ ~r/items-a-.*/ and is_binary(text)
    end
  end

  describe "Issue #2982" do
    test "can reorder a stream with LiveComponents as direct stream children", %{page: page} do
      Page.goto!(page, "/stream/reset-lc")
      sync_lv(page)

      assert list_items(page) == [
               %{"id" => "items-a", "text" => "A"},
               %{"id" => "items-b", "text" => "B"},
               %{"id" => "items-c", "text" => "C"},
               %{"id" => "items-d", "text" => "D"}
             ]

      page |> Page.get_by_role(:button, name: "Reorder") |> Locator.click!()
      sync_lv(page)

      assert list_items(page) == [
               %{"id" => "items-e", "text" => "E"},
               %{"id" => "items-a", "text" => "A"},
               %{"id" => "items-f", "text" => "F"},
               %{"id" => "items-g", "text" => "G"}
             ]
    end
  end

  describe "Issue #3023" do
    test "can bulk insert items at a specific index", %{page: page} do
      Page.goto!(page, "/stream/reset")
      sync_lv(page)

      assert list_items(page) == [
               %{"id" => "items-a", "text" => "A"},
               %{"id" => "items-b", "text" => "B"},
               %{"id" => "items-c", "text" => "C"},
               %{"id" => "items-d", "text" => "D"}
             ]

      page |> Page.get_by_role(:button, name: "Bulk insert") |> Locator.click!()
      sync_lv(page)

      assert list_items(page) == [
               %{"id" => "items-a", "text" => "A"},
               %{"id" => "items-e", "text" => "E"},
               %{"id" => "items-f", "text" => "F"},
               %{"id" => "items-g", "text" => "G"},
               %{"id" => "items-b", "text" => "B"},
               %{"id" => "items-c", "text" => "C"},
               %{"id" => "items-d", "text" => "D"}
             ]
    end
  end

  describe "stream limit - issue #2686" do
    @tag :request
    test "limit is enforced on mount, but not dead render", %{page: page, request: request} do
      html = request |> APIRequestContext.get!("/stream/limit") |> APIResponse.text!()

      for i <- 1..10 do
        assert html =~ ~s(id="items-#{i}")
      end

      Page.goto!(page, "/stream/limit")
      sync_lv(page)

      assert list_items(page) == [
               %{"id" => "items-6", "text" => "6"},
               %{"id" => "items-7", "text" => "7"},
               %{"id" => "items-8", "text" => "8"},
               %{"id" => "items-9", "text" => "9"},
               %{"id" => "items-10", "text" => "10"}
             ]
    end

    test "removes item at front when appending and limit is negative", %{page: page} do
      Page.goto!(page, "/stream/limit")
      sync_lv(page)

      # these are the defaults in the LV
      page |> Page.locator("input[name='at']") |> Expect.to_have_value!("-1")
      page |> Page.locator("input[name='limit']") |> Expect.to_have_value!("-5")

      page |> Page.get_by_role(:button, name: "add 1", exact: true) |> Locator.click!()
      sync_lv(page)

      assert list_items(page) == [
               %{"id" => "items-7", "text" => "7"},
               %{"id" => "items-8", "text" => "8"},
               %{"id" => "items-9", "text" => "9"},
               %{"id" => "items-10", "text" => "10"},
               %{"id" => "items-11", "text" => "11"}
             ]

      page |> Page.get_by_role(:button, name: "add 10", exact: true) |> Locator.click!()
      sync_lv(page)

      assert list_items(page) == [
               %{"id" => "items-17", "text" => "17"},
               %{"id" => "items-18", "text" => "18"},
               %{"id" => "items-19", "text" => "19"},
               %{"id" => "items-20", "text" => "20"},
               %{"id" => "items-21", "text" => "21"}
             ]
    end

    test "removes item at back when prepending and limit is positive", %{page: page} do
      Page.goto!(page, "/stream/limit")
      sync_lv(page)

      page |> Page.locator("input[name='at']") |> Locator.fill!("0")
      page |> Page.locator("input[name='limit']") |> Locator.fill!("5")
      page |> Page.get_by_role(:button, name: "recreate stream") |> Locator.click!()
      sync_lv(page)

      assert list_items(page) == [
               %{"id" => "items-10", "text" => "10"},
               %{"id" => "items-9", "text" => "9"},
               %{"id" => "items-8", "text" => "8"},
               %{"id" => "items-7", "text" => "7"},
               %{"id" => "items-6", "text" => "6"}
             ]

      page |> Page.get_by_role(:button, name: "add 1", exact: true) |> Locator.click!()
      sync_lv(page)

      assert list_items(page) == [
               %{"id" => "items-11", "text" => "11"},
               %{"id" => "items-10", "text" => "10"},
               %{"id" => "items-9", "text" => "9"},
               %{"id" => "items-8", "text" => "8"},
               %{"id" => "items-7", "text" => "7"}
             ]

      page |> Page.get_by_role(:button, name: "add 10", exact: true) |> Locator.click!()
      sync_lv(page)

      assert list_items(page) == [
               %{"id" => "items-21", "text" => "21"},
               %{"id" => "items-20", "text" => "20"},
               %{"id" => "items-19", "text" => "19"},
               %{"id" => "items-18", "text" => "18"},
               %{"id" => "items-17", "text" => "17"}
             ]
    end

    test "does nothing if appending and positive limit is reached", %{page: page} do
      Page.goto!(page, "/stream/limit")
      sync_lv(page)

      page |> Page.locator("input[name='at']") |> Locator.fill!("-1")
      page |> Page.locator("input[name='limit']") |> Locator.fill!("5")
      page |> Page.get_by_role(:button, name: "recreate stream") |> Locator.click!()
      sync_lv(page)

      page |> Page.get_by_role(:button, name: "clear") |> Locator.click!()
      sync_lv(page)

      assert list_items(page) == []

      Enum.reduce(1..5, [], fn i, items ->
        page |> Page.get_by_role(:button, name: "add 1", exact: true) |> Locator.click!()
        sync_lv(page)
        items = items ++ [%{"id" => "items-#{i}", "text" => Integer.to_string(i)}]
        assert list_items(page) == items
        items
      end)

      # now adding new items should do nothing, as the limit is reached
      page |> Page.get_by_role(:button, name: "add 1", exact: true) |> Locator.click!()
      sync_lv(page)

      assert list_items(page) == [
               %{"id" => "items-1", "text" => "1"},
               %{"id" => "items-2", "text" => "2"},
               %{"id" => "items-3", "text" => "3"},
               %{"id" => "items-4", "text" => "4"},
               %{"id" => "items-5", "text" => "5"}
             ]

      # same when bulk inserting
      page |> Page.get_by_role(:button, name: "add 10", exact: true) |> Locator.click!()
      sync_lv(page)

      assert list_items(page) == [
               %{"id" => "items-1", "text" => "1"},
               %{"id" => "items-2", "text" => "2"},
               %{"id" => "items-3", "text" => "3"},
               %{"id" => "items-4", "text" => "4"},
               %{"id" => "items-5", "text" => "5"}
             ]
    end

    test "does nothing if prepending and negative limit is reached", %{page: page} do
      Page.goto!(page, "/stream/limit")
      sync_lv(page)

      page |> Page.locator("input[name='at']") |> Locator.fill!("0")
      page |> Page.locator("input[name='limit']") |> Locator.fill!("-5")
      page |> Page.get_by_role(:button, name: "recreate stream") |> Locator.click!()
      sync_lv(page)

      page |> Page.get_by_role(:button, name: "clear") |> Locator.click!()
      sync_lv(page)

      assert list_items(page) == []

      Enum.reduce(1..5, [], fn i, items ->
        page |> Page.get_by_role(:button, name: "add 1", exact: true) |> Locator.click!()
        sync_lv(page)
        items = [%{"id" => "items-#{i}", "text" => Integer.to_string(i)} | items]
        assert list_items(page) == items
        items
      end)

      # now adding new items should do nothing, as the limit is reached
      page |> Page.get_by_role(:button, name: "add 1", exact: true) |> Locator.click!()
      sync_lv(page)

      assert list_items(page) == [
               %{"id" => "items-5", "text" => "5"},
               %{"id" => "items-4", "text" => "4"},
               %{"id" => "items-3", "text" => "3"},
               %{"id" => "items-2", "text" => "2"},
               %{"id" => "items-1", "text" => "1"}
             ]

      # same when bulk inserting
      page |> Page.get_by_role(:button, name: "add 10", exact: true) |> Locator.click!()
      sync_lv(page)

      assert list_items(page) == [
               %{"id" => "items-5", "text" => "5"},
               %{"id" => "items-4", "text" => "4"},
               %{"id" => "items-3", "text" => "3"},
               %{"id" => "items-2", "text" => "2"},
               %{"id" => "items-1", "text" => "1"}
             ]
    end

    test "arbitrary index", %{page: page} do
      Page.goto!(page, "/stream/limit")
      sync_lv(page)

      page |> Page.locator("input[name='at']") |> Locator.fill!("1")
      page |> Page.locator("input[name='limit']") |> Locator.fill!("5")
      page |> Page.get_by_role(:button, name: "recreate stream") |> Locator.click!()
      sync_lv(page)

      # we tried to insert 10 items
      assert list_items(page) == [
               %{"id" => "items-1", "text" => "1"},
               %{"id" => "items-10", "text" => "10"},
               %{"id" => "items-9", "text" => "9"},
               %{"id" => "items-8", "text" => "8"},
               %{"id" => "items-7", "text" => "7"}
             ]

      page |> Page.get_by_role(:button, name: "add 10", exact: true) |> Locator.click!()
      sync_lv(page)

      assert list_items(page) == [
               %{"id" => "items-1", "text" => "1"},
               %{"id" => "items-20", "text" => "20"},
               %{"id" => "items-19", "text" => "19"},
               %{"id" => "items-18", "text" => "18"},
               %{"id" => "items-17", "text" => "17"}
             ]

      page |> Page.locator("input[name='at']") |> Locator.fill!("1")
      page |> Page.locator("input[name='limit']") |> Locator.fill!("-5")
      page |> Page.get_by_role(:button, name: "recreate stream") |> Locator.click!()
      sync_lv(page)

      # we tried to insert 10 items
      assert list_items(page) == [
               %{"id" => "items-10", "text" => "10"},
               %{"id" => "items-5", "text" => "5"},
               %{"id" => "items-4", "text" => "4"},
               %{"id" => "items-3", "text" => "3"},
               %{"id" => "items-2", "text" => "2"}
             ]

      page |> Page.get_by_role(:button, name: "add 10", exact: true) |> Locator.click!()
      sync_lv(page)

      assert list_items(page) == [
               %{"id" => "items-20", "text" => "20"},
               %{"id" => "items-5", "text" => "5"},
               %{"id" => "items-4", "text" => "4"},
               %{"id" => "items-3", "text" => "3"},
               %{"id" => "items-2", "text" => "2"}
             ]
    end
  end

  test "any stream insert for elements already in the DOM does not reorder", %{page: page} do
    Page.goto!(page, "/stream/reset")
    sync_lv(page)

    assert list_items(page) == [
             %{"id" => "items-a", "text" => "A"},
             %{"id" => "items-b", "text" => "B"},
             %{"id" => "items-c", "text" => "C"},
             %{"id" => "items-d", "text" => "D"}
           ]

    page |> Page.get_by_role(:button, name: "Prepend C") |> Locator.click!()
    sync_lv(page)

    assert list_items(page) == [
             %{"id" => "items-a", "text" => "A"},
             %{"id" => "items-b", "text" => "B"},
             %{"id" => "items-c", "text" => "C"},
             %{"id" => "items-d", "text" => "D"}
           ]

    page |> Page.get_by_role(:button, name: "Append C") |> Locator.click!()
    sync_lv(page)

    assert list_items(page) == [
             %{"id" => "items-a", "text" => "A"},
             %{"id" => "items-b", "text" => "B"},
             %{"id" => "items-c", "text" => "C"},
             %{"id" => "items-d", "text" => "D"}
           ]

    page |> Page.get_by_role(:button, name: "Insert C at 1") |> Locator.click!()
    sync_lv(page)

    assert list_items(page) == [
             %{"id" => "items-a", "text" => "A"},
             %{"id" => "items-b", "text" => "B"},
             %{"id" => "items-c", "text" => "C"},
             %{"id" => "items-d", "text" => "D"}
           ]

    page |> Page.get_by_role(:button, name: "Insert at 1", exact: true) |> Locator.click!()
    sync_lv(page)

    assert [
             %{"id" => "items-a", "text" => "A"},
             %{"id" => id, "text" => text},
             %{"id" => "items-b", "text" => "B"},
             %{"id" => "items-c", "text" => "C"},
             %{"id" => "items-d", "text" => "D"}
           ] = list_items(page)

    assert id =~ ~r/items-a-.*/ and is_binary(text)

    page |> Page.get_by_role(:button, name: "Reset") |> Locator.click!()
    sync_lv(page)

    assert list_items(page) == [
             %{"id" => "items-a", "text" => "A"},
             %{"id" => "items-b", "text" => "B"},
             %{"id" => "items-c", "text" => "C"},
             %{"id" => "items-d", "text" => "D"}
           ]

    page |> Page.get_by_role(:button, name: "Delete C and insert at 1") |> Locator.click!()
    sync_lv(page)

    assert list_items(page) == [
             %{"id" => "items-a", "text" => "A"},
             %{"id" => "items-c", "text" => "C"},
             %{"id" => "items-b", "text" => "B"},
             %{"id" => "items-d", "text" => "D"}
           ]
  end

  test "stream nested in a LiveComponent is properly restored on reset", %{page: page} do
    Page.goto!(page, "/stream/nested-component-reset")
    sync_lv(page)

    child_items = fn page, id ->
      page
      |> Page.locator("##{id} div[phx-update=stream] > *")
      |> Locator.evaluate_all!("(div) => div.map((el) => ({ id: el.id, text: el.innerText }))")
    end

    assert [
             %{"id" => "items-a", "text" => a},
             %{"id" => "items-b", "text" => b},
             %{"id" => "items-c", "text" => c},
             %{"id" => "items-d", "text" => d}
           ] = list_items(page)

    assert a =~ ~r/A/ and b =~ ~r/B/ and c =~ ~r/C/ and d =~ ~r/D/

    for id <- ["a", "b", "c", "d"] do
      assert child_items.(page, "items-#{id}") == [
               %{"id" => "nested-items-#{id}-a", "text" => "N-A"},
               %{"id" => "nested-items-#{id}-b", "text" => "N-B"},
               %{"id" => "nested-items-#{id}-c", "text" => "N-C"},
               %{"id" => "nested-items-#{id}-d", "text" => "N-D"}
             ]
    end

    # now reorder the nested stream of items-a
    page |> Page.locator("#items-a button") |> Locator.click!()
    sync_lv(page)

    assert child_items.(page, "items-a") == [
             %{"id" => "nested-items-a-e", "text" => "N-E"},
             %{"id" => "nested-items-a-a", "text" => "N-A"},
             %{"id" => "nested-items-a-f", "text" => "N-F"},
             %{"id" => "nested-items-a-g", "text" => "N-G"}
           ]

    # unchanged
    for id <- ["b", "c", "d"] do
      assert child_items.(page, "items-#{id}") == [
               %{"id" => "nested-items-#{id}-a", "text" => "N-A"},
               %{"id" => "nested-items-#{id}-b", "text" => "N-B"},
               %{"id" => "nested-items-#{id}-c", "text" => "N-C"},
               %{"id" => "nested-items-#{id}-d", "text" => "N-D"}
             ]
    end

    # now reorder the parent stream
    page |> Page.locator("#parent-reorder") |> Locator.click!()
    sync_lv(page)

    assert [
             %{"id" => "items-e", "text" => e},
             %{"id" => "items-a", "text" => a},
             %{"id" => "items-f", "text" => f},
             %{"id" => "items-g", "text" => g}
           ] = list_items(page)

    assert e =~ ~r/E/ and a =~ ~r/A/ and f =~ ~r/F/ and g =~ ~r/G/

    # the new children's stream items have the correct order
    for id <- ["e", "f", "g"] do
      assert child_items.(page, "items-#{id}") == [
               %{"id" => "nested-items-#{id}-a", "text" => "N-A"},
               %{"id" => "nested-items-#{id}-b", "text" => "N-B"},
               %{"id" => "nested-items-#{id}-c", "text" => "N-C"},
               %{"id" => "nested-items-#{id}-d", "text" => "N-D"}
             ]
    end

    # Item A has the same children as before, still reordered
    assert child_items.(page, "items-a") == [
             %{"id" => "nested-items-a-e", "text" => "N-E"},
             %{"id" => "nested-items-a-a", "text" => "N-A"},
             %{"id" => "nested-items-a-f", "text" => "N-F"},
             %{"id" => "nested-items-a-g", "text" => "N-G"}
           ]
  end

  test "phx-remove is handled correctly when restoring nodes", %{page: page} do
    Page.goto!(page, "/stream/reset?phx-remove")
    sync_lv(page)

    assert list_items(page) == [
             %{"id" => "items-a", "text" => "A"},
             %{"id" => "items-b", "text" => "B"},
             %{"id" => "items-c", "text" => "C"},
             %{"id" => "items-d", "text" => "D"}
           ]

    page |> Page.get_by_role(:button, name: "Filter") |> Locator.click!()
    sync_lv(page)

    assert list_items(page) == [
             %{"id" => "items-b", "text" => "B"},
             %{"id" => "items-c", "text" => "C"},
             %{"id" => "items-d", "text" => "D"}
           ]

    page |> Page.get_by_role(:button, name: "Reset") |> Locator.click!()
    sync_lv(page)

    assert list_items(page) == [
             %{"id" => "items-a", "text" => "A"},
             %{"id" => "items-b", "text" => "B"},
             %{"id" => "items-c", "text" => "C"},
             %{"id" => "items-d", "text" => "D"}
           ]
  end

  test "issue #3129 - streams asynchronously assigned and rendered inside a comprehension",
       %{page: page} do
    Page.goto!(page, "/stream/inside-for")
    sync_lv(page)

    assert list_items(page) == [
             %{"id" => "items-a", "text" => "A"},
             %{"id" => "items-b", "text" => "B"},
             %{"id" => "items-c", "text" => "C"},
             %{"id" => "items-d", "text" => "D"}
           ]
  end

  test "issue #3260 - supports non-stream items with id in stream container", %{page: page} do
    Page.goto!(page, "/stream?empty_item")

    assert users_in_dom(page, "users") == [
             %{"id" => "users-1", "text" => "chris"},
             %{"id" => "users-2", "text" => "callan"},
             %{"id" => "users-empty", "text" => "Empty!"}
           ]

    page |> Page.get_by_text("Empty") |> Expect.to_be_hidden!()
    eval_lv(page, ~s|socket.view.handle_event("reset-users", %{}, socket)|)
    page |> Page.get_by_text("Empty") |> Expect.to_be_visible!()

    assert users_in_dom(page, "users") == [
             %{"id" => "users-empty", "text" => "Empty!"}
           ]

    eval_lv(page, ~s|socket.view.handle_event("append-users", %{}, socket)|)
    page |> Page.get_by_text("Empty") |> Expect.to_be_hidden!()

    assert users_in_dom(page, "users") == [
             %{"id" => "users-4", "text" => "foo"},
             %{"id" => "users-3", "text" => "last_user"},
             %{"id" => "users-empty", "text" => "Empty!"}
           ]
  end

  test "JS commands are applied when re-joining", %{page: page} do
    Page.goto!(page, "/stream")
    sync_lv(page)

    assert users_in_dom(page, "users") == [
             %{"id" => "users-1", "text" => "chris"},
             %{"id" => "users-2", "text" => "callan"}
           ]

    page |> Page.locator("#users-1") |> Expect.to_be_visible!()

    page
    |> Page.locator("#users-1")
    |> Locator.get_by_role(:button, name: "JS Hide")
    |> Locator.click!()

    page |> Page.locator("#users-1") |> Expect.to_be_hidden!()

    Page.evaluate!(
      page,
      "() => new Promise((resolve) => window.liveSocket.disconnect(resolve))"
    )

    # not reconnect
    Page.evaluate!(page, "() => window.liveSocket.connect()")
    sync_lv(page)
    # should still be hidden
    page |> Page.locator("#users-1") |> Expect.to_be_hidden!()
  end

  test "update_only", %{page: page} do
    Page.goto!(page, "/stream/reset")
    sync_lv(page)

    assert list_items(page) == [
             %{"id" => "items-a", "text" => "A"},
             %{"id" => "items-b", "text" => "B"},
             %{"id" => "items-c", "text" => "C"},
             %{"id" => "items-d", "text" => "D"}
           ]

    page |> Page.get_by_role(:button, name: "Add E (update only)") |> Locator.click!()
    sync_lv(page)

    assert list_items(page) == [
             %{"id" => "items-a", "text" => "A"},
             %{"id" => "items-b", "text" => "B"},
             %{"id" => "items-c", "text" => "C"},
             %{"id" => "items-d", "text" => "D"}
           ]

    page |> Page.get_by_role(:button, name: "Update C (update only)") |> Locator.click!()
    sync_lv(page)

    assert [
             %{"id" => "items-a", "text" => "A"},
             %{"id" => "items-b", "text" => "B"},
             %{"id" => "items-c", "text" => c},
             %{"id" => "items-d", "text" => "D"}
           ] = list_items(page)

    assert c =~ ~r/C .*/
  end

  # https://github.com/phoenixframework/phoenix_live_view/issues/3784
  # empty text nodes would accumulate inside streams, leading to linear
  # growth. When locked trees were involved, the growth could become
  # exponential though, because text nodes from the clone would accumulate,
  # doubling the text nodes on unlock
  test "empty text nodes are pruned", %{page: page} do
    Page.goto!(page, "/stream/limit")
    sync_lv(page)

    initial_count =
      Page.evaluate!(
        page,
        ~S|() => document.getElementById("items").innerHTML.match(/\n/g).length|
      )

    for _i <- 0..9 do
      page |> Page.get_by_role(:button, name: "add 10") |> Locator.click!()
    end

    sync_lv(page)

    new_count =
      Page.evaluate!(
        page,
        ~S|() => document.getElementById("items").innerHTML.match(/\n/g).length|
      )

    assert new_count == initial_count
  end
end
