defmodule Phoenix.WarningsTest do
  use ExUnit.Case, async: true

  @moduletag :after_verify
  import ExUnit.CaptureIO

  test "deprecated preload/1" do
    warnings =
      capture_io(:stderr, fn ->
        defmodule DeprecatedPreloadComponent do
          use Phoenix.LiveComponent

          def preload(list_of_assigns) do
            list_of_assigns
          end

          def render(assigns) do
            ~H"<div></div>"
          end
        end
      end)

    assert warnings =~
             "LiveComponent.preload/1 is deprecated (defind in Phoenix.WarningsTest.DeprecatedPreloadComponent). Use LiveComponent.update_many/2 instead"
  end
end
