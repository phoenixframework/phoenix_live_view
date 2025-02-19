defmodule Phoenix.LiveView.DelegateEventTest do
  use ExUnit.Case, async: true

  defmodule ExampleComponent do
    def handle_event("make it so", _params, _socket) do
      :success
    end
  end

  defmodule ExampleView do
    import Phoenix.LiveView
    delegate_event "make it so", to: ExampleComponent
  end


  test "delegating an event handler" do
    assert ExampleView.handle_event("make it so", %{}, %{}) == :success
  end
end
