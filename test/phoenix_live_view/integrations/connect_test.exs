defmodule Phoenix.LiveView.ConnectTest do
  use ExUnit.Case, async: false
  import Phoenix.LiveViewTest
  import Phoenix.ConnTest

  @endpoint Phoenix.LiveViewTest.Endpoint

  describe "connect_params" do
    test "can be read on mount" do
      {:ok, live, _html} =
        Phoenix.ConnTest.build_conn()
        |> put_connect_params(%{"connect1" => "1"})
        |> live("/connect")

      assert render(live) =~ rendered_to_string(~s|params: %{"_mounts" => 0, "connect1" => "1"}|)
    end
  end

  describe "connect_info" do
    test "can be read on mount" do
      {:ok, live, html} =
        Phoenix.ConnTest.build_conn()
        |> Plug.Conn.put_req_header("user-agent", "custom-client")
        |> Plug.Conn.put_req_header("x-foo", "bar")
        |> Plug.Conn.put_req_header("x-bar", "baz")
        |> Plug.Conn.put_req_header("tracestate", "one")
        |> Plug.Conn.put_req_header("traceparent", "two")
        |> live("/connect")

      assert_html = fn html ->
        html = String.replace(html, "&quot;", "\"")
        assert html =~ ~S<user-agent: "custom-client">
        assert html =~ ~S<x-headers: [{"x-foo", "bar"}, {"x-bar", "baz"}]>
        assert html =~ ~S<trace: [{"tracestate", "one"}, {"traceparent", "two"}]>
        assert html =~ ~S<peer: %{address: {127, 0, 0, 1}, port: 111317, ssl_cert: nil}>
        assert html =~ ~S<uri: http://www.example.com/connect>
      end

      assert_html.(html)
      assert_html.(render(live))
    end
  end
end
