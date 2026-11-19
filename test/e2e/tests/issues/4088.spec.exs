defmodule Phoenix.LiveViewTest.E2E.Issue4088Test do
  use Phoenix.LiveViewTest.E2E.Case

  # https://github.com/phoenixframework/phoenix_live_view/issues/4088
  test "locked LiveComponent container can be patched properly", %{page: page} do
    errors = array()

    Page.on(page, :page_error, fn err ->
      push(errors, err)
    end)

    Page.goto!(page, "/issues/4088")
    sync_lv(page)

    assert length(values(errors)) == 0
  end
end
