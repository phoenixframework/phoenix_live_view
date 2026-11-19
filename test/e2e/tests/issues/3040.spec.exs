defmodule Phoenix.LiveViewTest.E2E.Issue3040Test do
  use Phoenix.LiveViewTest.E2E.Case

  test "click-away does not fire when triggering form submit", %{page: page} do
    Page.goto!(page, "/issues/3040")
    sync_lv(page)

    page |> Page.get_by_role(:link, name: "Add new") |> Locator.click!()
    sync_lv(page)

    modal = Page.locator(page, "#my-modal-container")
    Expect.to_be_visible!(modal)

    # focusFirst should have focused the input
    page |> Page.locator("input[name='name']") |> Expect.to_be_focused!()

    # submit the form
    page |> Page.keyboard() |> Keyboard.press!("Enter")
    sync_lv(page)

    page |> Page.locator("form") |> Expect.to_have_text!("Form was submitted!")
    Expect.to_be_visible!(modal)

    # now click outside
    page |> Page.mouse() |> Mouse.click!(0, 0)
    sync_lv(page)

    Expect.to_be_hidden!(modal)
  end

  # see also https://github.com/phoenixframework/phoenix_live_view/issues/1920
  test "does not close modal when moving mouse outside while held down", %{page: page} do
    Page.goto!(page, "/issues/3040")
    sync_lv(page)

    page |> Page.get_by_role(:link, name: "Add new") |> Locator.click!()
    sync_lv(page)

    modal = Page.locator(page, "#my-modal-container")
    Expect.to_be_visible!(modal)

    page |> Page.locator("input[name='name']") |> Expect.to_be_focused!()
    page |> Page.locator("input[name='name']") |> Locator.fill!("test")

    # we move the mouse inside the input field and then drag it outside
    # while holding the mouse button down
    page |> Page.mouse() |> Mouse.move!(434, 350)
    page |> Page.mouse() |> Mouse.down!()
    page |> Page.mouse() |> Mouse.move!(143, 350)
    page |> Page.mouse() |> Mouse.up!()

    # we expect the modal to still be visible because the mousedown happened
    # inside, not triggering phx-click-away
    Expect.to_be_visible!(modal)
    page |> Page.keyboard() |> Keyboard.press!("Backspace")

    page |> Page.locator("input[name='name']") |> Expect.to_have_value!("")
    Expect.to_be_visible!(modal)

    # close modal with escape
    page |> Page.keyboard() |> Keyboard.press!("Escape")
    Expect.to_be_hidden!(modal)
  end
end
