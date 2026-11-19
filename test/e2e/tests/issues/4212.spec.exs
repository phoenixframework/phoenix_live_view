defmodule Phoenix.LiveViewTest.E2E.Issue4212Test do
  use Phoenix.LiveViewTest.E2E.Case

  # https://github.com/phoenixframework/phoenix_live_view/issues/4212
  #
  # stream_insert(..., at: idx) used to call insertBefore() inside
  # maybeReOrderStream, which detaches and re-attaches the moved DOM node and
  # fires extra disconnectedCallback / connectedCallback cycles on custom
  # elements. The fix routes the reorder through the atomic moveBefore() API
  # when the runtime supports it. We assert that connectedMoveCallback fires
  # (direct evidence that moveBefore was used) and that no spurious
  # disconnect happened on the just-inserted element.
  test "stream_insert with :at uses atomic moveBefore for the reorder", %{page: page} do
    Page.goto!(page, "/issues/4212")
    sync_lv(page)

    move_before_supported =
      Page.evaluate!(page, ~s|() => typeof Element.prototype.moveBefore === "function"|)

    # skipped without moveBefore (ExUnit has no runtime skip, so the test passes)
    if move_before_supported do
      # wait for the SSR'd custom elements to be observable; we don't make a
      # strict assertion on the initial-mount log because morphdom's join-time
      # reconciliation can produce extra disconnect/connect cycles outside the
      # maybeReOrderStream path covered by this fix.
      Expect.poll!(
        fn ->
          Page.evaluate!(
            page,
            ~s|() => window.__lvCustomElLog.filter((e) => e.type === "connected").length|
          )
        end,
        &assert(&1 >= 3)
      )

      Page.evaluate!(page, "() => (window.__lvCustomElLog = [])")

      page |> Page.locator("#insert-at-1") |> Locator.click!()
      sync_lv(page)

      # The new element is added by morphdom's addChild (-> connectedCallback),
      # and then maybeReOrderStream moves it to the at: 1 position. With the
      # moveBefore fix, that reorder must produce a connectedMoveCallback and
      # must NOT produce a disconnect on the just-inserted element.
      log = Page.evaluate!(page, "() => window.__lvCustomElLog")
      new_events = Enum.filter(log, &(&1["id"] == "el-new1"))

      # arrayContaining
      assert %{"type" => "connected", "id" => "el-new1"} in new_events
      assert %{"type" => "moved", "id" => "el-new1"} in new_events
      assert Enum.filter(new_events, &(&1["type"] == "disconnected")) == []
    end
  end
end
