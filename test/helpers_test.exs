defmodule Phoenix.LiveView.HelpersTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveView.Helpers
  import Phoenix.HTML

  describe "live_link" do
    test "forwards dom attribute options" do
      dom =
        live_link("next", to: "/", class: "btn btn-large", data: [page_number: 2])
        |> safe_to_string()

      assert dom =~ ~s|class="btn btn-large"|
      assert dom =~ ~s|data-page-number="2"|
    end

    test "overwrites reserved options" do
      dom =
        live_link("next", to: "page-1", href: "page-2", data: [phx_live_link: "other"])
        |> safe_to_string()

      assert dom =~ ~s|href="page-1"|
      refute dom =~ ~s|href="page-2"|
      assert dom =~ ~s|data-phx-live-link="push"|
      refute dom =~ ~s|data-phx-live-link="other"|
    end
  end
end
