defmodule Phoenix.LiveViewTest.E2E.Issue4444Test do
  use Phoenix.LiveViewTest.E2E.Case

  # A hook in the parent LiveView locks an element that contains a nested LiveView.
  # While the lock is active, the parent is patched (which creates the private
  # clone of the locked element) and a LiveComponent inside the nested LiveView
  # receives a component-only diff. That diff must not be redirected into the
  # parent's clone, as the unlock morph never descends into nested LiveViews.
  defp run_locked(page, variant) do
    Page.goto!(page, "/issues/4444?variant=#{variant}")
    sync_lv(page)
    page |> Page.locator("#child-lv") |> Expect.to_have_class!(~r/phx-connected/)
    page |> Page.locator("#child-component-label") |> Expect.to_have_text!("child 0")

    page |> Page.locator("#run") |> Locator.click!()

    page
    |> Page.locator("#locked")
    |> Expect.to_have_attribute!("data-phx-ref-lock", "1")

    page
    |> Page.locator("#locked")
    |> Expect.not_()
    |> Expect.to_have_attribute!("data-phx-ref-lock")

    sync_lv(page)
  end

  test "nested LiveView component patch is not lost when locked ancestor is skipped", %{
    page: page
  } do
    run_locked(page, "skip")

    page |> Page.locator("#outside-count") |> Expect.to_have_text!("1")
    page |> Page.locator("#child-component-label") |> Expect.to_have_text!("child 1")
  end

  test "nested LiveView component patch is not lost when locked ancestor is patched", %{
    page: page
  } do
    run_locked(page, "root")

    page |> Page.locator("#outside-count") |> Expect.to_have_text!("1")
    page |> Page.locator("#child-component-label") |> Expect.to_have_text!("child 1")
  end

  test "nested LiveView component patch does not target parent component with same cid", %{
    page: page
  } do
    run_locked(page, "collision")

    page
    |> Page.locator("#child-lv #child-component-label")
    |> Expect.to_have_text!("child 1")

    page
    |> Page.locator("#locked > #parent-component #parent-component-label")
    |> Expect.to_have_text!("parent 0")

    page |> Page.locator("#update-parent") |> Locator.click!()
    page |> Page.locator("#parent-component-label") |> Expect.to_have_text!("parent 1")
  end
end
