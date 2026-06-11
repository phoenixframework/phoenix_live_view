defmodule Phoenix.Component.QuotedTemplateTest do
  # async: false because the colocated hook tests read/write a shared folder
  use ExUnit.Case, async: false

  import Phoenix.LiveViewTest

  defmodule Builder do
    use Phoenix.Component

    defmacro build_tag(opts) do
      name = Keyword.fetch!(opts, :name)
      class = Keyword.get(opts, :class, "default")

      template =
        Phoenix.Component.quoted(~H"""
        <div class={unquote(class)} id={@id}>{@inner}</div>
        """)

      quote do
        def unquote(name)(var!(assigns)), do: unquote(template)
      end
    end

    defmacro build_with_assign_splice(name, assign_name) do
      # splice AST referencing an assign, as if it was written in the template
      hole = {:@, [], [{assign_name, [], nil}]}

      template =
        Phoenix.Component.quoted(~H"""
        <div id={@id} class={unquote(hole)}></div>
        """)

      quote do
        def unquote(name)(var!(assigns)), do: unquote(template)
      end
    end

    defmacro build_with_root_attrs(name, attrs) do
      template =
        Phoenix.Component.quoted(~H"""
        <div {unquote(attrs)}></div>
        """)

      quote do
        def unquote(name)(var!(assigns)), do: unquote(template)
      end
    end

    defmacro build_with_component_call(name) do
      template =
        Phoenix.Component.quoted(~H"""
        <.inner label={unquote("from macro")} />
        """)

      quote do
        def unquote(name)(var!(assigns)), do: unquote(template)
      end
    end

    defmacro build_with_hook(opts) do
      name = Keyword.fetch!(opts, :name)
      hook_name = Keyword.fetch!(opts, :hook_name)

      template =
        Phoenix.Component.quoted(~H"""
        <div id={@id} phx-hook={unquote(hook_name)}></div>
        <script :type={Phoenix.LiveView.ColocatedHook} name={unquote(hook_name)}>
          export default {
            mounted() {
              this.el.textContent = "from quoted";
            },
          };
        </script>
        """)

      quote do
        def unquote(name)(var!(assigns)), do: unquote(template)
      end
    end

    defmacro build_static_attr(name, value) do
      template =
        Phoenix.Component.quoted(~H"""
        <div title={unquote(value)} id={@id}></div>
        """)

      quote do
        def unquote(name)(var!(assigns)), do: unquote(template)
      end
    end
  end

  defmodule Tags do
    use Phoenix.Component
    require Builder

    Builder.build_tag(name: :card, class: "card")
    Builder.build_tag(name: :badge, class: "badge")
  end

  defmodule Tracked do
    use Phoenix.Component
    require Builder

    Builder.build_with_assign_splice(:dyn, :extra)
  end

  describe "value splicing" do
    test "splices compile-time values into attributes" do
      assert rendered_to_string(Tags.card(%{id: "a", inner: "hi"})) ==
               ~s(<div class="card" id="a">hi</div>)

      assert rendered_to_string(Tags.badge(%{id: "b", inner: "ho"})) ==
               ~s(<div class="badge" id="b">ho</div>)
    end

    test "spliced values are HTML escaped" do
      defmodule Evil do
        use Phoenix.Component
        require Builder

        Builder.build_tag(name: :evil, class: "\"><script>alert(1)</script>")
      end

      assert rendered_to_string(Evil.evil(%{id: "x", inner: "hi"})) ==
               "<div class=\"&quot;&gt;&lt;script&gt;alert(1)&lt;/script&gt;\" id=\"x\">hi</div>"
    end

    test "splices keyword lists into root attributes" do
      defmodule RootAttrs do
        use Phoenix.Component
        require Builder

        Builder.build_with_root_attrs(:static_root, class: "fixed", id: "root")
      end

      assert rendered_to_string(RootAttrs.static_root(%{})) =~ ~s(class="fixed")
      assert rendered_to_string(RootAttrs.static_root(%{})) =~ ~s(id="root")
    end

    test "calls components resolved in the caller context" do
      defmodule WithComponentCall do
        use Phoenix.Component
        require Builder

        def inner(assigns), do: ~H"<span>{@label}</span>"

        Builder.build_with_component_call(:outer)
      end

      assert rendered_to_string(WithComponentCall.outer(%{})) == "<span>from macro</span>"
    end
  end

  describe "change tracking" do
    test "spliced AST takes part in change tracking" do
      rendered = Tracked.dyn(%{id: "a", extra: "one", __changed__: nil})
      assert Enum.to_list(rendered.dynamic.(true)) == [[" id=\"", "a", 34], "one"]

      rendered = Tracked.dyn(%{id: "a", extra: "two", __changed__: %{extra: true}})
      assert Enum.to_list(rendered.dynamic.(true)) == [nil, "two"]

      rendered = Tracked.dyn(%{id: "b", extra: "two", __changed__: %{id: true}})
      assert Enum.to_list(rendered.dynamic.(true)) == [[" id=\"", "b", 34], nil]
    end

    test "spliced literals are inlined as escaped static parts" do
      defmodule StaticAttr do
        use Phoenix.Component
        require Builder

        Builder.build_static_attr(:titled, "say \"hi\"")
      end

      rendered = StaticAttr.titled(%{id: "a", __changed__: nil})
      # the title attribute is inlined, so only @id is dynamic,
      # exactly as for a handwritten title={"..."}
      assert length(Enum.to_list(rendered.dynamic.(true))) == 1
      assert hd(rendered.static) == "<div title=\"say &quot;hi&quot;\""
    end
  end

  describe "colocated hooks" do
    test "are extracted into the caller's application" do
      defmodule WithHook do
        use Phoenix.Component
        require Builder

        Builder.build_with_hook(name: :widget, hook_name: ".QuotedWidget")
      end

      # the relative hook name resolves against the caller module
      assert rendered_to_string(WithHook.widget(%{id: "w"})) =~
               ~s(phx-hook="Phoenix.Component.QuotedTemplateTest.WithHook.QuotedWidget")

      base = Path.join(Mix.Project.build_path(), "phoenix-colocated/phoenix_live_view")

      assert folder =
               base
               |> File.ls!()
               |> Enum.find(&(&1 =~ "Phoenix.Component.QuotedTemplateTest.WithHook"))

      assert [script] = Path.wildcard(Path.join(base, "#{folder}/*.js"))
      assert File.read!(script) =~ "from quoted"
    after
      :code.delete(__MODULE__.WithHook)
      :code.purge(__MODULE__.WithHook)
    end
  end

  describe "errors" do
    test "raises on unquote inside EEx block expressions" do
      assert_raise Phoenix.LiveView.TagEngine.Tokenizer.ParseError,
                   ~r/unquote is not supported inside <% %> expressions/,
                   fn ->
                     defmodule EExBlockHole do
                       use Phoenix.Component

                       defmacro bad(cond_ast) do
                         Phoenix.Component.quoted(~H"""
                         <%= if unquote(cond_ast) do %>
                           <div>hi</div>
                         <% end %>
                         """)
                       end
                     end
                   end
    end

    test "raises when the argument is not a ~H sigil" do
      assert_raise ArgumentError,
                   ~r/expects a ~H template without interpolation/,
                   fn ->
                     defmodule NotASigil do
                       use Phoenix.Component

                       defmacro bad do
                         Phoenix.Component.quoted("<div></div>")
                       end
                     end
                   end
    end

    test "raises when no assigns variable is in scope at the use site" do
      assert_raise RuntimeError,
                   ~r/quoted templates require a variable named "assigns"/,
                   fn ->
                     defmodule NoAssigns do
                       use Phoenix.Component

                       defmacro bad_def(name) do
                         template = Phoenix.Component.quoted(~H"<div></div>")

                         quote do
                           def unquote(name)(_other_name), do: unquote(template)
                         end
                       end
                     end

                     defmodule NoAssignsUser do
                       use Phoenix.Component
                       require NoAssigns
                       NoAssigns.bad_def(:broken)
                     end
                   end
    end

    test "raises on invalid HTML when the macro is defined" do
      assert_raise Phoenix.LiveView.TagEngine.Tokenizer.ParseError,
                   ~r/unmatched closing tag/,
                   fn ->
                     defmodule BadHtml do
                       use Phoenix.Component

                       defmacro bad do
                         Phoenix.Component.quoted(~H"<div></span>"noformat)
                       end
                     end
                   end
    end
  end
end
