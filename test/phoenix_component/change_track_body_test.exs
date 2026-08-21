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
    alias Phoenix.Component.ChangeTrackBodyTest.Lookalike

    change_track_body(true)

    def aliased(assigns) do
      assigns = assigns |> PC.assign(:a, assigns.x) |> PC.assign(:b, assigns.x)
      ~H"{@a}|{@b}|{@z}"
    end

    change_track_body(true)

    def lookalike(assigns) do
      assigns = Lookalike.Component.assign(assigns, :a, assigns.x)
      ~H"{@a}|{@z}"
    end
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
      # Lookalike.Component.assign/3 reads assigns.suffix, so treating its first
      # argument as a threading position would silently under-track it
      assigns = %{x: 1, suffix: "B", z: "z"}

      assert ["1-B", nil] = dynamic(:lookalike, assigns, %{suffix: true})
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
      capture_io(:stderr, fn ->
        Code.eval_string("""
        defmodule Test#{System.unique_integer([:positive])} do
          use Phoenix.Component

          change_track_body true

          def c(assigns) do
            #{body}
            ~H"{@v}|{@z}"
          end
        end
        """)
      end)
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
