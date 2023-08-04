defmodule Phoenix.LiveView.AssignAsyncTest do
  use ExUnit.Case, async: true
  import Phoenix.ConnTest

  import Phoenix.LiveViewTest
  alias Phoenix.LiveViewTest.Endpoint

  @endpoint Endpoint

  setup do
    {:ok, conn: Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), %{})}
  end

  describe "assign_async" do
    test "bad return", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/async?test=bad_return")

      await_async(lv)
      assert render(lv) =~
               "error: {:error, %ArgumentError{message: &quot;expected assign_async to return {:ok, map} of\\nassigns for [:data] or {:error, reason}, got: 123\\n&quot;}}"

      assert render(lv)
    end

    test "missing known key", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/async?test=bad_ok")

      await_async(lv)
      assert render(lv) =~
               "expected assign_async to return map of\\nassigns for all keys in [:data]"

      assert render(lv)
    end

    test "valid return", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/async?test=ok")
      await_async(lv)
      assert render(lv) =~ "data: 123"
    end

    test "raise during execution", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/async?test=raise")

      await_async(lv)
      assert render(lv) =~ "error: {:error, %RuntimeError{message: &quot;boom&quot;}}"
    end
  end
end
