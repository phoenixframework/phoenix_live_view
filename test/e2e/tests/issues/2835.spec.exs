defmodule Phoenix.LiveViewTest.E2E.Issue2835Test do
  use Phoenix.LiveViewTest.E2E.Case

  defp file(name) do
    %{name: name, mimeType: "text/plain", buffer: name}
  end

  defp upload_state(page) do
    %{
      uploaded:
        page |> Page.locator("#uploaded-files li") |> Locator.all_text_contents!() |> Enum.sort(),
      pending:
        page
        |> Page.locator(".upload-entry")
        |> Locator.all_text_contents!()
        |> Enum.map(fn text -> text |> String.split(":") |> hd() |> String.trim() end)
        |> Enum.sort(),
      errors:
        page
        |> Page.locator(".upload-error")
        |> Locator.all_text_contents!()
        |> Enum.map(fn text -> String.trim(text) end)
    }
  end

  # https://github.com/phoenixframework/phoenix_live_view/issues/2835
  test "max_entries total mode includes files consumed by an auto upload", %{page: page} do
    Page.goto!(page, "/issues/2835")
    sync_lv(page)

    input = Page.locator(page, "#upload-form input[type='file']")

    Locator.set_input_files!(input, [
      file("first.txt"),
      file("second.txt"),
      file("third.txt")
    ])

    sync_lv(page)
    after_initial_selection = upload_state(page)

    Locator.set_input_files!(input, file("fourth.txt"))
    sync_lv(page)
    after_additional_selection = upload_state(page)

    assert %{
             after_initial_selection: after_initial_selection,
             after_additional_selection: after_additional_selection
           } == %{
             after_initial_selection: %{
               uploaded: ["first.txt", "second.txt"],
               pending: ["third.txt"],
               errors: [":too_many_files"]
             },
             after_additional_selection: %{
               uploaded: ["first.txt", "second.txt"],
               pending: ["fourth.txt", "third.txt"],
               errors: [":too_many_files"]
             }
           }
  end
end
