defmodule Phoenix.LiveViewTest.E2E.UploadsTest do
  use Phoenix.LiveViewTest.E2E.Case

  # https://stackoverflow.com/questions/10623798/how-do-i-read-the-contents-of-a-node-js-stream-into-a-string-variable
  # (create_read_stream! returns an Enumerable of binaries)
  defp read_stream(stream), do: Enum.join(stream)

  # https://github.com/phoenixframework/phoenix_live_view/issues/4369
  test "file inputs stay disabled until connected and across reloads", %{page: page} do
    # `let releaseJoin; let joinReleased = new Promise(...)`
    join_released = deferred()

    Page.route_web_socket!(page, ~r"/live/websocket", fn ws ->
      server = WebSocketRoute.connect_to_server(ws)

      WebSocketRoute.on_message(ws, fn message ->
        if is_binary(message) and String.contains?(message, ~s("phx_join")) do
          # `await joinReleased` inside the async handler: blocking the handler process would
          # stall the connection, so a process awaits the promise and forwards the message
          # (JS keeps handling later messages meanwhile, as here)
          Task.start(fn ->
            await_deferred(join_released)
            WebSocketRoute.send(server, message)
          end)
        else
          WebSocketRoute.send(server, message)
        end
      end)
    end)

    Page.goto!(page, "/upload")
    input = Page.locator(page, "#upload-form input[type=file]")
    Expect.to_be_disabled!(input)
    input |> Expect.not_() |> Expect.to_have_attribute!("data-phx-user-disabled")

    resolve(join_released)
    sync_lv(page)
    Expect.to_be_enabled!(input)

    # Firefox must not restore the enabled state before the hook mounts again.
    reset(join_released)
    Page.reload!(page)
    Expect.to_be_disabled!(input)
    resolve(join_released)
    sync_lv(page)
    Expect.to_be_enabled!(input)

    Page.evaluate!(
      page,
      "() => new Promise((resolve) => window.liveSocket.disconnect(resolve))"
    )

    Expect.to_be_disabled!(input)
    Page.evaluate!(page, "() => window.liveSocket.connect()")
    sync_lv(page)
    Expect.to_be_enabled!(input)
  end

  test "can upload a file", %{page: page} do
    Page.goto!(page, "/upload")
    sync_lv(page)

    changes_form = attribute_mutations(page, "#upload-form")
    changes_input = attribute_mutations(page, "#upload-form input")

    # wait for the change listeners to be ready
    Page.wait_for_timeout!(page, 50)

    page
    |> Page.locator("#upload-form input")
    |> Locator.set_input_files!(%{
      name: "file.txt",
      mimeType: "text/plain",
      buffer: "this is a test"
    })

    sync_lv(page)
    page |> Page.locator("progress") |> Expect.to_have_attribute!("value", "0")
    page |> Page.get_by_role(:button, name: "Upload") |> Locator.click!()

    # we should see one uploaded file in the list
    page |> Page.locator("ul li") |> Expect.to_be_visible!()

    # expect.arrayContaining
    form_changes = changes_form.()

    for change <- [
          %{"attr" => "class", "oldValue" => :null, "newValue" => "phx-submit-loading"},
          %{"attr" => "class", "oldValue" => "phx-submit-loading", "newValue" => :null}
        ] do
      assert change in form_changes
    end

    input_changes = changes_input.()

    for change <- [
          %{"attr" => "class", "oldValue" => :null, "newValue" => "phx-change-loading"},
          %{"attr" => "class", "oldValue" => "phx-change-loading", "newValue" => :null}
        ] do
      assert change in input_changes
    end

    # now download the file to see if it contains the expected content
    download_promise = Page.wait_for_event(page, :download)
    page |> Page.locator("ul li a") |> Locator.click!()
    download = Promise.await!(download_promise)

    assert download |> Download.create_read_stream!() |> read_stream() == "this is a test"
  end

  test "can drop a file", %{page: page} do
    Page.goto!(page, "/upload")
    sync_lv(page)

    # https://github.com/microsoft/playwright/issues/10667
    # Create the DataTransfer and File
    data_transfer =
      Page.evaluate_handle!(
        page,
        """
        (data) => {
          const dt = new DataTransfer();
          // Convert the buffer to a hex array
          const file = new File([data], "file.txt", { type: "text/plain" });
          dt.items.add(file);
          return dt;
        }
        """,
        "this is a test"
      )

    # Now dispatch
    Page.dispatch_event!(page, "section", "drop", %{dataTransfer: data_transfer})

    sync_lv(page)
    page |> Page.get_by_role(:button, name: "Upload") |> Locator.click!()

    # we should see one uploaded file in the list
    page |> Page.locator("ul li") |> Expect.to_be_visible!()

    # now download the file to see if it contains the expected content
    download_promise = Page.wait_for_event(page, :download)
    page |> Page.locator("ul li a") |> Locator.click!()
    download = Promise.await!(download_promise)

    assert download |> Download.create_read_stream!() |> read_stream() == "this is a test"
  end

  test "removes the active drop target class when dragging leaves the browser", %{page: page} do
    Page.goto!(page, "/upload")
    sync_lv(page)

    drop_target = Page.locator(page, "#drop-target")

    data_transfer =
      Page.evaluate_handle!(page, """
      () => {
        const dataTransfer = new DataTransfer();
        dataTransfer.items.add(
          new File(["this is a test"], "file.txt", { type: "text/plain" }),
        );
        return dataTransfer;
      }
      """)

    Locator.dispatch_event!(drop_target, "dragenter", %{dataTransfer: data_transfer})
    Expect.to_have_class!(drop_target, ~r/phx-drop-target-active/)

    box = Locator.bounding_box!(drop_target)
    assert box != nil

    # When leaving the browser, Firefox can report pointer coordinates that numerically overlap
    # the drop target even though relatedTarget is null because no other DOM element was entered.
    Locator.dispatch_event!(drop_target, "dragleave", %{
      dataTransfer: data_transfer,
      clientX: box.x + box.width / 2,
      clientY: box.y + box.height / 2,
      relatedTarget: :null
    })

    drop_target |> Expect.not_() |> Expect.to_have_class!(~r/phx-drop-target-active/)
  end

  test "keeps the active drop target class when dragging across a child", %{page: page} do
    Page.goto!(page, "/upload")
    sync_lv(page)

    drop_target = Page.locator(page, "#drop-target")
    child = Page.locator(page, "#drop-target-inner")

    data_transfer =
      Page.evaluate_handle!(page, """
      () => {
        const dataTransfer = new DataTransfer();
        dataTransfer.items.add(
          new File(["this is a test"], "file.txt", { type: "text/plain" }),
        );
        return dataTransfer;
      }
      """)

    Locator.dispatch_event!(drop_target, "dragenter", %{dataTransfer: data_transfer})
    Expect.to_have_class!(drop_target, ~r/phx-drop-target-active/)

    # Older Safari reports relatedTarget as null when crossing child boundaries. The dragenter for
    # the child and dragleave for its parent must balance without removing the active class.
    Locator.dispatch_event!(child, "dragenter", %{
      dataTransfer: data_transfer,
      relatedTarget: :null
    })

    Locator.dispatch_event!(drop_target, "dragleave", %{
      dataTransfer: data_transfer,
      relatedTarget: :null
    })

    Expect.to_have_class!(drop_target, ~r/phx-drop-target-active/)

    Locator.dispatch_event!(child, "dragleave", %{
      dataTransfer: data_transfer,
      relatedTarget: :null
    })

    drop_target |> Expect.not_() |> Expect.to_have_class!(~r/phx-drop-target-active/)
  end

  test "can upload multiple files", %{page: page} do
    Page.goto!(page, "/upload")
    sync_lv(page)

    page
    |> Page.locator("#upload-form input")
    |> Locator.set_input_files!([
      %{
        name: "file.txt",
        mimeType: "text/plain",
        buffer: "this is a test"
      },
      %{
        name: "file.md",
        mimeType: "text/markdown",
        buffer: "## this is a markdown file"
      }
    ])

    sync_lv(page)
    page |> Page.get_by_role(:button, name: "Upload") |> Locator.click!()

    # we should see two uploaded files in the list
    page |> Page.locator("ul li") |> Expect.to_have_count!(2)
  end

  test "shows error when there are too many files", %{page: page} do
    Page.goto!(page, "/upload")
    sync_lv(page)

    page
    |> Page.locator("#upload-form input")
    |> Locator.set_input_files!([
      %{
        name: "file.txt",
        mimeType: "text/plain",
        buffer: "this is a test"
      },
      %{
        name: "file.md",
        mimeType: "text/markdown",
        buffer: "## this is a markdown file"
      },
      %{
        name: "file2.txt",
        mimeType: "text/plain",
        buffer: "another file"
      }
    ])

    sync_lv(page)

    page
    |> Page.locator(".alert")
    |> Expect.to_contain_text!("You have selected too many files")
  end

  test "shows error for invalid mimetype", %{page: page} do
    Page.goto!(page, "/upload")
    sync_lv(page)

    page
    |> Page.locator("#upload-form input")
    |> Locator.set_input_files!([
      %{
        name: "file.html",
        mimeType: "text/html",
        buffer: "<h1>Hi</h1>"
      }
    ])

    sync_lv(page)

    page
    |> Page.locator(".alert")
    |> Expect.to_contain_text!("You have selected an unacceptable file type")
  end

  test "auto upload", %{page: page} do
    Page.goto!(page, "/upload?auto_upload=1")
    sync_lv(page)

    changes = attribute_mutations(page, "#upload-form input")
    # wait for the change listeners to be ready
    Page.wait_for_timeout!(page, 50)

    page
    |> Page.locator("#upload-form input")
    |> Locator.set_input_files!([
      %{
        name: "file.txt",
        mimeType: "text/plain",
        buffer: "this is a test"
      }
    ])

    sync_lv(page)
    page |> Page.locator("progress") |> Expect.to_have_attribute!("value", "100")

    # expect.arrayContaining
    input_changes = changes.()

    for change <- [
          %{"attr" => "class", "oldValue" => :null, "newValue" => "phx-change-loading"},
          %{"attr" => "class", "oldValue" => "phx-change-loading", "newValue" => :null}
        ] do
      assert change in input_changes
    end

    page |> Page.get_by_role(:button, name: "Upload") |> Locator.click!()

    page |> Page.locator("ul li") |> Expect.to_be_visible!()
  end

  # https://github.com/phoenixframework/phoenix_live_view/issues/3287
  test "external uploader is notified when an upload is cancelled", %{page: page} do
    Page.goto!(page, "/upload?external_upload=1")
    sync_lv(page)

    page
    |> Page.locator("#upload-form input")
    |> Locator.set_input_files!(%{
      name: "file.txt",
      mimeType: "text/plain",
      buffer: "this upload remains in progress"
    })

    page
    |> Page.locator("html")
    |> Expect.to_have_attribute!("data-external-upload-started", ~r/.+/)

    page |> Page.get_by_label("cancel") |> Locator.click!()

    page
    |> Page.locator("html")
    |> Expect.to_have_attribute!("data-external-upload-aborted", ~r/.+/)
  end

  # https://github.com/phoenixframework/phoenix_live_view/issues/3380
  test "external uploader is notified when its view is replaced", %{page: page} do
    Page.goto!(page, "/upload?external_upload=1")
    sync_lv(page)

    page
    |> Page.locator("#upload-form input")
    |> Locator.set_input_files!(%{
      name: "file.txt",
      mimeType: "text/plain",
      buffer: "this upload remains in progress"
    })

    page
    |> Page.locator("html")
    |> Expect.to_have_attribute!("data-external-upload-started", ~r/.+/)

    page |> Page.get_by_role(:link, name: "Replace view") |> Locator.click!()

    Expect.to_have_url!(page, ~r/\/upload\?replaced=1$/)

    page
    |> Page.locator("html")
    |> Expect.to_have_attribute!("data-external-upload-aborted", ~r/.+/)
  end

  test "issue 3115 - cancelled upload is not re-added", %{page: page} do
    Page.goto!(page, "/upload")
    sync_lv(page)

    page
    |> Page.locator("#upload-form input")
    |> Locator.set_input_files!([
      %{
        name: "file.txt",
        mimeType: "text/plain",
        buffer: "this is a test"
      }
    ])

    sync_lv(page)
    # cancel the file
    page |> Page.get_by_label("cancel") |> Locator.click!()

    # add other file
    page
    |> Page.locator("#upload-form input")
    |> Locator.set_input_files!([
      %{
        name: "file.md",
        mimeType: "text/markdown",
        buffer: "## this is a markdown file"
      }
    ])

    sync_lv(page)
    page |> Page.get_by_role(:button, name: "Upload") |> Locator.click!()
    sync_lv(page)

    # we should see one uploaded file in the list
    page |> Page.locator("ul li") |> Expect.to_have_count!(1)
  end

  test "submitting invalid form multiple times doesn't crash", %{page: page} do
    # https://github.com/phoenixframework/phoenix_live_view/pull/3133#issuecomment-1962439904
    Page.goto!(page, "/upload")
    sync_lv(page)

    logs = array()
    Page.on(page, :console, fn e -> push(logs, ConsoleMessage.text(e)) end)

    page
    |> Page.locator("#upload-form input")
    |> Locator.set_input_files!([
      %{
        name: "file.txt",
        mimeType: "text/plain",
        buffer: "this is a test"
      },
      %{
        name: "file.md",
        mimeType: "text/markdown",
        buffer: "## this is a markdown file"
      },
      %{
        name: "file2.md",
        mimeType: "text/markdown",
        buffer: "## this is another markdown file"
      }
    ])

    sync_lv(page)
    page |> Page.get_by_role(:button, name: "Upload") |> Locator.click!()
    page |> Page.get_by_role(:button, name: "Upload") |> Locator.click!()
    sync_lv(page)

    refute Enum.any?(values(logs), &(&1 =~ ~r/view crashed/))

    page
    |> Page.locator(".alert")
    |> Expect.to_contain_text!("You have selected too many files")
  end

  test "auto upload - can submit files after fixing too many files error", %{page: page} do
    # https://github.com/phoenixframework/phoenix_live_view/commit/80ddf356faaded097358a784c2515c50c345713e
    Page.goto!(page, "/upload?auto_upload=1")
    sync_lv(page)

    logs = array()
    Page.on(page, :console, fn e -> push(logs, ConsoleMessage.text(e)) end)

    page
    |> Page.locator("#upload-form input")
    |> Locator.set_input_files!([
      %{
        name: "file.txt",
        mimeType: "text/plain",
        buffer: "this is a test"
      },
      %{
        name: "file.md",
        mimeType: "text/markdown",
        buffer: "## this is a markdown file"
      },
      %{
        name: "file2.md",
        mimeType: "text/markdown",
        buffer: "## this is another markdown file"
      }
    ])

    # before the fix, this already failed because the phx-change-loading class was not removed
    # because undoRefs failed
    sync_lv(page)

    refute Enum.any?(
             values(logs),
             &(&1 =~ ~r/no preflight upload response returned with ref/)
           )

    # too many files
    page |> Page.locator("ul li") |> Expect.to_have_count!(0)

    page
    |> Page.locator(".alert")
    |> Expect.to_contain_text!("You have selected too many files")

    # now remove the file that caused the error
    page
    |> Page.locator("article")
    |> Locator.filter(has_text: "file2.md")
    |> Locator.get_by_label("cancel")
    |> Locator.click!()

    # now we can upload the files
    page |> Page.get_by_role(:button, name: "Upload") |> Locator.click!()
    sync_lv(page)

    page |> Page.locator(".alert") |> Expect.to_be_hidden!()
    page |> Page.locator("ul li") |> Expect.to_have_count!(2)
  end
end
