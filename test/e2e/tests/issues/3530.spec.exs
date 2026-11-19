defmodule Phoenix.LiveViewTest.E2E.Issue3530Test do
  use Phoenix.LiveViewTest.E2E.Case

  # https://github.com/phoenixframework/phoenix_live_view/issues/3530
  test "hook is initialized properly when using a stream of nested LiveViews", %{page: page} do
    logs = array()
    Page.on(page, :console, fn e -> push(logs, ConsoleMessage.text(e)) end)
    errors = array()
    Page.on(page, :page_error, fn err -> push(errors, err) end)

    Page.goto!(page, "/issues/3530")
    sync_lv(page)

    assert values(errors) == []

    assert logs |> values() |> Enum.filter(&String.contains?(&1, "item-1 mounted")) |> length() ==
             1

    assert logs |> values() |> Enum.filter(&String.contains?(&1, "item-2 mounted")) |> length() ==
             1

    assert logs |> values() |> Enum.filter(&String.contains?(&1, "item-3 mounted")) |> length() ==
             1

    clear(logs)

    page |> Page.get_by_role(:link, name: "patch a") |> Locator.click!()
    sync_lv(page)

    assert values(errors) == []

    assert logs |> values() |> Enum.filter(&String.contains?(&1, "item-2 destroyed")) |> length() ==
             1

    assert logs |> values() |> Enum.filter(&String.contains?(&1, "item-1 destroyed")) |> length() ==
             0

    assert logs |> values() |> Enum.filter(&String.contains?(&1, "item-3 destroyed")) |> length() ==
             0

    clear(logs)

    page |> Page.get_by_role(:link, name: "patch b") |> Locator.click!()
    sync_lv(page)

    assert values(errors) == []

    assert logs |> values() |> Enum.filter(&String.contains?(&1, "item-1 destroyed")) |> length() ==
             1

    assert logs |> values() |> Enum.filter(&String.contains?(&1, "item-2 destroyed")) |> length() ==
             0

    assert logs |> values() |> Enum.filter(&String.contains?(&1, "item-3 destroyed")) |> length() ==
             0

    assert logs |> values() |> Enum.filter(&String.contains?(&1, "item-2 mounted")) |> length() ==
             1

    clear(logs)

    page |> Page.locator("div[phx-click=inc]") |> Locator.click!()
    sync_lv(page)

    assert logs |> values() |> Enum.filter(&String.contains?(&1, "item-4 mounted")) |> length() ==
             1

    refute_equal(
      values(logs),
      array_containing([string_matching("no hook found for custom element")])
    )

    # no uncaught exceptions
    assert values(errors) == []
  end
end
