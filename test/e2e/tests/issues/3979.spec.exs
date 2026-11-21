defmodule Phoenix.LiveViewTest.E2E.Issue3979Test do
  use Phoenix.LiveViewTest.E2E.Case

  # https://github.com/phoenixframework/phoenix_live_view/issues/3979
  test "components destroyed check works properly", %{page: page} do
    errors = array()
    Page.on(page, :page_error, fn err -> push(errors, err) end)

    Page.goto!(page, "/issues/3979")
    sync_lv(page)

    bump_btn = Page.get_by_role(page, :button, name: "Bump ID (and counter)")

    for _i <- 0..9 do
      Locator.click!(bump_btn)
      sync_lv(page)
    end

    for i <- 0..9 do
      page
      |> Page.locator(~s([data-phx-component="#{i + 1}"]))
      |> Expect.to_have_text!("10")
    end

    assert values(errors) == []
  end
end
