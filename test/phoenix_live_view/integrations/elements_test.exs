defmodule Phoenix.LiveView.ElementsTest do
  use ExUnit.Case, async: true
  use Phoenix.ConnTest

  import Phoenix.LiveViewTest
  alias Phoenix.LiveViewTest.{Endpoint}

  @endpoint Endpoint

  setup do
    {:ok, live, _} = live(Phoenix.ConnTest.build_conn(), "/elements")
    %{live: live}
  end

  test "it works", %{live: live} do
    assert live
  end
end
