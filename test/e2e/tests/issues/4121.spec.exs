defmodule Phoenix.LiveViewTest.E2E.Issue4121Test do
  use Phoenix.LiveViewTest.E2E.Case

  # https://github.com/phoenixframework/phoenix_live_view/issues/4121
  test "stream teleported outside of LiveView can be reset", %{page: page} do
    Page.goto!(page, "/issues/4121")
    sync_lv(page)

    assert stream_elements(page, "stream-in-lv") == [
             %{
               "id" => "items-1",
               "text" => "Item 1"
             },
             %{"id" => "items-2", "text" => "Item 2"}
           ]

    page |> Page.locator("button") |> Locator.click!()
    sync_lv(page)

    assert length(stream_elements(page, "stream-in-lv")) == 1
  end

  defp stream_elements(page, parent) do
    page
    |> Page.locator("##{parent} > *")
    |> Locator.evaluate_all!("""
    (list) =>
      list.map((el) => ({
        id: el.id,
        text: el.childNodes[0].nodeValue.trim(),
      }))
    """)
  end
end
