defmodule Phoenix.LiveViewTest.E2E.Issue4102Test do
  use Phoenix.LiveViewTest.E2E.Case

  # https://github.com/phoenixframework/phoenix_live_view/issues/4102
  test "debounce works for inputs outside of the form", %{page: page} do
    errors = array()

    Page.on(page, :page_error, fn err ->
      push(errors, err)
    end)

    Page.goto!(page, "/issues/4102")
    sync_lv(page)

    page |> Page.locator("input") |> Locator.fill!("123")
    page |> Page.locator("button") |> Locator.click!()
    sync_lv(page)

    assert length(values(errors)) == 0
  end
end
