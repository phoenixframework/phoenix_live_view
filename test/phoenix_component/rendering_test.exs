defmodule Phoenix.ComponentRenderingTest do
  use ExUnit.Case, async: true
  use Phoenix.Component

  import ExUnit.CaptureIO
  import Phoenix.LiveViewTest

  embed_templates "pages/*"
  embed_templates "another_root/*.html", root: "pages"
  embed_templates "another_root/*.text", root: "pages", suffix: "_text"

  defp h2s(template) do
    template
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  defp hello(assigns) do
    assigns = assign_new(assigns, :name, fn -> "World" end)

    ~H"""
    Hello {@name}
    """
  end

  describe "rendering" do
    test "renders component" do
      assigns = %{}

      assert h2s(~H"""
             <.hello name="WORLD" />
             """) == """
             Hello WORLD\
             """
    end
  end

  describe "embed_templates" do
    attr :name, :string, default: "chris"
    def welcome_page(assigns)

    test "embed from directory pattern" do
      # generic template
      assert render_component(&about_page/1) == "About us"

      # root
      assert render_component(&root/1) == "root!"
      assert Phoenix.Template.render(__MODULE__, "root_text", "text", []) == "root plain text!\n"

      # attr'd bodyless definition
      assert render_component(&welcome_page/1) == "Welcome chris"
    end
  end

  describe "testing" do
    test "render_component/1" do
      assert render_component(&hello/1) == "Hello World"
      assert render_component(&hello/1, name: "WORLD!") == "Hello WORLD!"
    end
  end

  describe "change tracking" do
    defp eval(%Phoenix.LiveView.Rendered{dynamic: dynamic}), do: Enum.map(dynamic.(true), &eval/1)
    defp eval(other), do: other

    def changed(assigns) do
      ~H"""
      {inspect(Map.get(assigns, :__changed__), custom_options: [sort_maps: true])}
      """
    end

    test "without changed assigns on root" do
      assigns = %{foo: 1}
      assert eval(~H"<.changed foo={@foo} />") == [["nil"]]
    end

    @compile {:no_warn_undefined, __MODULE__.Tainted}

    test "with tainted variable" do
      assert capture_io(:stderr, fn ->
               defmodule Tainted do
                 def run(assigns) do
                   foo = 1
                   ~H"<Phoenix.ComponentRenderingTest.changed foo={foo} />"
                 end
               end
             end) =~ "you are accessing the variable \"foo\" inside a LiveView template"

      assert eval(__MODULE__.Tainted.run(%{foo: 1})) == [["nil"]]
      assert eval(__MODULE__.Tainted.run(%{foo: 1, __changed__: %{}})) == [["%{foo: true}"]]
    end

    test "with changed assigns on root" do
      assigns = %{foo: 1, __changed__: %{}}
      assert eval(~H"<.changed foo={@foo} />") == [nil]

      assigns = %{foo: 1, __changed__: %{bar: true}}
      assert eval(~H"<.changed foo={@foo} />") == [nil]

      assigns = %{foo: 1, __changed__: %{foo: true}}
      assert eval(~H"<.changed foo={@foo} />") == [["%{foo: true}"]]

      assigns = %{foo: 1, __changed__: %{foo: %{bar: true}}}
      assert eval(~H"<.changed foo={@foo} />") == [["%{foo: %{bar: true}}"]]
    end

    test "with changed assigns on map" do
      assigns = %{foo: %{bar: :bar}, __changed__: %{}}
      assert eval(~H"<.changed foo={@foo.bar} />") == [nil]

      assigns = %{foo: %{bar: :bar}, __changed__: %{bar: true}}
      assert eval(~H"<.changed foo={@foo.bar} />") == [nil]

      assigns = %{foo: %{bar: :bar}, __changed__: %{foo: true}}
      assert eval(~H"<.changed foo={@foo.bar} />") == [["%{foo: true}"]]

      assigns = %{foo: %{bar: :bar}, __changed__: %{foo: %{bar: :bar}}}
      assert eval(~H"<.changed foo={@foo.bar} />") == [nil]

      assigns = %{foo: %{bar: :bar}, __changed__: %{foo: %{bar: :baz}}}
      assert eval(~H"<.changed foo={@foo.bar} />") == [["%{foo: true}"]]

      assigns = %{foo: %{bar: %{bar: :bar}}, __changed__: %{foo: %{bar: %{bar: :bat}}}}
      assert eval(~H"<.changed foo={@foo.bar} />") == [["%{foo: %{bar: :bat}}"]]
    end

    test "with multiple changed assigns" do
      assigns = %{foo: 1, bar: 2, __changed__: %{}}
      assert eval(~H"<.changed foo={@foo + @bar} />") == [nil]

      assigns = %{foo: 1, bar: 2, __changed__: %{bar: true}}
      assert eval(~H"<.changed foo={@foo + @bar} />") == [["%{foo: true}"]]

      assigns = %{foo: 1, bar: 2, __changed__: %{foo: true}}
      assert eval(~H"<.changed foo={@foo + @bar} />") == [["%{foo: true}"]]

      assigns = %{foo: 1, bar: 2, __changed__: %{baz: true}}
      assert eval(~H"<.changed foo={@foo + @bar} />") == [nil]
    end

    test "with multiple keys" do
      assigns = %{foo: 1, bar: 2, __changed__: %{}}
      assert eval(~H"<.changed foo={@foo} bar={@bar} />") == [nil]

      assigns = %{foo: 1, bar: 2, __changed__: %{bar: true}}
      assert eval(~H"<.changed foo={@foo} bar={@bar} />") == [["%{bar: true}"]]

      assigns = %{foo: 1, bar: 2, __changed__: %{foo: true}}
      assert eval(~H"<.changed foo={@foo} bar={@bar} />") == [["%{foo: true}"]]

      assigns = %{foo: 1, bar: 2, __changed__: %{baz: true}}
      assert eval(~H"<.changed foo={@foo} bar={@bar} />") == [nil]
    end

    test "with multiple keys and one is static" do
      assigns = %{foo: 1, __changed__: %{}}
      assert eval(~H|<.changed foo={@foo} bar="2" />|) == [nil]

      assigns = %{foo: 1, __changed__: %{bar: true}}
      assert eval(~H|<.changed foo={@foo} bar="2" />|) == [nil]

      assigns = %{foo: 1, __changed__: %{foo: true}}
      assert eval(~H|<.changed foo={@foo} bar="2" />|) == [["%{foo: true}"]]
    end

    test "with multiple keys and one is tainted" do
      assigns = %{foo: 1, __changed__: %{}}
      assert eval(~H|<.changed foo={@foo} bar={assigns} />|) == [["%{bar: true}"]]

      assigns = %{foo: 1, __changed__: %{foo: true}}
      assert eval(~H|<.changed foo={@foo} bar={assigns} />|) == [["%{bar: true, foo: true}"]]
    end

    test "with conflict on changed assigns" do
      assigns = %{foo: 1, bar: %{foo: 2}, __changed__: %{}}
      assert eval(~H"<.changed foo={@foo} {@bar} />") == [nil]

      # we cannot perform any change tracking when dynamic assigns are involved
      assigns = %{foo: 1, bar: %{foo: 2}, __changed__: %{bar: true}}
      assert eval(~H"<.changed foo={@foo} {@bar} />") == [["nil"]]

      assigns = %{foo: 1, bar: %{foo: 2}, __changed__: %{foo: true}}
      assert eval(~H"<.changed foo={@foo} {@bar} />") == [["nil"]]

      assigns = %{foo: 1, bar: %{foo: 2}, baz: 3, __changed__: %{baz: true}}
      assert eval(~H"<.changed foo={@foo} {@bar} baz={@baz} />") == [["nil"]]
    end

    test "with dynamic assigns" do
      assigns = %{foo: %{a: 1, b: 2}, __changed__: %{}}
      assert eval(~H"<.changed {@foo} />") == [nil]

      # we cannot perform any change tracking when dynamic assigns are involved
      assigns = %{foo: %{a: 1, b: 2}, __changed__: %{foo: true}}
      assert eval(~H"<.changed {@foo} />") == [["nil"]]

      assigns = %{foo: %{a: 1, b: 2}, bar: 3, __changed__: %{bar: true}}
      assert eval(~H"<.changed {@foo} bar={@bar} />") == [["nil"]]

      assigns = %{foo: %{a: 1, b: 2}, bar: 3, __changed__: %{bar: true}}
      assert eval(~H"<.changed {%{a: 1, b: 2}} bar={@bar} />") == [["nil"]]

      assigns = %{bar: 3, __changed__: %{bar: true}}

      assert eval(~H"<.changed {%{a: assigns[:b], b: assigns[:a]}} bar={@bar} />") ==
               [["nil"]]

      assigns = %{a: 1, b: 2, bar: 3, __changed__: %{a: true, b: true, bar: true}}

      assert eval(~H"<.changed {%{a: assigns[:b], b: assigns[:a]}} bar={@bar} />") ==
               [["nil"]]
    end

    defp wrapper(assigns) do
      ~H"""
      <div>{render_slot(@inner_block)}</div>
      """
    end

    defp inner_changed(assigns) do
      ~H"""
      {inspect(Map.get(assigns, :__changed__), custom_options: [sort_maps: true])}
      {render_slot(@inner_block, "var")}
      """
    end

    test "with @inner_block" do
      assigns = %{foo: 1, __changed__: %{}}
      assert eval(~H|<.inner_changed foo={@foo}></.inner_changed>|) == [nil]
      assert eval(~H|<.inner_changed>{@foo}</.inner_changed>|) == [nil]

      assigns = %{foo: 1, __changed__: %{foo: true}}

      assert eval(~H|<.inner_changed foo={@foo}></.inner_changed>|) ==
               [["%{foo: true}", nil]]

      assert eval(
               ~H|<.inner_changed foo={@foo}>{inspect(Map.get(assigns, :__changed__))}</.inner_changed>|
             ) ==
               [["%{foo: true, inner_block: true}", ["%{foo: true}"]]]

      assert eval(~H|<.inner_changed>{@foo}</.inner_changed>|) ==
               [["%{inner_block: true}", ["1"]]]

      assigns = %{foo: 1, __changed__: %{foo: %{bar: true}}}

      assert eval(~H|<.inner_changed foo={@foo}></.inner_changed>|) ==
               [["%{foo: %{bar: true}}", nil]]

      assert eval(
               ~H|<.inner_changed foo={@foo}>{inspect(Map.get(assigns, :__changed__))}</.inner_changed>|
             ) ==
               [["%{foo: %{bar: true}, inner_block: true}", ["%{foo: %{bar: true}}"]]]

      assert eval(~H|<.inner_changed>{@foo}</.inner_changed>|) ==
               [["%{inner_block: %{bar: true}}", ["1"]]]
    end

    test "with let" do
      assigns = %{foo: 1, __changed__: %{}}
      assert eval(~H|<.inner_changed :let={_foo} foo={@foo}></.inner_changed>|) == [nil]

      assigns = %{foo: 1, __changed__: %{foo: true}}

      assert eval(~H|<.inner_changed :let={_foo} foo={@foo}></.inner_changed>|) ==
               [["%{foo: true}", nil]]

      assert eval(~H"""
             <.inner_changed :let={_foo} foo={@foo}>
               {inspect(Map.get(assigns, :__changed__))}
             </.inner_changed>
             """) ==
               [["%{foo: true, inner_block: true}", ["%{foo: true}"]]]

      assert eval(~H"""
             <.inner_changed :let={_foo} foo={@foo}>
               {"constant"}{inspect(Map.get(assigns, :__changed__))}
             </.inner_changed>
             """) ==
               [["%{foo: true, inner_block: true}", [nil, "%{foo: true}"]]]

      assert eval(~H"""
             <.inner_changed :let={foo} foo={@foo}>
               <.inner_changed :let={_bar} bar={foo}>
                 {"constant"}{inspect(Map.get(assigns, :__changed__))}
               </.inner_changed>
             </.inner_changed>
             """) ==
               [
                 [
                   "%{foo: true, inner_block: true}",
                   [["%{bar: true, inner_block: true}", [nil, "%{foo: true}"]]]
                 ]
               ]

      assert eval(~H"""
             <.inner_changed :let={foo} foo={@foo}>
               {foo}{inspect(Map.get(assigns, :__changed__))}
             </.inner_changed>
             """) ==
               [["%{foo: true, inner_block: true}", ["var", "%{foo: true}"]]]

      assert eval(~H"""
             <.inner_changed :let={foo} foo={@foo}>
               <.inner_changed :let={bar} bar={foo}>
                 {bar}{inspect(Map.get(assigns, :__changed__))}
               </.inner_changed>
             </.inner_changed>
             """) ==
               [
                 [
                   "%{foo: true, inner_block: true}",
                   [["%{bar: true, inner_block: true}", ["var", "%{foo: true}"]]]
                 ]
               ]
    end

    test "with :let inside @inner_block" do
      assigns = %{foo: 1, bar: 2, __changed__: %{foo: true}}

      assert eval(~H"""
             <.wrapper>
               {@foo}
               <.inner_changed :let={var} foo={@bar}>
                 {var}
               </.inner_changed>
             </.wrapper>
             """) == [[["1", nil]]]
    end

    defp optional_wrapper(assigns) do
      assigns = assign_new(assigns, :inner_block, fn -> [] end)

      ~H"""
      <div>{render_slot(@inner_block) || "DEFAULT!"}</div>
      """
    end

    test "with optional @inner_block" do
      assigns = %{foo: 1}

      assert eval(~H"""
             <.optional_wrapper>
               {@foo}
             </.optional_wrapper>
             """) == [[["1"]]]

      assigns = %{foo: 2, __changed__: %{foo: true}}

      assert eval(~H"""
             <.optional_wrapper>
               {@foo}
             </.optional_wrapper>
             """) == [[["2"]]]

      assigns = %{foo: 3}

      assert eval(~H"""
             <.optional_wrapper />
             """) == [["DEFAULT!"]]
    end
  end
end
