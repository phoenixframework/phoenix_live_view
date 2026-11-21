defmodule Phoenix.LiveViewTest.E2E.Issue4323Test do
  use Phoenix.LiveViewTest.E2E.Case

  defp increment_counter(page) do
    eval_lv(
      page,
      "{:noreply, Phoenix.Component.assign(socket, :counter, socket.assigns.counter + 1)}"
    )

    sync_lv(page)
  end

  describe "phx-patch-focused" do
    setup %{page: page} do
      Page.goto!(page, "/issues/4323")
      sync_lv(page)
      :ok
    end

    test "preserves focused form-associated custom elements by default", %{page: page} do
      control = Page.locator(page, "#face-default")
      Locator.focus!(control)
      Expect.to_be_focused!(control)

      increment_counter(page)

      page |> Page.locator("#face-default-child") |> Expect.to_have_text!("count:0")
    end

    test "patches an opted-in focused form-associated custom element", %{page: page} do
      control = Page.locator(page, "#face-opt-in")
      Locator.focus!(control)
      Expect.to_be_focused!(control)

      increment_counter(page)

      page |> Page.locator("#face-opt-in-child") |> Expect.to_have_text!("count:1")
    end

    test "patches opted-in slotted children when focus is delegated", %{page: page} do
      page |> Page.locator("#face-delegates") |> Locator.click!()

      Expect.poll!(
        fn -> Page.evaluate!(page, "() => document.activeElement?.id") end,
        &assert(&1 == "face-delegates")
      )

      increment_counter(page)

      page |> Page.locator("#face-delegates-child") |> Expect.to_have_text!("count:1")
    end

    test "preserves a focused native input by default", %{page: page} do
      input = Page.locator(page, "#native-default")
      Locator.fill!(input, "client")
      Expect.to_be_focused!(input)

      increment_counter(page)

      Expect.to_have_value!(input, "client")
    end

    test "patches an opted-in focused native input", %{page: page} do
      input = Page.locator(page, "#native-opt-in")
      Locator.fill!(input, "client")
      Expect.to_be_focused!(input)

      increment_counter(page)

      Expect.to_have_value!(input, "1")
    end
  end
end
