defmodule Phoenix.Component.ChangeTrackBodyTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  defmodule Lookalike.Component do
    @doc "Not Phoenix.Component.assign/3: it also reads assigns.suffix"
    def assign(assigns, key, value) do
      Phoenix.Component.assign(assigns, key, "#{value}-#{assigns.suffix}")
    end
  end

  defmodule Components do
    use Phoenix.Component

    @base_class "rounded"

    change_track_body(true)

    def step(assigns) do
      assigns =
        cond do
          assigns.error? -> assign(assigns, bg: "bg-destructive", number: "!")
          assigns.current_scope.subscribed? -> assign(assigns, bg: "bg-success", number: "ok")
          true -> assign(assigns, bg: "bg-primary", number: "1")
        end

      ~H"<div class={@bg}>{@number}</div><h2>{@title}</h2>"
    end

    change_track_body(true)

    def two_statements(assigns) do
      assigns = assign(assigns, :a, assigns.x + 1)
      assigns = assign(assigns, :b, assigns.y + 1)
      ~H"{@a}|{@b}|{@z}"
    end

    change_track_body(true)

    def chained(assigns) do
      assigns = assign(assigns, :a, assigns.x + 1)
      assigns = assign(assigns, :b, assigns.a + 1)
      ~H"{@a}|{@b}|{@z}"
    end

    change_track_body(true)

    def piped(assigns) do
      assigns =
        assigns
        |> assign(:a, assigns.x + 1)
        |> assign(:b, assigns.x + 2)

      ~H"{@a}|{@b}|{@z}"
    end

    change_track_body(true)

    def module_attribute(assigns) do
      assigns = assign(assigns, :class, [@base_class, assigns.extra])
      ~H"{@class}|{@z}"
    end

    change_track_body(false)

    def opted_out(assigns) do
      assigns = assign(assigns, :a, assigns.x + 1)
      ~H"{@a}|{@z}"
    end

    def never_opted_in(assigns) do
      assigns = assign(assigns, :a, assigns.x + 1)
      ~H"{@a}|{@z}"
    end

    alias Phoenix.Component, as: PC

    change_track_body(true)

    def aliased(assigns) do
      assigns = assigns |> PC.assign(:a, assigns.x) |> PC.assign(:b, assigns.x)
      ~H"{@a}|{@b}|{@z}"
    end
  end

  defmodule ModuleDefault do
    use Phoenix.Component, change_track_body: true

    def tracked(assigns) do
      assigns = assign(assigns, :v, assigns.x + 1)
      ~H"{@v}|{@z}"
    end

    change_track_body(false)

    def opted_out(assigns) do
      assigns = assign(assigns, :v, assigns.x + 1)
      ~H"{@v}|{@z}"
    end

    # not components: the module wide default must leave these alone
    def helper(a, b), do: a + b
    def zero_arity, do: :ok

    # single argument named assigns, but receives a %Phoenix.LiveView.Socket{},
    # which carries no __changed__ at all
    def socket_taking(assigns) do
      assigns = assign(assigns, :v, 123)
      assigns
    end
  end

  defmodule LiveViewDefault do
    use Phoenix.LiveView, change_track_body: true

    def render(assigns) do
      assigns = assign(assigns, :v, assigns.x + 1)
      ~H"{@v}|{@z}"
    end

    def mount(_params, _session, socket), do: {:ok, socket}
  end

  # the standard Phoenix `use MyAppWeb, :html` indirection
  defmodule Web do
    defmacro __using__(which) when is_atom(which), do: apply(__MODULE__, which, [])

    def html do
      quote do
        use Phoenix.Component, change_track_body: true
      end
    end
  end

  defmodule WebHTML do
    use Web, :html

    def card(assigns) do
      assigns = assign(assigns, :v, assigns.x + 1)
      ~H"{@v}|{@z}"
    end
  end

  defmodule LiveComponentDefault do
    use Phoenix.LiveComponent, change_track_body: true

    def render(assigns) do
      assigns = assign(assigns, :v, assigns.x + 1)
      ~H"{@v}|{@z}"
    end
  end

  # Defining a component whose body cannot be change tracked warns on purpose, so
  # it must be compiled inside the test rather than when this file is loaded.
  defp compile_component(body) do
    name = "ChangeTrackBodyFixture#{System.unique_integer([:positive])}"

    warning =
      capture_io(:stderr, fn ->
        Code.eval_string("""
        defmodule #{name} do
          use Phoenix.Component
          alias Phoenix.Component.ChangeTrackBodyTest.Lookalike
          #{body}
        end
        """)
      end)

    {Module.concat([name]), warning}
  end

  defp dynamic(mod, fun, assigns, changed) do
    %{dynamic: dynamic} = apply(mod, fun, [Map.put(assigns, :__changed__, changed)])
    dynamic.(true)
  end

  defp dynamic(fun, assigns, changed) do
    %{dynamic: dynamic} = apply(Components, fun, [Map.put(assigns, :__changed__, changed)])
    dynamic.(true)
  end

  describe "change tracking of the component body" do
    test "does not mark assigns as changed when no dependency changed" do
      assigns = %{error?: false, current_scope: %{subscribed?: false}, title: "Step"}

      assert [nil, nil, "Step"] = dynamic(:step, assigns, %{title: true})
    end

    test "marks assigns as changed when a dependency changed" do
      assigns = %{error?: true, current_scope: %{subscribed?: false}, title: "Step"}

      assert ["bg-destructive", "!", nil] = dynamic(:step, assigns, %{error?: true})
    end

    test "tracks nested dependencies" do
      assigns = %{error?: false, current_scope: %{subscribed?: true}, title: "Step"}

      assert ["bg-success", "ok", nil] = dynamic(:step, assigns, %{current_scope: true})
    end

    test "computes everything on the first render" do
      assigns = %{error?: false, current_scope: %{subscribed?: false}, title: "Step"}

      assert ["bg-primary", "1", "Step"] = dynamic(:step, assigns, nil)
    end

    test "statements do not clobber each other" do
      assigns = %{x: 1, y: 1, z: "z"}

      assert ["2", nil, nil] = dynamic(:two_statements, assigns, %{x: true})
      assert [nil, "2", nil] = dynamic(:two_statements, assigns, %{y: true})
      assert [nil, nil, "z"] = dynamic(:two_statements, assigns, %{z: true})
    end

    test "a statement depends on assigns computed by an earlier statement" do
      assigns = %{x: 1, z: "z"}

      assert ["2", "3", nil] = dynamic(:chained, assigns, %{x: true})
      assert [nil, nil, "z"] = dynamic(:chained, assigns, %{z: true})
    end

    test "tracks assigns threaded through a pipeline" do
      assigns = %{x: 1, z: "z"}

      assert ["2", "3", nil] = dynamic(:piped, assigns, %{x: true})
      assert [nil, nil, "z"] = dynamic(:piped, assigns, %{z: true})
    end
  end

  describe "module attributes" do
    test "keep their regular meaning inside the body" do
      assigns = %{extra: "x", z: "z"}

      assert [["rounded", "x"], nil] = dynamic(:module_attribute, assigns, %{extra: true})
      assert [nil, "z"] = dynamic(:module_attribute, assigns, %{z: true})
    end
  end

  describe "resolving assign/2,3" do
    test "tracks Phoenix.Component aliased under another name, including in a pipe" do
      assert [nil, nil, "z"] = dynamic(:aliased, %{x: 1, z: "z"}, %{z: true})
      assert ["1", "1", nil] = dynamic(:aliased, %{x: 1, z: "z"}, %{x: true})
    end

    test "does not thread through a look-alike module that only ends in Component" do
      {module, warning} =
        compile_component("""
        change_track_body true

        def c(assigns) do
          assigns = Lookalike.Component.assign(assigns, :a, assigns.x)
          ~H"{@a}|{@z}"
        end
        """)

      assert warning =~ "cannot be change tracked"

      # Lookalike.Component.assign/3 also reads assigns.suffix, so treating its
      # first argument as a threading position would silently under-track it
      assert ["1-B", nil] = dynamic(module, :c, %{x: 1, suffix: "B", z: "z"}, %{suffix: true})
    end
  end

  describe "module wide default" do
    test "use Phoenix.Component, change_track_body: true tracks every component" do
      assert [nil, "z"] = dynamic(ModuleDefault, :tracked, %{x: 1, z: "z"}, %{z: true})
      assert ["2", nil] = dynamic(ModuleDefault, :tracked, %{x: 1, z: "z"}, %{x: true})
    end

    test "change_track_body false overrides the module wide default" do
      assert ["2", "z"] = dynamic(ModuleDefault, :opted_out, %{x: 1, z: "z"}, %{z: true})
    end

    test "leaves definitions that are not components alone" do
      assert ModuleDefault.helper(1, 2) == 3
      assert ModuleDefault.zero_arity() == :ok
    end

    test "degrades on a single argument function that carries no __changed__" do
      socket = %Phoenix.LiveView.Socket{}

      assert ModuleDefault.socket_taking(socket).assigns[:v] == 123
    end

    test "use Phoenix.LiveView, change_track_body: true reaches render/1" do
      assert [nil, "z"] = dynamic(LiveViewDefault, :render, %{x: 1, z: "z"}, %{z: true})
      assert ["2", nil] = dynamic(LiveViewDefault, :render, %{x: 1, z: "z"}, %{x: true})
    end

    test "survives the use MyAppWeb, :html indirection" do
      assert [nil, "z"] = dynamic(WebHTML, :card, %{x: 1, z: "z"}, %{z: true})
      assert ["2", nil] = dynamic(WebHTML, :card, %{x: 1, z: "z"}, %{x: true})
    end

    test "use Phoenix.LiveComponent, change_track_body: true reaches render/1" do
      assert [nil, "z"] = dynamic(LiveComponentDefault, :render, %{x: 1, z: "z"}, %{z: true})
    end

    test "rejects a non boolean option" do
      assert_raise ArgumentError, ~r/:change_track_body expects a boolean literal/, fn ->
        Code.eval_string("""
        defmodule Invalid#{System.unique_integer([:positive])} do
          use Phoenix.Component, change_track_body: "yes"
        end
        """)
      end
    end
  end

  describe "opting out" do
    test "change_track_body false leaves the body alone" do
      assert ["2", "z"] = dynamic(:opted_out, %{x: 1, z: "z"}, %{z: true})
    end

    test "a component that never opted in is left alone" do
      assert ["2", "z"] = dynamic(:never_opted_in, %{x: 1, z: "z"}, %{z: true})
    end
  end

  describe "expressions that cannot be tracked" do
    defp compile(body) do
      {_module, warning} =
        compile_component("""
        change_track_body true

        def c(assigns) do
          #{body}
          ~H"{@v}|{@z}"
        end
        """)

      warning
    end

    test "warns and stays correct when the expression reads a variable" do
      warning = compile("extra = 10\n    assigns = assign(assigns, :v, assigns.count + extra)")

      assert warning =~ "cannot be change tracked"
      assert warning =~ "reads a variable"
    end

    test "warns when assigns is passed to another function" do
      warning = compile("assigns = assign(assigns, :v, Map.get(assigns, :count))")

      assert warning =~ "cannot be change tracked"
    end

    test "does not warn when the expression is tracked" do
      refute compile("assigns = assign(assigns, :v, assigns.count + 1)") =~
               "cannot be change tracked"
    end
  end

  describe "validation" do
    test "raises when used on something that is not a function component" do
      assert_raise ArgumentError, ~r/can only be used on a function component/, fn ->
        Code.eval_string("""
        defmodule Invalid#{System.unique_integer([:positive])} do
          use Phoenix.Component

          change_track_body true

          def not_a_component(a, b), do: a + b
        end
        """)
      end
    end
  end
end
