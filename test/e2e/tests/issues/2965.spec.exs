defmodule Phoenix.LiveViewTest.E2E.Issue2965Test do
  use Phoenix.LiveViewTest.E2E.Case

  test "can upload files with custom chunk hook", %{page: page} do
    Page.goto!(page, "/issues/2965")
    sync_lv(page)

    files =
      for i <- 1..20 do
        %{
          name: "file#{i}.txt",
          mimeType: "text/plain",
          # random 100 kb
          buffer: :crypto.strong_rand_bytes(100 * 1024)
        }
      end

    page |> Page.locator("#fileinput") |> Locator.set_input_files!(files)
    sync_lv(page)

    # wait for uploads to finish
    for i <- 0..19 do
      row = page |> Page.locator("tbody tr") |> Locator.nth(i)
      Expect.to_contain_text!(row, "file#{i + 1}.txt")
      row |> Locator.locator("progress") |> Expect.to_have_attribute!("value", "100")
    end

    # all uploads are finished!
  end
end
