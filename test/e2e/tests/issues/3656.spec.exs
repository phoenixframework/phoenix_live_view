defmodule Phoenix.LiveViewTest.E2E.Issue3656Test do
  use Phoenix.LiveViewTest.E2E.Case

  # https://github.com/phoenixframework/phoenix_live_view/issues/3656
  test "phx-click-loading is removed from links in sticky LiveViews", %{page: page} do
    Page.goto!(page, "/issues/3656")
    sync_lv(page)

    changes = attribute_mutations(page, "nav a")

    link = Page.get_by_role(page, :link, name: "Link 1")
    Locator.click!(link)

    sync_lv(page)
    link |> Expect.not_() |> Expect.to_have_class!("phx-click-loading")

    # expect.arrayContaining: every expected element is in the actual list
    # (evaluate returns string keys, and JS null as :null)
    mutations = changes.()

    for expected <- [
          %{"attr" => "class", "oldValue" => :null, "newValue" => "phx-click-loading"},
          %{"attr" => "class", "oldValue" => "phx-click-loading", "newValue" => ""}
        ] do
      assert expected in mutations
    end
  end
end
