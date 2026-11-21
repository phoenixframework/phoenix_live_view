defmodule Phoenix.LiveViewTest.E2E.FormsTest do
  use Phoenix.LiveViewTest.E2E.Case

  alias Playwright.WebSocket

  # one describe with the loop inside, as ExUnit forbids two describes with the same name
  # see also https://github.com/phoenixframework/phoenix_live_view/issues/1759
  # https://github.com/phoenixframework/phoenix_live_view/issues/2993
  describe "restores disabled and readonly states" do
    for path <- ["/form/nested", "/form"] do
      test "#{path} - readonly state is restored after submits", %{page: page} do
        Page.goto!(page, unquote(path))
        sync_lv(page)
        page |> Page.locator("input[name=a]") |> Expect.to_have_attribute!("readonly")
        changes_a = attribute_mutations(page, "input[name=a]")
        changes_b = attribute_mutations(page, "input[name=b]")
        # can submit multiple times and readonly input stays readonly
        page |> Page.locator("#submit") |> Locator.click!()
        sync_lv(page)
        # a is readonly and should stay readonly
        assert_equal(
          changes_a.(),
          array_containing([
            %{"attr" => "data-phx-readonly", "oldValue" => :null, "newValue" => "true"},
            %{"attr" => "readonly", "oldValue" => "", "newValue" => ""},
            %{"attr" => "data-phx-readonly", "oldValue" => "true", "newValue" => :null},
            %{"attr" => "readonly", "oldValue" => "", "newValue" => ""}
          ])
        )

        # b is not readonly, but LV will set it to readonly while submitting
        assert_equal(
          changes_b.(),
          array_containing([
            %{"attr" => "data-phx-readonly", "oldValue" => :null, "newValue" => "false"},
            %{"attr" => "readonly", "oldValue" => :null, "newValue" => ""},
            %{"attr" => "data-phx-readonly", "oldValue" => "false", "newValue" => :null},
            %{"attr" => "readonly", "oldValue" => "", "newValue" => :null}
          ])
        )

        page |> Page.locator("input[name=a]") |> Expect.to_have_attribute!("readonly")
        page |> Page.locator("#submit") |> Locator.click!()
        sync_lv(page)
        page |> Page.locator("input[name=a]") |> Expect.to_have_attribute!("readonly")
      end

      test "#{path} - button disabled state is restored after submits", %{page: page} do
        Page.goto!(page, unquote(path))
        sync_lv(page)
        changes = attribute_mutations(page, "#submit")
        page |> Page.locator("#submit") |> Locator.click!()
        sync_lv(page)
        # submit button is disabled while submitting, but then restored
        assert_equal(
          changes.(),
          array_containing([
            %{"attr" => "data-phx-disabled", "oldValue" => :null, "newValue" => "false"},
            %{"attr" => "disabled", "oldValue" => :null, "newValue" => ""},
            %{"attr" => "class", "oldValue" => :null, "newValue" => "phx-submit-loading"},
            %{"attr" => "data-phx-disabled", "oldValue" => "false", "newValue" => :null},
            %{"attr" => "disabled", "oldValue" => "", "newValue" => :null},
            %{"attr" => "class", "oldValue" => "phx-submit-loading", "newValue" => :null}
          ])
        )
      end

      test "#{path} - non-form button (phx-disable-with) disabled state is restored after click",
           %{page: page} do
        Page.goto!(page, unquote(path))
        sync_lv(page)
        changes = attribute_mutations(page, "button[type=button]")
        page |> Page.locator("button[type=button]") |> Locator.click!()
        sync_lv(page)
        # submit button is disabled while submitting, but then restored
        assert_equal(
          changes.(),
          array_containing([
            %{"attr" => "data-phx-disabled", "oldValue" => :null, "newValue" => "false"},
            %{"attr" => "disabled", "oldValue" => :null, "newValue" => ""},
            %{"attr" => "class", "oldValue" => :null, "newValue" => "phx-click-loading"},
            %{"attr" => "data-phx-disabled", "oldValue" => "false", "newValue" => :null},
            %{"attr" => "disabled", "oldValue" => "", "newValue" => :null},
            %{"attr" => "class", "oldValue" => "phx-click-loading", "newValue" => :null}
          ])
        )
      end
    end
  end

  for path <- ["/form/nested", "/form"] do
    for additional_params <- ["live-component", "", "portal"] do
      if additional_params == "portal" and path == "/form/nested" do
        # TODO: maybe revisit this in the future. I believe we could also track
        # nested LiveViews by them being included in the DOM and only destroy when
        # they are actually removed.
      else
        append = if String.length(additional_params) > 0, do: " #{additional_params}", else: ""

        describe "#{path}#{append} - form recovery" do
          test "form state is recovered when socket reconnects", %{page: page} do
            web_socket_events = array()

            Page.on(page, :web_socket, fn ws ->
              WebSocket.on(ws, :frame_sent, fn event ->
                push(web_socket_events, %{type: "sent", payload: event.payload})
              end)

              WebSocket.on(ws, :frame_received, fn event ->
                push(web_socket_events, %{type: "received", payload: event.payload})
              end)

              WebSocket.on(ws, :close, fn _ ->
                push(web_socket_events, %{type: "close"})
              end)
            end)

            Page.goto!(page, unquote(path) <> "?" <> unquote(additional_params))
            sync_lv(page)

            page |> Page.locator("input[name=b]") |> Locator.fill!("test")
            page |> Page.locator("input[name=e]") |> Locator.fill!("inside")
            page |> Page.locator("input[name=f]") |> Locator.fill!("outside")
            page |> Page.locator("input[name=c]") |> Locator.fill!("hello world")
            page |> Page.locator("select[name=d]") |> Locator.select_option!("bar")
            page |> Page.locator("input[name=c]") |> Expect.to_be_focused!()
            sync_lv(page)

            Page.evaluate!(
              page,
              "() => new Promise((resolve) => window.liveSocket.disconnect(resolve))"
            )

            page |> Page.locator(".phx-loading") |> Expect.to_have_count!(1)

            events = values(web_socket_events)
            assert Enum.any?(events, &(&1.type == "sent" and &1.payload =~ "phx_join"))
            assert Enum.any?(events, &(&1.type == "received" and &1.payload =~ "phx_reply"))
            assert %{type: "close"} in events

            clear(web_socket_events)

            Page.evaluate!(page, "() => window.liveSocket.connect()")
            sync_lv(page)
            page |> Page.locator(".phx-loading") |> Expect.to_have_count!(0)

            page |> Page.locator("input[name=b]") |> Expect.to_have_value!("test")
            # c should still be focused (at least when not using a nested LV)
            if unquote(path) == "/form" do
              page |> Page.locator("input[name=c]") |> Expect.to_be_focused!()
            end

            page |> Page.locator("select[name=d]") |> Expect.to_have_value!("bar")

            events = values(web_socket_events)
            assert Enum.any?(events, &(&1.type == "sent" and &1.payload =~ "phx_join"))
            assert Enum.any?(events, &(&1.type == "received" and &1.payload =~ "phx_reply"))
            assert Enum.any?(events, &(&1.type == "sent" and &1.payload =~ "validate"))

            assert form_payload(events) == %{
                     "_unused_a" => "",
                     "a" => "foo",
                     "b" => "test",
                     "c" => "hello world",
                     "d" => "bar",
                     "e" => "inside",
                     "f" => "outside"
                   }
          end

          test "JS command in phx-change works during recovery", %{page: page} do
            Page.goto!(page, unquote(path) <> "?" <> unquote(additional_params) <> "&js-change=1")
            sync_lv(page)

            page |> Page.locator("input[name=b]") |> Locator.fill!("test")
            # blur, otherwise the input would not be morphed anyway
            page |> Page.locator("input[name=b]") |> Locator.blur!()
            page |> Page.locator("form") |> Expect.to_have_attribute!("phx-change", ~r/push/)
            sync_lv(page)

            Page.evaluate!(
              page,
              "() => new Promise((resolve) => window.liveSocket.disconnect(resolve))"
            )

            page |> Page.locator(".phx-loading") |> Expect.to_have_count!(1)

            Page.evaluate!(page, "() => window.liveSocket.connect()")
            sync_lv(page)
            page |> Page.locator(".phx-loading") |> Expect.to_have_count!(0)
            page |> Page.locator("input[name=b]") |> Expect.to_have_value!("test")
          end

          test "does not recover when form is missing id", %{page: page} do
            Page.goto!(page, "#{unquote(path)}?no-id&#{unquote(additional_params)}")
            sync_lv(page)

            page |> Page.locator("input[name=b]") |> Locator.fill!("test")
            # blur, otherwise the input would not be morphed anyway
            page |> Page.locator("input[name=b]") |> Locator.blur!()
            sync_lv(page)

            Page.evaluate!(
              page,
              "() => new Promise((resolve) => window.liveSocket.disconnect(resolve))"
            )

            page |> Page.locator(".phx-loading") |> Expect.to_have_count!(1)

            Page.evaluate!(page, "() => window.liveSocket.connect()")
            sync_lv(page)
            page |> Page.locator(".phx-loading") |> Expect.to_have_count!(0)

            page |> Page.locator("input[name=b]") |> Expect.to_have_value!("bar")
          end

          test "does not recover when form is missing phx-change", %{page: page} do
            Page.goto!(page, "#{unquote(path)}?no-change-event&#{unquote(additional_params)}")
            sync_lv(page)

            page |> Page.locator("input[name=b]") |> Locator.fill!("test")
            # blur, otherwise the input would not be morphed anyway
            page |> Page.locator("input[name=b]") |> Locator.blur!()
            sync_lv(page)

            Page.evaluate!(
              page,
              "() => new Promise((resolve) => window.liveSocket.disconnect(resolve))"
            )

            page |> Page.locator(".phx-loading") |> Expect.to_have_count!(1)

            Page.evaluate!(page, "() => window.liveSocket.connect()")
            sync_lv(page)
            page |> Page.locator(".phx-loading") |> Expect.to_have_count!(0)

            page |> Page.locator("input[name=b]") |> Expect.to_have_value!("bar")
          end

          test "phx-auto-recover", %{page: page} do
            Page.goto!(
              page,
              "#{unquote(path)}?phx-auto-recover=custom-recovery&#{unquote(additional_params)}"
            )

            sync_lv(page)

            page |> Page.locator("input[name=b]") |> Locator.fill!("test")
            # blur, otherwise the input would not be morphed anyway
            page |> Page.locator("input[name=b]") |> Locator.blur!()
            sync_lv(page)

            Page.evaluate!(
              page,
              "() => new Promise((resolve) => window.liveSocket.disconnect(resolve))"
            )

            page |> Page.locator(".phx-loading") |> Expect.to_have_count!(1)

            web_socket_events = array()

            Page.on(page, :web_socket, fn ws ->
              WebSocket.on(ws, :frame_sent, fn event ->
                push(web_socket_events, %{type: "sent", payload: event.payload})
              end)

              WebSocket.on(ws, :frame_received, fn event ->
                push(web_socket_events, %{type: "received", payload: event.payload})
              end)

              WebSocket.on(ws, :close, fn _ ->
                push(web_socket_events, %{type: "close"})
              end)
            end)

            Page.evaluate!(page, "() => window.liveSocket.connect()")
            sync_lv(page)
            page |> Page.locator(".phx-loading") |> Expect.to_have_count!(0)

            page
            |> Page.locator("input[name=b]")
            |> Expect.to_have_value!("custom value from server")

            events = values(web_socket_events)
            assert Enum.any?(events, &(&1.type == "sent" and &1.payload =~ "phx_join"))
            assert Enum.any?(events, &(&1.type == "received" and &1.payload =~ "phx_reply"))

            assert Enum.any?(
                     events,
                     &(&1.type == "sent" and &1.payload =~ ~r/event.*_unused_a=&a=foo&b=test/)
                   )
          end

          test "respects disabled state of a fieldset", %{page: page} do
            web_socket_events = array()

            Page.on(page, :web_socket, fn ws ->
              WebSocket.on(ws, :frame_sent, fn event ->
                push(web_socket_events, %{type: "sent", payload: event.payload})
              end)

              WebSocket.on(ws, :frame_received, fn event ->
                push(web_socket_events, %{type: "received", payload: event.payload})
              end)

              WebSocket.on(ws, :close, fn _ ->
                push(web_socket_events, %{type: "close"})
              end)
            end)

            Page.goto!(
              page,
              unquote(path) <> "?disabled-fieldset=true&" <> unquote(additional_params)
            )

            sync_lv(page)

            page |> Page.locator("input[name=c]") |> Locator.fill!("hello world")
            page |> Page.locator("select[name=d]") |> Locator.select_option!("bar")
            page |> Page.locator("input[name=c]") |> Expect.to_be_focused!()
            sync_lv(page)

            Page.pause!(page)

            Page.evaluate!(
              page,
              "() => new Promise((resolve) => window.liveSocket.disconnect(resolve))"
            )

            page |> Page.locator(".phx-loading") |> Expect.to_have_count!(1)

            clear(web_socket_events)
            Page.evaluate!(page, "() => window.liveSocket.connect()")
            sync_lv(page)
            page |> Page.locator(".phx-loading") |> Expect.to_have_count!(0)

            assert form_payload(values(web_socket_events)) == %{
                     "c" => "hello world",
                     "d" => "bar",
                     "_unused_e" => "",
                     "e" => "",
                     "_unused_f" => "",
                     "f" => ""
                   }
          end

          # nested LiveViews don't support handle_params
          if path == "/form" do
            test "navigation during recovery is properly handled by the client", %{page: page} do
              Page.goto!(
                page,
                "#{unquote(path)}?phx-auto-recover=patch-recovery&#{unquote(additional_params)}"
              )

              sync_lv(page)

              Page.evaluate!(
                page,
                "() => new Promise((resolve) => window.liveSocket.disconnect(resolve))"
              )

              page |> Page.locator(".phx-loading") |> Expect.to_have_count!(1)

              Page.evaluate!(page, "() => window.liveSocket.connect()")
              # `\p` is a plain `p` in a JS regex but an error in PCRE: pass the JS source
              Expect.to_have_url!(page, Playwright.RegExp.new("\\patched=true"))
            end
          end
        end
      end
    end

    test "#{path} - can submit form with button that has phx-click", %{page: page} do
      Page.goto!(page, "#{unquote(path)}?phx-auto-recover=custom-recovery")
      sync_lv(page)

      page |> Page.get_by_text("Form was submitted!") |> Expect.to_be_hidden!()

      page |> Page.get_by_role(:button, name: "Submit with JS") |> Locator.click!()
      sync_lv(page)

      page |> Page.get_by_text("Form was submitted!") |> Expect.to_be_visible!()
    end

    @tag :request
    test "#{path} - loading and locked states with latency", %{page: page, request: request} do
      nested = String.match?(unquote(path), ~r/nested/)
      Page.goto!(page, "#{unquote(path)}?phx-change=validate")
      sync_lv(page)

      %{"lv_pid" => lv_pid} =
        eval_lv(
          page,
          ~S"""
          <<"#PID"::binary, pid::binary>> = inspect(self())

          pid_parts =
            pid
            |> String.trim_leading("<")
            |> String.trim_trailing(">")
            |> String.split(".")

          %{lv_pid: pid_parts}
          """,
          if(nested, do: "#nested")
        )

      ack = fn event ->
        eval_plug(
          request,
          "send(IEx.Helpers.pid(#{Enum.at(lv_pid, 0)}, #{Enum.at(lv_pid, 1)}, #{Enum.at(lv_pid, 2)}), {:sync, \"#{event}\"}); nil"
        )
      end

      # we serialize the test by letting each event handler wait for a {:sync, event} message
      eval_lv(
        page,
        ~S"""
        attach_hook(socket, :sync, :handle_event, fn event, _params, socket ->
          if event == "ping" do
            {:cont, socket}
          else
            receive do {:sync, ^event} -> {:cont, socket} end
          end
        end)
        """,
        if(nested, do: "#nested")
      )

      page |> Page.get_by_text("Form was submitted!") |> Expect.to_be_hidden!()
      test_form = Page.locator(page, "#test-form")
      submit_btn = Page.locator(page, "#test-form #submit")
      page |> Page.locator("#test-form input[name=b]") |> Locator.fill!("test")
      Expect.to_have_class!(test_form, "myformclass phx-change-loading")
      Expect.to_have_attribute!(test_form, "data-phx-ref-loading")
      # form is locked on phx-change for any changed input
      Expect.to_have_attribute!(test_form, "data-phx-ref-lock")
      Expect.to_have_attribute!(test_form, "data-phx-ref-src")
      Locator.click!(submit_btn)
      # change-loading and submit-loading classes exist simultaneously
      Expect.to_have_class!(test_form, "myformclass phx-change-loading phx-submit-loading")
      # phx-change ack arrives and is removed
      ack.("validate")
      Expect.to_have_class!(test_form, "myformclass phx-submit-loading")
      Expect.to_have_class!(submit_btn, "phx-submit-loading")
      Expect.to_have_attribute!(submit_btn, "data-phx-disable-with-restore", "Submit")
      Expect.to_have_attribute!(submit_btn, "data-phx-ref-loading")
      Expect.to_have_attribute!(test_form, "data-phx-ref-loading")
      Expect.to_have_attribute!(test_form, "data-phx-ref-src")
      Expect.to_have_attribute!(submit_btn, "data-phx-ref-lock")
      # form is not locked on submit
      test_form |> Expect.not_() |> Expect.to_have_attribute!("data-phx-ref-lock")
      Expect.to_have_attribute!(submit_btn, "data-phx-ref-src")
      Expect.to_have_attribute!(submit_btn, "disabled", "")
      Expect.to_have_attribute!(submit_btn, "phx-disable-with", "Submitting")
      ack.("save")
      page |> Page.get_by_text("Form was submitted!") |> Expect.to_be_visible!()
      # all refs are cleaned up
      Expect.to_have_class!(test_form, "myformclass")
      Expect.to_have_class!(submit_btn, "")
      submit_btn |> Expect.not_() |> Expect.to_have_attribute!("data-phx-disable-with-restore")
      submit_btn |> Expect.not_() |> Expect.to_have_attribute!("data-phx-ref-loading")
      submit_btn |> Expect.not_() |> Expect.to_have_attribute!("data-phx-ref-lock")
      submit_btn |> Expect.not_() |> Expect.to_have_attribute!("data-phx-ref-src")
      submit_btn |> Expect.not_() |> Expect.to_have_attribute!("data-phx-ref-loading")
      submit_btn |> Expect.not_() |> Expect.to_have_attribute!("data-phx-ref-lock")
      submit_btn |> Expect.not_() |> Expect.to_have_attribute!("data-phx-ref-src")
      submit_btn |> Expect.not_() |> Expect.to_have_attribute!("disabled")
      Expect.to_have_attribute!(submit_btn, "phx-disable-with", "Submitting")
    end
  end

  @tag :request
  test "loading and locked states with latent clone", %{page: page, request: request} do
    Page.goto!(page, "/form/stream")
    form_hook = Page.locator(page, "#form-stream-hook")
    sync_lv(page)

    %{"lv_pid" => lv_pid} =
      eval_lv(
        page,
        ~S"""
        <<"#PID"::binary, pid::binary>> = inspect(self())

        pid_parts =
          pid
          |> String.trim_leading("<")
          |> String.trim_trailing(">")
          |> String.split(".")

        %{lv_pid: pid_parts}
        """
      )

    ack = fn event ->
      eval_plug(
        request,
        "send(IEx.Helpers.pid(#{Enum.at(lv_pid, 0)}, #{Enum.at(lv_pid, 1)}, #{Enum.at(lv_pid, 2)}), {:sync, \"#{event}\"}); nil"
      )
    end

    # we serialize the test by letting each event handler wait for a {:sync, event} message
    # excluding the ping messages from our hook
    eval_lv(
      page,
      ~S"""
      attach_hook(socket, :sync, :handle_event, fn event, _params, socket ->
        if event == "ping" do
          {:cont, socket}
        else
          receive do {:sync, ^event} -> {:cont, socket} end
        end
      end)
      """
    )

    Expect.to_have_text!(form_hook, "pong")
    test_form = Page.locator(page, "#test-form")
    test_input = Page.locator(page, "#test-form input[name=myname]")
    submit_btn = Page.locator(page, "#test-form button")
    # initial 3 stream items
    page |> Page.locator("#form-stream li") |> Expect.to_have_count!(3)
    Locator.fill!(test_input, "1")
    Locator.fill!(test_input, "2")
    # form is locked on phx-change and stream remains unchanged
    Expect.to_have_class!(test_form, "phx-change-loading")
    Expect.to_have_class!(test_input, "phx-change-loading")
    Expect.to_have_attribute!(test_form, "data-phx-ref-loading")
    Expect.to_have_attribute!(test_form, "data-phx-ref-src")
    Expect.to_have_attribute!(test_input, "data-phx-ref-loading")
    Expect.to_have_attribute!(test_input, "data-phx-ref-src")
    # now we submit
    Locator.click!(submit_btn)
    Expect.to_have_class!(test_form, "phx-change-loading phx-submit-loading")
    Expect.to_have_text!(submit_btn, "Saving...")
    Expect.to_have_class!(test_input, "phx-change-loading")
    Expect.to_have_attribute!(test_form, "data-phx-ref-loading")
    Expect.to_have_attribute!(test_form, "data-phx-ref-src")
    Expect.to_have_attribute!(test_input, "data-phx-ref-loading")
    Expect.to_have_attribute!(test_input, "data-phx-ref-src")
    # now we ack the two change events
    ack.("validate")
    # the form is still locked, therefore we still have 3 elements
    page |> Page.locator("#form-stream li") |> Expect.to_have_count!(3)
    ack.("validate")
    # on unlock, cloned stream items that are added on each phx-change are applied to DOM
    page |> Page.locator("#form-stream li") |> Expect.to_have_count!(5)
    # after clones are applied, the stream item hooks are mounted
    # note that the form still awaits the submit ack, but it is not locked,
    # therefore the updates from the phx-change are already applied
    page
    |> Page.locator("#form-stream li")
    |> Expect.to_have_text!([
      "*%{id: 1}pong",
      "*%{id: 2}pong",
      "*%{id: 3}pong",
      "*%{id: 4}",
      "*%{id: 5}"
    ])

    # still saving
    Expect.to_have_text!(submit_btn, "Saving...")
    Expect.to_have_class!(test_form, "phx-submit-loading")
    Expect.to_have_attribute!(test_input, "readonly", "")
    Expect.to_have_class!(submit_btn, "phx-submit-loading")
    Expect.to_have_attribute!(test_form, "data-phx-ref-loading")
    Expect.to_have_attribute!(test_form, "data-phx-ref-src")
    Expect.to_have_attribute!(test_input, "data-phx-ref-loading")
    Expect.to_have_attribute!(test_input, "data-phx-ref-src")
    Expect.to_have_attribute!(submit_btn, "data-phx-ref-loading")
    Expect.to_have_attribute!(submit_btn, "data-phx-ref-src")
    # now we ack the submit
    ack.("save")
    # submit adds 1 more stream item and new hook is mounted
    page
    |> Page.locator("#form-stream li")
    |> Expect.to_have_text!([
      "*%{id: 1}pong",
      "*%{id: 2}pong",
      "*%{id: 3}pong",
      "*%{id: 4}pong",
      "*%{id: 5}pong",
      "*%{id: 6}pong"
    ])

    Expect.to_have_text!(submit_btn, "Submit")
    Expect.to_have_attribute!(submit_btn, "phx-disable-with", "Saving...")
    test_form |> Expect.not_() |> Expect.to_have_class!("phx-submit-loading")
    test_input |> Expect.not_() |> Expect.to_have_attribute!("readonly")
    submit_btn |> Expect.not_() |> Expect.to_have_class!("phx-submit-loading")
    test_form |> Expect.not_() |> Expect.to_have_attribute!("data-phx-ref")
    test_form |> Expect.not_() |> Expect.to_have_attribute!("data-phx-ref-src")
    test_input |> Expect.not_() |> Expect.to_have_attribute!("data-phx-ref")
    test_input |> Expect.not_() |> Expect.to_have_attribute!("data-phx-ref-src")
    submit_btn |> Expect.not_() |> Expect.to_have_attribute!("data-phx-ref")
    submit_btn |> Expect.not_() |> Expect.to_have_attribute!("data-phx-ref-src")
  end

  test "can dynamically add/remove inputs (ecto sort_param/drop_param)", %{page: page} do
    Page.goto!(page, "/form/dynamic-inputs")
    sync_lv(page)

    form_data = fn ->
      page
      |> Page.locator("form")
      |> Locator.evaluate!("(form) => Object.fromEntries(new FormData(form).entries())")
    end

    assert form_data.() == %{
             "my_form[name]" => "",
             "my_form[users_drop][]" => ""
           }

    page |> Page.locator("#my-form_name") |> Locator.fill!("Test")
    page |> Page.get_by_role(:button, name: "add more") |> Locator.click!()
    sync_lv(page)

    assert %{
             "my_form[name]" => "Test",
             "my_form[users][0][name]" => ""
           } = form_data.()

    page |> Page.locator("#my-form_users_0_name") |> Locator.fill!("User A")
    page |> Page.get_by_role(:button, name: "add more") |> Locator.click!()
    sync_lv(page)
    page |> Page.get_by_role(:button, name: "add more") |> Locator.click!()
    sync_lv(page)

    page |> Page.locator("#my-form_users_1_name") |> Locator.fill!("User B")
    page |> Page.locator("#my-form_users_2_name") |> Locator.fill!("User C")

    assert %{
             "my_form[name]" => "Test",
             "my_form[users_drop][]" => "",
             "my_form[users][0][name]" => "User A",
             "my_form[users][1][name]" => "User B",
             "my_form[users][2][name]" => "User C"
           } = form_data.()

    # remove User B
    page |> Page.locator(~s(button[name="my_form[users_drop][]"][value="1"])) |> Locator.click!()
    sync_lv(page)

    assert %{
             "my_form[name]" => "Test",
             "my_form[users_drop][]" => "",
             "my_form[users][0][name]" => "User A",
             "my_form[users][1][name]" => "User C"
           } = form_data.()
  end

  test "can dynamically add/remove inputs using checkboxes", %{page: page} do
    Page.goto!(page, "/form/dynamic-inputs?checkboxes=1")
    sync_lv(page)

    form_data = fn ->
      page
      |> Page.locator("form")
      |> Locator.evaluate!("(form) => Object.fromEntries(new FormData(form).entries())")
    end

    assert form_data.() == %{
             "my_form[name]" => "",
             "my_form[users_drop][]" => ""
           }

    page |> Page.locator("#my-form_name") |> Locator.fill!("Test")
    page |> Page.locator("label", has_text: "add more") |> Locator.click!()
    sync_lv(page)

    assert %{
             "my_form[name]" => "Test",
             "my_form[users][0][name]" => ""
           } = form_data.()

    page |> Page.locator("#my-form_users_0_name") |> Locator.fill!("User A")
    page |> Page.locator("label", has_text: "add more") |> Locator.click!()
    page |> Page.locator("label", has_text: "add more") |> Locator.click!()

    page |> Page.locator("#my-form_users_1_name") |> Locator.fill!("User B")
    page |> Page.locator("#my-form_users_2_name") |> Locator.fill!("User C")
    sync_lv(page)

    assert %{
             "my_form[name]" => "Test",
             "my_form[users_drop][]" => "",
             "my_form[users][0][name]" => "User A",
             "my_form[users][1][name]" => "User B",
             "my_form[users][2][name]" => "User C"
           } = form_data.()

    # remove User B
    page |> Page.locator(~s(input[name="my_form[users_drop][]"][value="1"])) |> Locator.click!()
    sync_lv(page)

    assert %{
             "my_form[name]" => "Test",
             "my_form[users_drop][]" => "",
             "my_form[users][0][name]" => "User A",
             "my_form[users][1][name]" => "User C"
           } = form_data.()
  end

  # this happened from v1.0.17 when the sort_params field is nested in a fieldset
  test "form recovery does not create duplicates of dynamically added fields", %{page: page} do
    Page.goto!(page, "/form/dynamic-inputs")
    sync_lv(page)

    form_data = fn ->
      page
      |> Page.locator("form")
      |> Locator.evaluate!("(form) => Object.fromEntries(new FormData(form).entries())")
    end

    assert form_data.() == %{
             "my_form[name]" => "",
             "my_form[users_drop][]" => ""
           }

    page |> Page.locator("#my-form_name") |> Locator.fill!("Test")
    page |> Page.get_by_role(:button, name: "add more") |> Locator.click!()
    sync_lv(page)

    assert %{
             "my_form[name]" => "Test",
             "my_form[users][0][name]" => ""
           } = form_data.()

    Page.evaluate!(
      page,
      "() => new Promise((resolve) => window.liveSocket.disconnect(resolve))"
    )

    Page.evaluate!(page, "() => window.liveSocket.connect()")
    sync_lv(page)

    data = form_data.()

    assert Map.has_key?(data, "my_form[users][1][name]") == false
  end

  # phx-feedback-for was removed in LiveView 1.0, but we still test the shim applied in
  # test_helper.exs layout for backwards compatibility
  test "phx-no-feedback is applied correctly for backwards-compatible-shims", %{page: page} do
    Page.goto!(page, "/form/feedback")
    sync_lv(page)

    page |> Page.locator("[phx-feedback-for=myfeedback]") |> Expect.to_be_hidden!()
    page |> Page.get_by_role(:button, name: "+") |> Locator.click!()
    sync_lv(page)
    page |> Page.locator("[phx-feedback-for=myfeedback]") |> Expect.to_be_hidden!()
    page |> Page.get_by_text("Validate count") |> Expect.to_contain_text!("0")

    page |> Page.locator("input[name=name]") |> Locator.fill!("Test")
    sync_lv(page)
    page |> Page.locator("[phx-feedback-for=myfeedback]") |> Expect.to_be_hidden!()
    page |> Page.get_by_text("Validate count") |> Expect.to_contain_text!("1")

    page |> Page.locator("input[name=myfeedback]") |> Locator.fill!("Test")
    sync_lv(page)
    page |> Page.get_by_text("Validate count") |> Expect.to_contain_text!("2")
    page |> Page.locator("[phx-feedback-for=myfeedback]") |> Expect.to_be_visible!()

    # feedback appears on submit
    Page.reload!(page)
    sync_lv(page)
    page |> Page.locator("[phx-feedback-for=myfeedback]") |> Expect.to_be_hidden!()

    page |> Page.get_by_role(:button, name: "Submit") |> Locator.click!()
    sync_lv(page)
    page |> Page.get_by_text("Submit count") |> Expect.to_contain_text!("1")
    page |> Page.locator("[phx-feedback-for=myfeedback]") |> Expect.to_be_visible!()

    # feedback hides on reset
    page |> Page.get_by_role(:button, name: "Reset") |> Locator.click!()
    sync_lv(page)
    page |> Page.locator("[phx-feedback-for=myfeedback]") |> Expect.to_be_hidden!()

    # can toggle feedback visibility
    Page.reload!(page)
    sync_lv(page)
    page |> Page.locator("[data-feedback-container]") |> Expect.to_be_hidden!()

    page |> Page.get_by_role(:button, name: "Toggle feedback") |> Locator.click!()
    sync_lv(page)
    page |> Page.locator("[data-feedback-container]") |> Expect.to_be_visible!()

    page |> Page.get_by_role(:button, name: "Toggle feedback") |> Locator.click!()
    sync_lv(page)
    page |> Page.locator("[data-feedback-container]") |> Expect.to_be_hidden!()
  end

  test "phx-no-unused-field on a form is applied correctly and no unused fields are sent",
       %{page: page} do
    web_socket_events = array()

    Page.on(page, :web_socket, fn ws ->
      WebSocket.on(ws, :frame_sent, fn event ->
        push(web_socket_events, %{type: "sent", payload: event.payload})
      end)
    end)

    Page.goto!(page, "/form?phx-no-unused-field-form")
    sync_lv(page)

    page |> Page.locator("input[name=b]") |> Locator.fill!("test")
    # blur, otherwise the input would not be morphed anyway
    page |> Page.locator("input[name=b]") |> Locator.blur!()
    sync_lv(page)

    # With phx-no-unused-field on the form, no _unused_ parameters should be sent
    events = values(web_socket_events)

    assert Enum.any?(
             events,
             &(&1.type == "sent" and &1.payload =~ ~r/event.*a=foo&b=test&c=baz&d=foo/)
           )

    # Ensure no _unused_ parameters are present in any sent events
    sent_events = Enum.filter(events, &(&1.type == "sent"))

    Enum.each(sent_events, fn event ->
      refute event.payload =~ ~r/_unused_/
    end)
  end

  test "phx-no-unused-field on an input is applied correctly and no unused field is sent for that specific input",
       %{page: page} do
    web_socket_events = array()

    Page.on(page, :web_socket, fn ws ->
      WebSocket.on(ws, :frame_sent, fn event ->
        push(web_socket_events, %{type: "sent", payload: event.payload})
      end)
    end)

    Page.goto!(page, "/form?phx-no-unused-field-input")
    sync_lv(page)

    page |> Page.locator("input[name=b]") |> Locator.fill!("test")
    # blur, otherwise the input would not be morphed anyway
    page |> Page.locator("input[name=b]") |> Locator.blur!()
    sync_lv(page)

    # Check that the form data and unused parameters are sent correctly
    events = values(web_socket_events)

    assert Enum.any?(
             events,
             &(&1.type == "sent" and
                 &1.payload =~ ~r/event.*_unused_a=&a=foo&b=test&c=baz&_unused_d=&d=foo/)
           )

    # Verify specific unused parameter behavior
    sent_events = Enum.filter(events, &(&1.type == "sent"))
    form_data_event = Enum.find(sent_events, &String.contains?(&1.payload, "a=foo"))

    # a and d should have _unused_ parameters (untouched, no phx-no-unused-field)
    assert form_data_event.payload =~ ~r/_unused_a=/
    assert form_data_event.payload =~ ~r/_unused_d=/
    # b and c should NOT have _unused_ parameters (b touched, c has phx-no-unused-field)
    refute form_data_event.payload =~ ~r/_unused_b=/
    refute form_data_event.payload =~ ~r/_unused_c=/
  end

  defp form_payload(events) do
    event =
      Enum.find(
        events,
        &(&1.type == "sent" and String.contains?(&1.payload, ~s("event":"validate")))
      )

    parsed = JSON.decode!(event.payload)
    URI.decode_query(Enum.at(parsed, 4)["value"])
  end
end
