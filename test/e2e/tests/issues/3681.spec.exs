defmodule Phoenix.LiveViewTest.E2E.Issue3681Test do
  use Phoenix.LiveViewTest.E2E.Case

  # https://github.com/phoenixframework/phoenix_live_view/issues/3681
  @tag :request
  test "streams in nested LiveViews are not reset when they share the same stream ref",
       %{page: page, request: request} do
    # this was a separate bug where child LiveViews accidentally shared the parent streams
    # check that the initial render does not contain the messages-4 element twice
    assert request
           |> APIRequestContext.get!("/issues/3681/away")
           |> APIResponse.text!()
           |> then(&Regex.scan(~r/messages-4/, &1))
           |> length() == 1

    Page.goto!(page, "/issues/3681")
    sync_lv(page)

    page |> Page.locator("#msgs-sticky > div") |> Expect.to_have_count!(3)

    page
    |> Page.get_by_role(:link, name: "Go to a different LV with a (funcky) stream")
    |> Locator.click!()

    sync_lv(page)
    page |> Page.locator("#msgs-sticky > div") |> Expect.to_have_count!(3)

    page
    |> Page.get_by_role(:link, name: "Go back to (the now borked) LV without a stream")
    |> Locator.click!()

    sync_lv(page)
    page |> Page.locator("#msgs-sticky > div") |> Expect.to_have_count!(3)
  end
end
