defmodule Phoenix.LiveViewTest.E2E.Issue4078Test do
  use Phoenix.LiveViewTest.E2E.Case

  # https://github.com/phoenixframework/phoenix_live_view/issues/4078
  # live_file_input should respect changing assigns like disabled and class

  test "live_file_input respects disabled attribute changes", %{page: page} do
    Page.goto!(page, "/issues/4078")
    sync_lv(page)

    input = Page.locator(page, "#upload-form input[type='file']")

    # Initially disabled
    Expect.to_be_disabled!(input)
    Expect.to_have_attribute!(input, "data-phx-user-disabled")

    # Click to enable
    page |> Page.locator("#toggle-disabled") |> Locator.click!()
    sync_lv(page)

    # Should now be enabled
    input |> Expect.not_() |> Expect.to_be_disabled!()
    input |> Expect.not_() |> Expect.to_have_attribute!("data-phx-user-disabled")

    # A later patch must not restore the server-rendered disabled attribute.
    page |> Page.locator("#toggle-class") |> Locator.click!()
    sync_lv(page)
    Expect.to_be_enabled!(input)

    # Click to disable again
    page |> Page.locator("#toggle-disabled") |> Locator.click!()
    sync_lv(page)

    # Should be disabled again
    Expect.to_be_disabled!(input)
    Expect.to_have_attribute!(input, "data-phx-user-disabled")
  end

  test "live_file_input respects class attribute changes", %{page: page} do
    Page.goto!(page, "/issues/4078")
    sync_lv(page)

    input = Page.locator(page, "#upload-form input[type='file']")

    # Initially has initial-class
    Expect.to_have_class!(input, ~r/initial-class/)

    # Click to change class
    page |> Page.locator("#toggle-class") |> Locator.click!()
    sync_lv(page)

    # Should have updated-class
    Expect.to_have_class!(input, ~r/updated-class/)

    # Click to change class back
    page |> Page.locator("#toggle-class") |> Locator.click!()
    sync_lv(page)

    # Should have initial-class again
    Expect.to_have_class!(input, ~r/initial-class/)
  end

  test "live_file_input preserves files when attributes change", %{page: page} do
    Page.goto!(page, "/issues/4078")
    sync_lv(page)

    # First enable the input
    page |> Page.locator("#toggle-disabled") |> Locator.click!()
    sync_lv(page)

    input = Page.locator(page, "#upload-form input[type='file']")
    input |> Expect.not_() |> Expect.to_be_disabled!()

    # Select a file
    Locator.set_input_files!(input, %{
      name: "test.txt",
      mimeType: "text/plain",
      buffer: "test content"
    })

    sync_lv(page)

    # Verify file is selected (entry should appear)
    page |> Page.locator(".upload-entry") |> Expect.to_be_visible!()
    page |> Page.locator(".entry-name") |> Expect.to_contain_text!("test.txt")

    # Change class attribute - file should remain selected
    page |> Page.locator("#toggle-class") |> Locator.click!()
    sync_lv(page)

    # Verify file is still selected after class change
    page |> Page.locator(".upload-entry") |> Expect.to_be_visible!()
    page |> Page.locator(".entry-name") |> Expect.to_contain_text!("test.txt")

    # Verify class was changed
    Expect.to_have_class!(input, ~r/updated-class/)
  end
end
