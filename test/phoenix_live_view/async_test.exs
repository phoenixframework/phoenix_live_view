defmodule Phoenix.LiveView.AsyncTest do
  # run with async: false to prevent other messages from being captured
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  describe "async operations" do
    for fun <- [:assign_async, :start_async] do
      test "warns when passing socket to #{fun} function" do
        warnings =
          capture_io(:stderr, fn ->
            Code.eval_string("""
            defmodule AssignAsyncSocket do
              use Phoenix.LiveView

              def mount(_params, _session, socket) do
                {:ok, #{unquote(fun)}(socket, :foo, fn ->
                  do_something(socket.assigns)
                end)}
              end

              defp do_something(_socket), do: :ok
            end
            """)
          end)

        assert warnings =~
                 "you are accessing the LiveView Socket inside a function given to #{unquote(fun)}"
      end

      test "does not warn when accessing socket outside of function passed to #{fun}" do
        warnings =
          capture_io(:stderr, fn ->
            Code.eval_string("""
            defmodule AssignAsyncSocket do
              use Phoenix.LiveView

              def mount(_params, _session, socket) do
                socket = assign(socket, :foo, :bar)
                foo = socket.assigns.foo

                {:ok, #{unquote(fun)}(socket, :foo, fn ->
                  do_something(foo)
                end)}
              end

              defp do_something(assigns), do: :ok
            end
            """)
          end)

        refute warnings =~
                 "you are accessing the LiveView Socket inside a function given to #{unquote(fun)}"
      end

      test "does not warn when argument is not a function (#{fun})" do
        warnings =
          capture_io(:stderr, fn ->
            Code.eval_string("""
            defmodule AssignAsyncSocket do
              use Phoenix.LiveView

              def mount(_params, _session, socket) do
                socket = assign(socket, :foo, :bar)

                {:ok, #{unquote(fun)}(socket, :foo, function_that_returns_the_func(socket))}
              end

              defp function_that_returns_the_func(socket) do
                foo = socket.assigns.foo

                fn ->
                  do_something(foo)
                end
              end

              defp do_something(assigns), do: :ok
            end
            """)
          end)

        refute warnings =~
                 "you are accessing the LiveView Socket inside a function given to #{unquote(fun)}"
      end
    end
  end
end
