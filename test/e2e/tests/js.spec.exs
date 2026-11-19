defmodule Phoenix.LiveViewTest.E2E.JsTest do
  use Phoenix.LiveViewTest.E2E.Case

  for kind <- ["focus", "focus_first", "pop_focus"] do
    test "#{kind} retries focus after showing a hidden target", %{page: page} do
      Page.goto!(page, "/js")
      sync_lv(page)

      initially_focused =
        Page.evaluate!(
          page,
          """
          (kind) => {
            const root = document.querySelector("[data-phx-main]");
            root.insertAdjacentHTML(
              "beforeend",
              `<input id="other" />
               <div id="parent" style="display: none">
                 <input id="target" />
               </div>`,
            );
            document.getElementById("other").focus();
            const to = kind === "focus_first" ? "#parent" : "#target";
            const commands = [
              [
                "show",
                { to: "#parent", transition: [["fade-in"], [], []], time: 50 },
              ],
              ...(kind === "pop_focus"
                ? [
                    ["push_focus", { to }],
                    ["pop_focus", {}],
                  ]
                : [[kind, { to }]]),
            ];
            window.liveSocket.execJS(root, JSON.stringify(commands));
            return document.activeElement.id;
          }
          """,
          unquote(kind)
        )

      assert initially_focused == "other"
      page |> Page.locator("#target") |> Expect.to_be_focused!()
    end
  end

  test "toggle_attribute", %{page: page} do
    Page.goto!(page, "/js")
    sync_lv(page)

    page |> Page.locator("#my-modal") |> Expect.to_be_hidden!()

    changes = attribute_mutations(page, "#my-modal")
    page |> Page.get_by_role(:button, name: "toggle modal") |> Locator.click!()
    # wait for the transition time (set to 50)
    Page.wait_for_timeout!(page, 100)

    assert_equal(
      changes.(),
      array_containing([
        %{
          "attr" => "style",
          "oldValue" => "display: none;",
          "newValue" => "display: block;"
        },
        %{"attr" => "aria-expanded", "oldValue" => "false", "newValue" => "true"},
        %{"attr" => "open", "oldValue" => :null, "newValue" => "true"},
        # chrome and firefox first transition from null to "" and then to "fade-in";
        # safari goes straight from null to "fade-in", therefore we do not perform an exact match
        object_containing(%{"attr" => "class", "newValue" => "fade-in"}),
        object_containing(%{"attr" => "class", "oldValue" => "fade-in"})
      ])
    )

    page |> Page.locator("#my-modal") |> Expect.not_() |> Expect.to_have_class!("fade-in")
    page |> Page.locator("#my-modal") |> Expect.to_have_attribute!("aria-expanded", "true")
    page |> Page.locator("#my-modal") |> Expect.to_have_attribute!("open", "true")
    page |> Page.locator("#my-modal") |> Expect.to_be_visible!()

    changes = attribute_mutations(page, "#my-modal")
    page |> Page.get_by_role(:button, name: "toggle modal") |> Locator.click!()
    # wait for the transition time (set to 50)
    Page.wait_for_timeout!(page, 100)

    assert_equal(
      changes.(),
      array_containing([
        %{
          "attr" => "style",
          "oldValue" => "display: block;",
          "newValue" => "display: none;"
        },
        %{"attr" => "aria-expanded", "oldValue" => "true", "newValue" => "false"},
        %{"attr" => "open", "oldValue" => "true", "newValue" => :null},
        object_containing(%{"attr" => "class", "newValue" => "fade-out"}),
        object_containing(%{"attr" => "class", "oldValue" => "fade-out"})
      ])
    )

    page |> Page.locator("#my-modal") |> Expect.not_() |> Expect.to_have_class!("fade-out")
    page |> Page.locator("#my-modal") |> Expect.to_have_attribute!("aria-expanded", "false")
    page |> Page.locator("#my-modal") |> Expect.not_() |> Expect.to_have_attribute!("open")
    page |> Page.locator("#my-modal") |> Expect.to_be_hidden!()
  end

  test "set and remove_attribute", %{page: page} do
    Page.goto!(page, "/js")
    sync_lv(page)

    page |> Page.locator("#my-modal") |> Expect.to_be_hidden!()

    changes = attribute_mutations(page, "#my-modal")
    page |> Page.get_by_role(:button, name: "show modal") |> Locator.click!()
    # wait for the transition time (set to 50)
    Page.wait_for_timeout!(page, 100)

    assert_equal(
      changes.(),
      array_containing([
        %{
          "attr" => "style",
          "oldValue" => "display: none;",
          "newValue" => "display: block;"
        },
        %{"attr" => "aria-expanded", "oldValue" => "false", "newValue" => "true"},
        %{"attr" => "open", "oldValue" => :null, "newValue" => "true"},
        object_containing(%{"attr" => "class", "newValue" => "fade-in"}),
        object_containing(%{"attr" => "class", "oldValue" => "fade-in"})
      ])
    )

    page |> Page.locator("#my-modal") |> Expect.not_() |> Expect.to_have_class!("fade-in")
    page |> Page.locator("#my-modal") |> Expect.to_have_attribute!("aria-expanded", "true")
    page |> Page.locator("#my-modal") |> Expect.to_have_attribute!("open", "true")
    page |> Page.locator("#my-modal") |> Expect.to_be_visible!()

    changes = attribute_mutations(page, "#my-modal")
    page |> Page.get_by_role(:button, name: "hide modal") |> Locator.click!()
    # wait for the transition time (set to 50)
    Page.wait_for_timeout!(page, 100)

    assert_equal(
      changes.(),
      array_containing([
        %{
          "attr" => "style",
          "oldValue" => "display: block;",
          "newValue" => "display: none;"
        },
        %{"attr" => "aria-expanded", "oldValue" => "true", "newValue" => "false"},
        %{"attr" => "open", "oldValue" => "true", "newValue" => :null},
        object_containing(%{"attr" => "class", "newValue" => "fade-out"}),
        object_containing(%{"attr" => "class", "oldValue" => "fade-out"})
      ])
    )

    page |> Page.locator("#my-modal") |> Expect.not_() |> Expect.to_have_class!("fade-out")
    page |> Page.locator("#my-modal") |> Expect.to_have_attribute!("aria-expanded", "false")
    page |> Page.locator("#my-modal") |> Expect.not_() |> Expect.to_have_attribute!("open")
    page |> Page.locator("#my-modal") |> Expect.to_be_hidden!()
  end

  test "ignore_attributes", %{page: page} do
    Page.goto!(page, "/js")
    sync_lv(page)
    page |> Page.locator("details") |> Expect.not_() |> Expect.to_have_attribute!("open")
    page |> Page.locator("details") |> Locator.click!()
    page |> Page.locator("details") |> Expect.to_have_attribute!("open")
    # without ignore_attributes, the open attribute would be reset to false
    page |> Page.locator("details button") |> Locator.click!()
    sync_lv(page)
    page |> Page.locator("details") |> Expect.to_have_attribute!("open")
  end
end
