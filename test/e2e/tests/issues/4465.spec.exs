defmodule Phoenix.LiveViewTest.E2E.Issue4465Test do
  use Phoenix.LiveViewTest.E2E.Case

  # https://github.com/phoenixframework/phoenix_live_view/pull/4465

  defp file(name, contents) do
    %{
      name: name,
      mimeType: "text/plain",
      buffer: contents
    }
  end

  # not `setup/2`, which would clash with ExUnit's imported macro
  defp setup_page(page, query) do
    Page.goto!(page, "/issues/4465?#{query}")
    sync_lv(page)
    form = Page.locator(page, "#upload-form")

    %{
      # used to ensure that the form is not only released because the LiveView remounted
      pid: page |> Page.locator("#pid") |> Locator.text_content!(),
      form: form,
      input: Locator.locator(form, "input[type='file']"),
      submit: Locator.get_by_role(form, :button, name: "Submit")
    }
  end

  defp expect_unlocked(%{form: form, input: input, submit: submit}) do
    form |> Expect.not_() |> Expect.to_have_class!(~r/phx-submit-loading/)
    Expect.to_be_enabled!(submit)
    submit |> Expect.not_() |> Expect.to_have_attribute!("data-phx-ref-lock")
    Expect.to_be_enabled!(input)
    input |> Expect.not_() |> Expect.to_have_attribute!("data-phx-ref-lock")
  end

  defp cancel_and_resubmit(page, %{input: input, submit: submit, pid: pid}) do
    page
    |> Page.locator(~s(.upload-entry[data-name="bad.txt"]))
    |> Locator.get_by_role(:button, name: "Cancel")
    |> Locator.click!()

    sync_lv(page)
    Locator.set_input_files!(input, [file("good2.txt", "0000000000")])
    Locator.click!(submit)
    page |> Page.locator("#submitted") |> Expect.to_contain_text!("good2.txt")
    page |> Page.locator("#pid") |> Expect.to_have_text!(pid)
  end

  describe "external uploader calling entry.error()" do
    # the files as {name, contents}: `file/2` is not callable at compile time
    for files <- [
          [{"bad.txt", "0000000000"}],
          [{"good.txt", "0000000000"}, {"bad.txt", "0000000000"}]
        ] do
      test "releases the submit lock (#{Enum.map_join(files, ", ", &elem(&1, 0))})", %{
        page: page
      } do
        ctx = setup_page(page, "uploader=external")

        Locator.set_input_files!(
          ctx.input,
          Enum.map(unquote(files), fn {name, contents} -> file(name, contents) end)
        )

        Locator.click!(ctx.submit)
        # locked while the external uploader is running
        Expect.to_have_class!(ctx.form, ~r/phx-submit-loading/)
        Expect.to_be_disabled!(ctx.submit)

        expect_unlocked(ctx)
        page |> Page.locator("#submitted") |> Expect.to_have_text!("submitted: nil")

        page
        |> Page.locator(~s(.upload-entry[data-name="bad.txt"] .upload-error))
        |> Expect.to_have_text!(":external_client_failure")

        cancel_and_resubmit(page, ctx)
      end
    end

    test "auto upload: a submit scheduled during upload is released", %{page: page} do
      ctx = setup_page(page, "uploader=external&auto=true")
      Locator.set_input_files!(ctx.input, [file("bad.txt", "0000000000")])
      Locator.click!(ctx.submit)

      expect_unlocked(ctx)
      page |> Page.locator("#submitted") |> Expect.to_have_text!("submitted: nil")
      page |> Page.locator("#pid") |> Expect.to_have_text!(ctx.pid)
    end
  end

  test "channel uploader: writer error releases the submit lock", %{page: page} do
    ctx = setup_page(page, "uploader=channel")
    Locator.set_input_files!(ctx.input, [file("bad.txt", "error")])
    Locator.click!(ctx.submit)

    expect_unlocked(ctx)

    page
    |> Page.locator(~s(.upload-entry[data-name="bad.txt"] .upload-error))
    |> Expect.to_have_text!("{:writer_failure, :boom}")

    page |> Page.locator("#submitted") |> Expect.to_have_text!("submitted: nil")

    cancel_and_resubmit(page, ctx)
  end
end
