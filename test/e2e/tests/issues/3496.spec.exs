defmodule Phoenix.LiveViewTest.E2E.Issue3496Test do
  use Phoenix.LiveViewTest.E2E.Case

  # https://github.com/phoenixframework/phoenix_live_view/issues/3496
  test "hook is initialized properly when reusing id between sticky and non sticky LiveViews",
       %{page: page} do
    logs = array()
    Page.on(page, :console, fn e -> push(logs, ConsoleMessage.text(e)) end)
    errors = array()
    Page.on(page, :page_error, fn err -> push(errors, err) end)

    Page.goto!(page, "/issues/3496/a")
    sync_lv(page)

    page |> Page.get_by_role(:link, name: "Go to page B") |> Locator.click!()
    sync_lv(page)

    assert length(Enum.filter(values(logs), &String.contains?(&1, "Hook mounted!"))) ==
             2

    refute Enum.any?(
             values(logs),
             &(&1 =~ ~r/no hook found for custom element/)
           )

    # no uncaught exceptions
    assert values(errors) == []
  end
end
