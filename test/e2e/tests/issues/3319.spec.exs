defmodule Phoenix.LiveViewTest.E2E.Issue3319Test do
  use Phoenix.LiveViewTest.E2E.Case

  # https://github.com/phoenixframework/phoenix_live_view/issues/3319
  test "required upload with multiple entries can be submitted", %{page: page} do
    Page.goto!(page, "/issues/3319")
    sync_lv(page)

    form = Page.locator(page, "#upload-form")
    input = Locator.locator(form, "input[type='file']")

    Locator.set_input_files!(input, [
      %{name: "first.txt", mimeType: "text/plain", buffer: "first"},
      %{name: "second.txt", mimeType: "text/plain", buffer: "second"}
    ])

    sync_lv(page)

    form |> Locator.locator(".upload-entry") |> Expect.to_have_count!(2)
    form |> Locator.get_by_role(:button, name: "Submit") |> Locator.click!()
    page |> Page.locator("#submitted") |> Expect.not_() |> Expect.to_be_empty!()

    assert page
           |> Page.locator("#submitted")
           |> Locator.text_content!()
           |> String.split(",")
           |> Enum.sort() == ["first.txt", "second.txt"]
  end
end
