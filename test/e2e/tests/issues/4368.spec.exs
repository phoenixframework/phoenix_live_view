defmodule Phoenix.LiveViewTest.E2E.Issue4368Test do
  use Phoenix.LiveViewTest.E2E.Case

  # https://github.com/phoenixframework/phoenix_live_view/pull/4368
  test "a custom writer failure remains visible until it is cancelled", %{page: page} do
    Page.goto!(page, "/issues/4368")
    sync_lv(page)

    input = Page.locator(page, "#upload-form input[type='file']")

    Locator.set_input_files!(input, [
      %{
        name: "good.pdf",
        mimeType: "application/pdf",
        buffer: "0000000000"
      },
      %{
        name: "bad.pdf",
        mimeType: "application/pdf",
        buffer: "00000error"
      }
    ])

    failed_entry = Page.locator(page, ~s(.upload-entry[data-name="bad.pdf"]))

    failed_entry
    |> Locator.locator(".upload-error")
    |> Expect.to_have_text!("{:writer_failure, :invalid_pdf}")

    page |> Page.locator("#consumed") |> Expect.to_have_text!("consumed: good.pdf")
    page |> Page.locator("#submitted") |> Expect.to_have_text!("submitted: false")
    page |> Page.locator("[data-phx-main]") |> Expect.to_have_class!(~r/phx-connected/)

    failed_ref = Locator.get_attribute!(input, "data-phx-active-refs")
    refute failed_ref == ""
    Expect.to_have_attribute!(input, "data-phx-preflighted-refs", failed_ref)
    Expect.to_have_attribute!(input, "data-phx-done-refs", "")

    failed_entry |> Locator.get_by_role(:button, name: "Cancel") |> Locator.click!()
    Expect.to_have_count!(failed_entry, 0)
    sync_lv(page)

    page |> Page.get_by_role(:button, name: "Submit") |> Locator.click!()
    sync_lv(page)
    page |> Page.locator("#submitted") |> Expect.to_have_text!("submitted: true")
  end

  test "a custom writer failure cancels a submit scheduled during upload", %{page: page} do
    Page.goto!(page, "/issues/4368")
    sync_lv(page)

    form = Page.locator(page, "#upload-form")
    input = Locator.locator(form, "input[type='file']")
    submit = Locator.get_by_role(form, :button, name: "Submit")

    Locator.set_input_files!(input, %{
      name: "bad.pdf",
      mimeType: "application/pdf",
      buffer: "delayerror"
    })

    Locator.click!(submit)
    Expect.to_be_disabled!(submit)

    failed_entry = Page.locator(page, ~s(.upload-entry[data-name="bad.pdf"]))

    failed_entry
    |> Locator.locator(".upload-error")
    |> Expect.to_have_text!("{:writer_failure, :invalid_pdf}")

    page |> Page.locator("#submitted") |> Expect.to_have_text!("submitted: false")
    form |> Expect.not_() |> Expect.to_have_class!(~r/phx-submit-loading/)
    Expect.to_be_enabled!(input)
    input |> Expect.not_() |> Expect.to_have_attribute!("data-phx-ref-lock")
    Expect.to_be_enabled!(submit)
    submit |> Expect.not_() |> Expect.to_have_attribute!("data-phx-ref-lock")

    failed_entry |> Locator.get_by_role(:button, name: "Cancel") |> Locator.click!()
    Expect.to_have_count!(failed_entry, 0)

    Locator.click!(submit)
    page |> Page.locator("#submitted") |> Expect.to_have_text!("submitted: true")
  end
end
