defmodule Phoenix.LiveView.HelpersTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveView.Helpers
  import Phoenix.HTML
  import Phoenix.HTML.Form

  describe "live_patch" do
    test "single arity" do
      dom =
        live_patch(to: "/", do: "text")
        |> safe_to_string()

      assert dom =~ ~s|data-phx-link="patch"|
      assert dom =~ ~s|data-phx-link-state="push"|
      assert dom =~ ~s|text</a>|
      refute dom =~ ~s|to="/|
    end

    test "forwards dom attribute options" do
      dom =
        live_patch("next", to: "/", class: "btn btn-large", data: [page_number: 2])
        |> safe_to_string()

      assert dom =~ ~s|class="btn btn-large"|
      assert dom =~ ~s|data-page-number="2"|
      assert dom =~ ~s|data-phx-link="patch"|
      assert dom =~ ~s|data-phx-link-state="push"|
    end

    test "overwrites reserved options" do
      dom =
        live_patch("next", to: "page-1", href: "page-2", data: [phx_link: "other"], replace: true)
        |> safe_to_string()

      assert dom =~ ~s|href="page-1"|
      refute dom =~ ~s|href="page-2"|
      assert dom =~ ~s|data-phx-link="patch"|
      assert dom =~ ~s|data-phx-link-state="replace"|
      refute dom =~ ~s|data-phx-link="other"|
    end

    test "uses HTML safe protocol" do
      assert live_patch(123, to: "page") |> safe_to_string() =~ "123</a>"
    end
  end

  describe "live_redirect" do
    test "single arity" do
      dom =
        live_redirect(to: "/", do: "text")
        |> safe_to_string()

      assert dom =~ ~s|data-phx-link="redirect"|
      assert dom =~ ~s|data-phx-link-state="push"|
      assert dom =~ ~s|text</a>|
      refute dom =~ ~s|to="/|
    end

    test "forwards dom attribute options" do
      dom =
        live_redirect("next", to: "/", class: "btn btn-large", data: [page_number: 2])
        |> safe_to_string()

      assert dom =~ ~s|class="btn btn-large"|
      assert dom =~ ~s|data-page-number="2"|
      assert dom =~ ~s|data-phx-link="redirect"|
      assert dom =~ ~s|data-phx-link-state="push"|
    end

    test "overwrites reserved options" do
      dom =
        live_redirect("next",
          to: "page-1",
          href: "page-2",
          data: [phx_link: "other"],
          replace: true
        )
        |> safe_to_string()

      assert dom =~ ~s|href="page-1"|
      refute dom =~ ~s|href="page-2"|
      assert dom =~ ~s|data-phx-link="redirect"|
      assert dom =~ ~s|data-phx-link-state="replace"|
      refute dom =~ ~s|data-phx-link="other"|
    end

    test "uses HTML safe protocol" do
      assert live_redirect(123, to: "page") |> safe_to_string() =~ "123</a>"
    end
  end

  describe "live_title_tag/2" do
    test "prefix only" do
      assert safe_to_string(live_title_tag("My Title", prefix: "MyApp – ")) ==
               ~s|<title data-prefix="MyApp – ">MyApp – My Title</title>|
    end

    test "suffix only" do
      assert safe_to_string(live_title_tag("My Title", suffix: " – MyApp")) ==
               ~s|<title data-suffix=" – MyApp">My Title – MyApp</title>|
    end

    test "prefix and suffix" do
      assert safe_to_string(live_title_tag("My Title", prefix: "Welcome: ", suffix: " – MyApp")) ==
               ~s|<title data-prefix="Welcome: " data-suffix=" – MyApp">Welcome: My Title – MyApp</title>|
    end

    test "without prefix or suffix" do
      assert safe_to_string(live_title_tag("My Title")) ==
               ~s|<title>My Title</title>|
    end

    test "bad options" do
      assert_raise ArgumentError, ~r/expects a :prefix and\/or :suffix/, fn ->
        live_title_tag("bad", bad: :bad)
      end
    end
  end

  defp parse(template) do
    template
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
    |> Phoenix.LiveViewTest.DOM.parse()
  end

  describe "flash" do
    test "raises when missing required assigns" do
      assert_raise ArgumentError, ~r/missing :type assign/, fn ->
        assigns = %{}

        parse(~H"""
        <.flash />
        """)
      end
    end

    test "generates flash if message is present" do
      assigns = %{}

      html =
        parse(~H"""
        <.flash type="alert" message="User created successfully." />
        """)

      assert [
               {"p", [{"class", "alert alert-alert"}, {"role", "alert"}],
                ["User created successfully."]}
             ] == html
    end

    test "does not generate flash if message is empty" do
      assigns = %{}

      empty_messages = [nil, "", " "]

      for empty_message <- empty_messages do
        html =
          parse(~H"""
          <.flash type="alert" message={empty_message} />
          """)

        assert [] == html
      end
    end
  end

  describe "form" do
    test "raises when missing required assigns" do
      assert_raise ArgumentError, ~r/missing :for assign/, fn ->
        assigns = %{}

        parse(~H"""
        <.form let={f}>
          <%= text_input f, :foo %>
        </.form>
        """)
      end
    end

    test "generates form with no options" do
      assigns = %{}

      html =
        parse(~H"""
        <.form let={f} for={:myform}>
          <%= text_input f, :foo %>
        </.form>
        """)

      assert [
               {"form", [{"action", "#"}, {"method", "post"}],
                [
                  {"input", [{"name", "_csrf_token"}, {"type", "hidden"}, {"value", _}], []},
                  {"input", [{"id", "myform_foo"}, {"name", "myform[foo]"}, {"type", "text"}], []}
                ]}
             ] = html
    end

    test "does not generate csrf_token if method is not post" do
      assigns = %{}

      html =
        parse(~H"""
        <.form let={f} for={:myform} method="get">
          <%= text_input f, :foo %>
        </.form>
        """)

      assert [
               {"form", [{"action", "#"}, {"method", "get"}],
                [
                  {"input", [{"id", "myform_foo"}, {"name", "myform[foo]"}, {"type", "text"}], []}
                ]}
             ] = html
    end

    test "generates form with available options and custom attributes" do
      assigns = %{}

      html =
        parse(~H"""
        <.form let={user_form}
          for={%Plug.Conn{}}
          id="form"
          action="/"
          method="put"
          multipart
          csrf_token="123"
          as="user"
          errors={[name: "can't be blank"]}
          data-foo="bar"
          class="pretty"
          phx-change="valid"
        >
          <%= text_input user_form, :foo %>
          <%= inspect(user_form.errors) %>
        </.form>
        """)

      assert [
               {"form",
                [
                  {"action", "/"},
                  {"method", "post"},
                  {"enctype", "multipart/form-data"},
                  {"class", "pretty"},
                  {"data-foo", "bar"},
                  {"id", "form"},
                  {"phx-change", "valid"}
                ],
                [
                  {"input", [{"name", "_method"}, {"type", "hidden"}, {"value", "put"}], []},
                  {"input", [{"name", "_csrf_token"}, {"type", "hidden"}, {"value", "123"}], []},
                  {"input", [{"id", "form_foo"}, {"name", "user[foo]"}, {"type", "text"}], []},
                  "\n  [name: \"can't be blank\"]\n\n"
                ]}
             ] = html
    end
  end

  test "assigns_to_attributes/2" do
    assert assigns_to_attributes(%{}) == []
    assert assigns_to_attributes(%{}, [:non_exists]) == []
    assert assigns_to_attributes(%{one: 1, two: 2}) == [one: 1, two: 2]
    assert assigns_to_attributes(%{one: 1, two: 2}, [:one]) == [two: 2]
    assert assigns_to_attributes(%{__changed__: %{}, one: 1, two: 2}, [:one]) == [two: 2]
    assert assigns_to_attributes(%{__changed__: %{}, inner_block: fn -> :ok end, a: 1}) == [a: 1]
    assert assigns_to_attributes(%{__slot__: :foo, inner_block: fn -> :ok end, a: 1}) == [a: 1]
  end
end
