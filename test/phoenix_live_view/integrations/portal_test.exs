defmodule Phoenix.LiveView.PortalTest do
  use ExUnit.Case, async: true

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Phoenix.LiveViewTest.Support.Endpoint

  @endpoint Endpoint

  setup do
    {:ok, conn: Plug.Test.init_test_session(build_conn(), %{})}
  end

  describe "portal component" do
    test "teleports content to target on initial render", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/portal")

      dbg(render(view))

      # Content should be accessible even though it's rendered in a portal
      assert has_element?(view, "#portal-content")
      assert has_element?(view, "#footer-content")

      # Main content should also be visible
      assert has_element?(view, "#main-content")
      assert has_element?(view, "h1", "Portal Test")

      # Portal content should have the correct text
      assert has_element?(view, "#portal-content h2", "Portal Content")
      assert has_element?(view, "#portal-content p", "This content is teleported to body")

      # Footer portal should be in the footer target
      assert has_element?(view, "#footer-content", "Footer content here (count: 0)")
    end

    test "portal content updates when state changes", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/portal")

      # Initial state
      assert has_element?(view, "#portal-content p", "Current count: 0")
      assert has_element?(view, "#footer-content", "Footer content here (count: 0)")

      # Click increment button
      view
      |> element("button", "Increment")
      |> render_click()

      # Portal content should update
      assert has_element?(view, "#portal-content p", "Current count: 1")
      assert has_element?(view, "#footer-content", "Footer content here (count: 1)")

      # Main content should also update
      assert has_element?(view, "p", "Count: 1")
    end

    test "portal content is properly replaced on re-render", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/portal")

      # Click increment multiple times
      view
      |> element("button", "Increment")
      |> render_click()

      view
      |> element("button", "Increment")
      |> render_click()

      # Should only have one instance of each portal content
      assert has_element?(view, "#portal-content p", "Current count: 2")

      # The content should be properly replaced, not duplicated
      html = render(view)

      # Count how many times the portal content ID appears
      portal_content_count =
        html
        |> String.split("id=\"portal-content\"")
        |> length()
        |> Kernel.-(1)

      footer_content_count =
        html
        |> String.split("id=\"footer-content\"")
        |> length()
        |> Kernel.-(1)

      # Each portal content should appear exactly twice:
      # once in the template and once in the teleported location
      assert portal_content_count == 2
      assert footer_content_count == 2
    end

    test "multiple portals with different targets work correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/portal")

      # Both portals should be accessible
      assert has_element?(view, "#portal-content")
      assert has_element?(view, "#footer-content")

      # Update state
      view
      |> element("button", "Increment")
      |> render_click()

      # Both should update
      assert has_element?(view, "#portal-content p", "Current count: 1")
      assert has_element?(view, "#footer-content", "Footer content here (count: 1)")
    end

    test "can interact with elements inside portals", %{conn: conn} do
      # Modify the LiveView to add a button inside the portal
      defmodule PortalWithButtonLive do
        use Phoenix.LiveView

        def mount(_params, _session, socket) do
          {:ok, assign(socket, :portal_clicks, 0)}
        end

        def render(assigns) do
          ~H"""
          <div>
            <p>Portal clicks: {@portal_clicks}</p>

            <.portal id="interactive-portal" target="#fakebody">
              <div id="portal-with-button">
                <button phx-click="portal_click">Click me in portal</button>
                <p>Clicked {@portal_clicks} times</p>
              </div>
            </.portal>
          </div>

          <div id="fakebody"></div>
          """
        end

        def handle_event("portal_click", _params, socket) do
          {:noreply, update(socket, :portal_clicks, &(&1 + 1))}
        end
      end

      # Register the test module temporarily
      {:ok, view, _html} =
        live_isolated(conn, PortalWithButtonLive)

      # Initial state
      assert has_element?(view, "p", "Portal clicks: 0")
      assert has_element?(view, "#portal-with-button p", "Clicked 0 times")

      # Click button inside portal
      view
      |> element("#portal-with-button button", "Click me in portal")
      |> render_click()

      # State should update
      assert has_element?(view, "p", "Portal clicks: 1")
      assert has_element?(view, "#portal-with-button p", "Clicked 1 times")
    end
  end
end
