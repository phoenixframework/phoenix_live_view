defmodule Phoenix.LiveViewTest.E2E.Issue3709Test do
  use Phoenix.LiveViewTest.E2E.Case

  # https://github.com/phoenixframework/phoenix_live_view/issues/3709
  test "pendingDiffs don't race with navigation", %{page: page} do
    logs = array()
    Page.on(page, :console, fn e -> push(logs, ConsoleMessage.text(e)) end)
    errors = array()
    Page.on(page, :page_error, fn err -> push(errors, err) end)

    Page.goto!(page, "/issues/3709/1")
    sync_lv(page)
    page |> Page.locator("body") |> Expect.to_contain_text!("id: 1")

    page |> Page.get_by_role(:button, name: "Break Stuff") |> Locator.click!()
    sync_lv(page)

    # expect.stringMatching(string) compiles the string as a RegExp
    refute Enum.any?(
             values(logs),
             &(&1 =~ ~r/Cannot read properties of undefined (reading 's')/)
           )

    page |> Page.get_by_role(:link, name: "Link 5") |> Locator.click!()
    sync_lv(page)
    page |> Page.locator("body") |> Expect.to_contain_text!("id: 5")

    refute Enum.any?(
             values(logs),
             &(&1 =~ ~r/Cannot set properties of undefined (setting 'newRender')/)
           )

    # no uncaught exceptions
    assert values(errors) == []
  end
end
