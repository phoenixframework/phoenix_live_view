defmodule Phoenix.LiveView.FlashTest do
  use ExUnit.Case, async: true

  alias Phoenix.LiveView.Flash
  alias Phoenix.LiveViewTest.Endpoint

  test "sign" do
    assert is_binary(Flash.sign(Endpoint, %{"info" => "hi"}))
  end

  test "verify with valid flash token" do
    token = Flash.sign(Endpoint, %{"info" => "hi"})
    assert Flash.verify(Endpoint, token) == %{"info" => "hi"}
  end

  test "verify with invalid flash token" do
    assert Flash.verify(Endpoint, "bad") == %{}
  end
end
