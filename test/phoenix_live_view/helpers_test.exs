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
  end

  describe "live_redirect" do
    test "single arity" do
      dom =
        live_redirect(to: "/", do: "text")
        |> safe_to_string()

      assert dom =~ ~s|data-phx-link="redirect"|
      assert dom =~ ~s|data-phx-link-state="push"|
      assert dom =~ ~s|text</a>|
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
        live_redirect("next", to: "page-1", href: "page-2", data: [phx_link: "other"], replace: true)
        |> safe_to_string()

      assert dom =~ ~s|href="page-1"|
      refute dom =~ ~s|href="page-2"|
      assert dom =~ ~s|data-phx-link="redirect"|
      assert dom =~ ~s|data-phx-link-state="replace"|
      refute dom =~ ~s|data-phx-link="other"|
    end
  end
end
