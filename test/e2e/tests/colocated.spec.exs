defmodule Phoenix.LiveViewTest.E2E.ColocatedTest do
  use Phoenix.LiveViewTest.E2E.Case

  test "colocated hooks works", %{page: page} do
    Page.goto!(page, "/colocated")
    sync_lv(page)

    page |> Page.locator("input") |> Locator.fill!("1234567890")
    page |> Page.keyboard() |> Keyboard.press!("Enter")
    # the hook formats the phone number with dashes, so if the dashes
    # are there, the hook works!
    page |> Page.locator("#phone") |> Expect.to_have_text!("123-456-7890")

    # test runtime hook
    page |> Page.locator("#runtime") |> Expect.to_be_visible!()
  end

  test "colocated JS works", %{page: page} do
    # our colocated JS provides a window event handler for executing JS commands
    # from the server; we have a button that triggers a toggle server side
    Page.goto!(page, "/colocated")
    sync_lv(page)

    page |> Page.locator("#hello") |> Expect.to_be_visible!()

    page |> Page.locator("button") |> Locator.click!()
    page |> Page.locator("#hello") |> Expect.to_be_hidden!()

    page |> Page.locator("button") |> Locator.click!()
    page |> Page.locator("#hello") |> Expect.to_be_visible!()
  end

  test "custom macro component works (syntax highlighting)", %{page: page} do
    Page.goto!(page, "/colocated")
    sync_lv(page)
    # we check if the code has the makeup classes
    page
    |> Page.locator("pre")
    |> Locator.nth(1)
    |> Locator.get_by_text("button")
    |> Locator.first()
    |> Expect.to_have_class!("nt")

    page
    |> Page.locator("pre")
    |> Locator.nth(1)
    |> Locator.get_by_text("@temperature")
    |> Expect.to_have_class!("na")
  end

  test "global colocated css works", %{page: page} do
    Page.goto!(page, "/colocated")
    sync_lv(page)

    page
    |> Page.locator(~s([data-test="global"]))
    |> Expect.to_have_css!("background-color", "rgb(255, 0, 0)")
  end

  # TODO: revisit when
  # https://bugzilla.mozilla.org/show_bug.cgi?id=1980526
  # https://bugzilla.mozilla.org/show_bug.cgi?id=1914188
  # are fixed.
  test "scoped colocated css works", %{page: page, browser_name: browser_name} do
    # Currently broken
    if browser_name != :firefox do
      Page.goto!(page, "/colocated")
      sync_lv(page)

      page
      |> Page.locator(~s([data-test="scoped"]))
      |> Expect.to_have_css!("background-color", "rgba(0, 0, 0, 0)")

      blue_locator = Page.locator(page, ~s([data-test-scoped="blue"]))

      Expect.to_have_count!(blue_locator, 6)

      for should_be_blue <- Locator.all!(blue_locator) do
        Expect.to_have_css!(should_be_blue, "background-color", "rgb(0, 0, 255)")
      end

      none_locator = Page.locator(page, ~s([data-test-scoped="none"]))

      Expect.to_have_count!(none_locator, 5)

      for should_be_transparent <- Locator.all!(none_locator) do
        Expect.to_have_css!(should_be_transparent, "background-color", "rgba(0, 0, 0, 0)")
      end

      page
      |> Page.locator(~s([data-test-scoped="yellow"]))
      |> Expect.to_have_css!("background-color", "rgb(255, 255, 0)")

      page
      |> Page.locator(~s([data-test-scoped="green"]))
      |> Expect.to_have_css!("background-color", "rgb(0, 255, 0)")
    end
  end

  # TODO: revisit when
  # https://bugzilla.mozilla.org/show_bug.cgi?id=1980526
  # https://bugzilla.mozilla.org/show_bug.cgi?id=1914188
  # are fixed.
  test "scoped colocated css lower bound inclusive/exclusive works", %{
    page: page,
    browser_name: browser_name
  } do
    # Currently broken
    if browser_name != :firefox do
      Page.goto!(page, "/colocated")
      sync_lv(page)

      lower_bound_container_locator = Page.locator(page, "[data-test-lower-bound-container]")

      Expect.to_have_count!(lower_bound_container_locator, 2)

      for should_be_flex <- Locator.all!(lower_bound_container_locator) do
        Expect.to_have_css!(should_be_flex, "display", "flex")
      end

      inclusive_flex_items_locator = Page.locator(page, ~s([data-test-inclusive="yes"]))

      Expect.to_have_count!(inclusive_flex_items_locator, 3)

      for should_flex <- Locator.all!(inclusive_flex_items_locator) do
        Expect.to_have_css!(should_flex, "flex", "1 1 0%")
      end

      exclusive_flex_items_locator = Page.locator(page, ~s([data-test-inclusive="no"]))

      Expect.to_have_count!(exclusive_flex_items_locator, 3)

      for shouldnt_flex <- Locator.all!(exclusive_flex_items_locator) do
        Expect.to_have_css!(shouldnt_flex, "flex", "0 1 auto")
      end
    end
  end
end
