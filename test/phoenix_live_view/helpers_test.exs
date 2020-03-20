defmodule Phoenix.LiveView.HelpersTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveView.Helpers
  import Phoenix.HTML

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
end
