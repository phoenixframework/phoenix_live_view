defmodule Phoenix.LiveViewTest.E2E.Issue4027Test do
  use Phoenix.LiveViewTest.E2E.Case

  # https://github.com/phoenixframework/phoenix_live_view/issues/4027
  for c <- ["first", "second"] do
    test "keyed comprehensions are merged properly in LiveComponents - case #{c}", %{page: page} do
      errors = array()
      Page.on(page, :page_error, fn err -> push(errors, err) end)
      Page.goto!(page, "/issues/4027?case=#{unquote(c)}")
      sync_lv(page)

      page |> Page.get_by_role(:button, name: "Load data") |> Locator.click!()
      page |> Page.locator("#result p") |> Expect.to_have_count!(3)

      page |> Page.get_by_role(:button, name: "Remove first entry") |> Locator.click!()
      page |> Page.locator("#result p") |> Expect.to_have_count!(2)

      page |> Page.locator("#result") |> Expect.not_() |> Expect.to_contain_text!("First")
      page |> Page.locator("#result") |> Expect.to_contain_text!("Second")
      page |> Page.locator("#result") |> Expect.to_contain_text!("Third")

      assert values(errors) == []
    end
  end
end
