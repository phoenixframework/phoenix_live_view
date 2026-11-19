defmodule Phoenix.LiveViewTest.E2E.Issue3391Test do
  use Phoenix.LiveViewTest.E2E.Case

  # https://github.com/phoenixframework/phoenix_live_view/issues/3391
  test "an invalid auto-upload cancels submit without locking the form", %{page: page} do
    Page.goto!(page, "/issues/3391")
    sync_lv(page)

    form = Page.locator(page, "#upload-form")
    input = Locator.locator(form, "input[type='file']")
    submit = Locator.get_by_role(form, :button, name: "Submit")

    Locator.set_input_files!(input, %{
      name: "invalid.html",
      mimeType: "text/html",
      buffer: "<h1>invalid</h1>"
    })

    sync_lv(page)

    failed_entry = Locator.locator(form, ".upload-entry")
    failed_entry |> Locator.locator(".upload-error") |> Expect.to_have_text!(":not_accepted")

    Locator.click!(submit)

    form |> Expect.not_() |> Expect.to_have_class!(~r/phx-submit-loading/)
    Expect.to_be_enabled!(submit)
    failed_entry |> Locator.get_by_role(:button, name: "Cancel") |> Expect.to_be_enabled!()
    failed_entry |> Locator.locator(".upload-error") |> Expect.to_have_text!(":not_accepted")
    page |> Page.locator("#submitted") |> Expect.to_have_text!("submitted: false")

    failed_entry |> Locator.get_by_role(:button, name: "Cancel") |> Locator.click!()
    Expect.to_have_count!(failed_entry, 0)

    Locator.set_input_files!(input, %{
      name: "valid.txt",
      mimeType: "text/plain",
      buffer: "valid"
    })

    page |> Page.locator("#uploaded") |> Expect.to_have_text!("uploaded: true")

    Locator.click!(submit)
    page |> Page.locator("#submitted") |> Expect.to_have_text!("submitted: true")
  end
end
