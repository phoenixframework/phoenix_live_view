defmodule Phoenix.LiveViewTest.E2E.PortalTest do
  use Phoenix.LiveViewTest.E2E.Case

  test "renders modal inside portal location", %{page: page} do
    Page.goto!(page, "/portal?tick=false")
    sync_lv(page)

    page |> Page.locator("#my-modal") |> Expect.to_have_count!(1)
    page |> Page.locator("#my-modal-content") |> Expect.to_be_hidden!()
    # no modal inside the main element (rendered in the layout)
    page |> Page.locator("main #my-modal") |> Expect.to_have_count!(0)

    page |> Page.get_by_role(:button, name: "Open modal") |> Locator.click!()
    page |> Page.locator("#my-modal-content") |> Expect.to_be_visible!()

    page
    |> Page.locator("#my-modal-content")
    |> Expect.to_contain_text!("DOM patching works as expected: 0")

    eval_lv(page, "send(self(), :tick)")

    page
    |> Page.locator("#my-modal-content")
    |> Expect.to_contain_text!("DOM patching works as expected: 1")
  end

  test "teleported element is removed properly", %{page: page} do
    Page.goto!(page, "/portal?tick=false")
    sync_lv(page)

    page |> Page.locator("[data-phx-teleported-src=portal-source]") |> Expect.to_have_count!(1)
    page |> Page.get_by_role(:button, name: "Toggle modal render") |> Locator.click!()
    page |> Page.locator("[data-phx-teleported-src=portal-source]") |> Expect.to_have_count!(0)
    page |> Page.locator("#my-modal") |> Expect.to_have_count!(0)

    # other modal still exists
    page |> Page.locator("[data-phx-teleported-src=portal-source-2]") |> Expect.to_have_count!(1)

    # now toggle it again
    page |> Page.get_by_role(:button, name: "Toggle modal render") |> Locator.click!()
    page |> Page.locator("[data-phx-teleported-src=portal-source]") |> Expect.to_have_count!(1)

    # now navigate to another page
    page |> Page.get_by_role(:button, name: "Live navigate") |> Locator.click!()
    sync_lv(page)
    # all teleported elements should be gone
    page |> Page.locator("[data-phx-teleported-src]") |> Expect.to_have_count!(0)
  end

  test "events are routed to correct LiveView", %{page: page} do
    Page.goto!(page, "/portal?tick=false")
    sync_lv(page)

    page |> Page.locator("#nested-event-count") |> Expect.to_have_text!("0")

    page
    |> Page.get_by_role(:button, name: "Trigger event in nested LV", exact: true)
    |> Locator.click!()

    page |> Page.locator("#nested-event-count") |> Expect.to_have_text!("1")

    page
    |> Page.get_by_role(:button, name: "Trigger event in nested LV (from teleported button)")
    |> Locator.click!()

    page |> Page.locator("#nested-event-count") |> Expect.to_have_text!("2")
  end

  test "streams work in teleported LiveComponent", %{page: page} do
    Page.goto!(page, "/portal?tick=false")
    sync_lv(page)

    assert Page.evaluate!(page, "() => document.querySelector('#stream-in-lc').children.length") ==
             2

    page |> Page.get_by_role(:button, name: "Prepend item", exact: true) |> Locator.click!()
    sync_lv(page)

    assert Page.evaluate!(page, "() => document.querySelector('#stream-in-lc').children.length") ==
             3

    # https://github.com/phoenixframework/phoenix_live_view/issues/4101
    # teleporting outside of live component works too
    page
    |> Page.get_by_role(:button, name: "Prepend item (teleported)", exact: true)
    |> Locator.click!()

    sync_lv(page)

    assert Page.evaluate!(page, "() => document.querySelector('#stream-in-lc').children.length") ==
             4
  end

  describe "tooltip" do
    # The tooltip sometimes causes a
    # ResizeObserver loop completed with undelivered notifications
    # error, which is safe to ignore.
    @describetag ignore_js_errors: true
    test "tooltip example", %{page: page} do
      Page.goto!(page, "/portal?tick=false")
      sync_lv(page)

      page |> Page.locator("#tooltip-example-portal") |> Expect.to_be_hidden!()
      page |> Page.locator("#tooltip-example-no-portal") |> Expect.to_be_hidden!()

      page |> Page.get_by_role(:button, name: "Hover me", exact: true) |> Locator.hover!()
      page |> Page.locator("#tooltip-example-portal") |> Expect.to_be_visible!()
      page |> Page.locator("#tooltip-example-no-portal") |> Expect.to_be_hidden!()

      page |> Page.get_by_role(:button, name: "Hover me (no portal)") |> Locator.hover!()
      page |> Page.locator("#tooltip-example-portal") |> Expect.to_be_hidden!()
      page |> Page.locator("#tooltip-example-no-portal") |> Expect.to_be_visible!()
    end
  end

  test "teleported hook works correctly", %{page: page} do
    # https://github.com/phoenixframework/phoenix_live_view/issues/3950
    Page.goto!(page, "/portal?tick=false")
    sync_lv(page)

    page
    |> Page.locator("#hook-test")
    |> Expect.to_have_attribute!("data-portalhook-mounted", "true")
  end

  test "nested portals render and work correctly", %{page: page} do
    Page.goto!(page, "/portal?tick=false")
    sync_lv(page)

    # Verify outer portal is teleported
    page
    |> Page.locator("[data-phx-teleported-src=nested-portal-source]")
    |> Expect.to_have_count!(1)

    page |> Page.locator("#outer-portal") |> Expect.to_have_count!(1)

    # Verify inner portal is teleported
    page
    |> Page.locator("[data-phx-teleported-src=inner-portal-source]")
    |> Expect.to_have_count!(1)

    page |> Page.locator("#inner-portal") |> Expect.to_have_count!(1)

    # Test that events work in nested portals
    page |> Page.locator("#nested-portal-count") |> Expect.to_have_text!("0")
    page |> Page.get_by_role(:button, name: "Click nested portal button") |> Locator.click!()
    page |> Page.locator("#nested-portal-count") |> Expect.to_have_text!("1")

    # Test DOM patching works in nested portals
    page |> Page.locator("#nested-portal-content") |> Expect.to_contain_text!("Tick count: 0")
    eval_lv(page, "send(self(), :tick)")
    page |> Page.locator("#nested-portal-content") |> Expect.to_contain_text!("Tick count: 1")
  end

  test "nested portals cleanup and re-render correctly", %{page: page} do
    Page.goto!(page, "/portal?tick=false")
    sync_lv(page)

    # Verify initial state
    page |> Page.locator("#outer-portal") |> Expect.to_have_count!(1)
    page |> Page.locator("#inner-portal") |> Expect.to_have_count!(1)

    # Toggle off - both portals should be removed
    page |> Page.get_by_role(:button, name: "Toggle nested portals") |> Locator.click!()

    page
    |> Page.locator("[data-phx-teleported-src=nested-portal-source]")
    |> Expect.to_have_count!(0)

    page
    |> Page.locator("[data-phx-teleported-src=inner-portal-source]")
    |> Expect.to_have_count!(0)

    page |> Page.locator("#outer-portal") |> Expect.to_have_count!(0)
    page |> Page.locator("#inner-portal") |> Expect.to_have_count!(0)

    # Toggle back on - both portals should reappear with correct nesting
    page |> Page.get_by_role(:button, name: "Toggle nested portals") |> Locator.click!()

    page
    |> Page.locator("[data-phx-teleported-src=nested-portal-source]")
    |> Expect.to_have_count!(1)

    page
    |> Page.locator("[data-phx-teleported-src=inner-portal-source]")
    |> Expect.to_have_count!(1)

    page |> Page.locator("#outer-portal") |> Expect.to_have_count!(1)
    page |> Page.locator("#inner-portal") |> Expect.to_have_count!(1)
  end

  test "click-away is portal aware", %{page: page} do
    Page.goto!(page, "/portal?tick=false")
    sync_lv(page)

    page |> Page.get_by_role(:button, name: "Open non-teleported modal") |> Locator.click!()
    page |> Page.locator("#non-teleported-modal-content") |> Expect.to_be_visible!()
    page |> Page.get_by_role(:button, name: "Open menu") |> Locator.click!()
    page |> Page.locator("#teleported-menu-content") |> Expect.to_be_visible!()
    page |> Page.get_by_role(:button, name: "Close menu") |> Locator.click!()
    page |> Page.locator("#teleported-menu-content") |> Expect.to_be_hidden!()

    # Modal must still be visible, despite click away
    page |> Page.locator("#non-teleported-modal-content") |> Expect.to_be_visible!()
    # trigger click-away
    page
    |> Page.locator("#non-teleported-modal .fixed[role='dialog']")
    |> Locator.click!(position: %{x: 0, y: 0})

    page |> Page.locator("#non-teleported-modal-content") |> Expect.to_be_hidden!()

    # Test that click-away also works properly for teleported modals
    page |> Page.get_by_role(:button, name: "Open modal") |> Locator.click!()
    page |> Page.locator("#my-modal-content") |> Expect.to_be_visible!()

    page
    |> Page.locator("#my-modal .fixed[role='dialog']")
    |> Locator.click!(position: %{x: 0, y: 0})

    page |> Page.locator("#my-modal-content") |> Expect.to_be_hidden!()

    # Test that visibility of the <template> element doesn't interfere with click-away
    page |> Page.get_by_role(:button, name: "Open second modal") |> Locator.click!()
    page |> Page.locator("#inner-red-box") |> Expect.to_be_visible!()
    page |> Page.locator("#my-modal-2 .bg-gray-300") |> Locator.click!()
    page |> Page.locator("#inner-red-box") |> Expect.to_be_hidden!()
  end
end
