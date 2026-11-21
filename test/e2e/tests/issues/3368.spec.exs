defmodule Phoenix.LiveViewTest.E2E.Issue3368Test do
  use Phoenix.LiveViewTest.E2E.Case

  defp drop_files(page, names) do
    data_transfer =
      Page.evaluate_handle!(
        page,
        """
        (fileNames) => {
          const dt = new DataTransfer();
          fileNames.forEach((name) => {
            dt.items.add(new File([name], name, { type: "image/png" }));
          });
          return dt;
        }
        """,
        names
      )

    Page.dispatch_event!(page, "#dropzone", "drop", %{dataTransfer: data_transfer})
    Playwright.JSHandle.dispose!(data_transfer)
    sync_lv(page)
  end

  # https://github.com/phoenixframework/phoenix_live_view/issues/3368
  test "a new drop replaces entries after too_many_files", %{page: page} do
    Page.goto!(page, "/issues/3368")
    sync_lv(page)

    drop_files(page, ["first.png", "second.png"])
    page |> Page.locator(".upload-error") |> Expect.to_have_text!(":too_many_files")

    drop_files(page, ["replacement.png"])

    page |> Page.locator(".upload-error") |> Expect.to_have_count!(0)
    page |> Page.locator(".upload-entry") |> Expect.to_have_text!("replacement.png")
  end
end
