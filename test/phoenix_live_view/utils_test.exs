defmodule Phoenix.LiveView.UtilsTest do
  use ExUnit.Case, async: true

  alias Phoenix.LiveView.Utils
  alias Phoenix.LiveViewTest.Support.Endpoint

  test "sign" do
    assert is_binary(Utils.sign_flash(Endpoint, %{"info" => "hi"}))
  end

  test "verify with valid flash token" do
    token = Utils.sign_flash(Endpoint, %{"info" => "hi"})
    assert Utils.verify_flash(Endpoint, token) == %{"info" => "hi"}
  end

  test "verify with invalid flash token" do
    assert Utils.verify_flash(Endpoint, "bad") == %{}
    assert Utils.verify_flash(Endpoint, nil) == %{}
  end

  test "valid_destination!/2" do
    assert Utils.valid_destination!("/foo", "")
    assert Utils.valid_destination!("http://example.com/foo", "")

    assert_raise ArgumentError, fn ->
      Utils.valid_destination!("javascript:alert('hi')", "")
    end

    # whitespace does not change the result
    assert_raise ArgumentError, fn ->
      Utils.valid_destination!("    javascript:alert('hi')", "")
    end

    assert_raise ArgumentError, fn ->
      Utils.valid_destination!("javascript:alert('hi')   ", "")
    end

    assert_raise ArgumentError, fn ->
      Utils.valid_destination!("    javascript:alert('hi')   ", "")
    end

    # can allow custom protocols with tuple syntax, e.g. {:javascript, "..."}
    assert Utils.valid_destination!({:javascript, "alert('hi')"}, "")
  end
end
