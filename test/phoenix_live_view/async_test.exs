defmodule Phoenix.LiveView.AsyncTest do
  # run with async: false to prevent other messages from being captured
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  describe "async operations - eval_quoted" do
    for fun <- [:assign_async, :start_async, :stream_async] do
      test "warns when passing socket to #{fun} function" do
        warnings =
          capture_io(:stderr, fn ->
            fun = unquote(fun)

            Code.eval_quoted(
              quote do
                require Phoenix.LiveView

                socket = %Phoenix.LiveView.Socket{
                  assigns: %{__changed__: %{}, bar: :baz},
                  private: %{lifecycle: %Phoenix.LiveView.Lifecycle{}}
                }

                Phoenix.LiveView.unquote(fun)(socket, :foo, fn ->
                  socket.assigns.bar
                end)
              end
            )
          end)

        assert warnings =~
                 "you are accessing the LiveView Socket inside a function given to #{unquote(fun)}"
      end

      test "does not warn when accessing socket outside of function passed to #{fun}" do
        warnings =
          capture_io(:stderr, fn ->
            fun = unquote(fun)

            Code.eval_quoted(
              quote do
                require Phoenix.LiveView

                socket = %Phoenix.LiveView.Socket{
                  assigns: %{__changed__: %{}, bar: :baz},
                  private: %{lifecycle: %Phoenix.LiveView.Lifecycle{}}
                }

                bar = socket.assigns.bar

                Phoenix.LiveView.unquote(fun)(socket, :foo, fn ->
                  bar
                end)
              end
            )
          end)

        refute warnings =~
                 "you are accessing the LiveView Socket inside a function given to #{unquote(fun)}"
      end
    end
  end

  describe "async operations" do
    for fun <- [:assign_async, :start_async, :stream_async] do
      test "warns when passing socket to #{fun} function", %{test: test} do
        warnings =
          capture_io(:stderr, fn ->
            defmodule Module.concat(AssignAsyncSocket, "Test#{:erlang.phash2(test)}") do
              use Phoenix.LiveView

              def mount(_params, _session, socket) do
                {:ok,
                 unquote(fun)(socket, :foo, fn ->
                   do_something(socket.assigns)
                 end)}
              end

              defp do_something(_socket), do: :ok
            end
          end)

        assert warnings =~
                 "you are accessing the LiveView Socket inside a function given to #{unquote(fun)}"
      end

      test "does not warn when accessing socket outside of function passed to #{fun}", %{
        test: test
      } do
        warnings =
          capture_io(:stderr, fn ->
            defmodule Module.concat(AssignAsyncSocket, "Test#{:erlang.phash2(test)}") do
              use Phoenix.LiveView

              def mount(_params, _session, socket) do
                socket = assign(socket, :foo, :bar)
                foo = socket.assigns.foo

                {:ok,
                 unquote(fun)(socket, :foo, fn ->
                   do_something(foo)
                 end)}
              end

              defp do_something(assigns), do: :ok
            end
          end)

        refute warnings =~
                 "you are accessing the LiveView Socket inside a function given to #{unquote(fun)}"
      end

      test "does not warn when argument is not a function (#{fun})", %{test: test} do
        warnings =
          capture_io(:stderr, fn ->
            defmodule Module.concat(AssignAsyncSocket, "Test#{:erlang.phash2(test)}") do
              use Phoenix.LiveView

              def mount(_params, _session, socket) do
                socket = assign(socket, :foo, :bar)

                {:ok, unquote(fun)(socket, :foo, function_that_returns_the_func(socket))}
              end

              defp function_that_returns_the_func(socket) do
                foo = socket.assigns.foo

                fn ->
                  do_something(foo)
                end
              end

              defp do_something(assigns), do: :ok
            end
          end)

        refute warnings =~
                 "you are accessing the LiveView Socket inside a function given to #{unquote(fun)}"
      end
    end
  end
end
