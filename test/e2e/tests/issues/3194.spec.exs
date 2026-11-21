defmodule Phoenix.LiveViewTest.E2E.Issue3194Test do
  use Phoenix.LiveViewTest.E2E.Case

  test "does not send event to wrong LV when submitting form with debounce blur", %{page: page} do
    logs = array()
    Page.on(page, :console, fn e -> push(logs, ConsoleMessage.text(e)) end)

    Page.goto!(page, "/issues/3194")
    sync_lv(page)

    page |> Page.locator("input") |> Locator.focus!()
    page |> Page.keyboard() |> Keyboard.type!("hello")
    page |> Page.keyboard() |> Keyboard.press!("Enter")
    Expect.to_have_url!(page, "/issues/3194/other")

    # give it some time for old events to reach the new LV
    # (this is the failure case!)
    Page.wait_for_timeout!(page, 50)

    # we navigated to another LV
    assert Enum.any?(
             values(logs),
             &(&1 =~ ~r/destroyed: the child has been removed from the parent/)
           )

    # it should not have crashed
    refute Enum.any?(values(logs), &(&1 =~ ~r/view crashed/))
  end
end
