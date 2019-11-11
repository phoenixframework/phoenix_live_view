defmodule Phoenix.LiveViewTest.View do
  @moduledoc """
  The struct for testing LiveViews.

  The following public fields represent the LiveView:

    * `id` - The DOM id of the LiveView
    * `module` - The module of the running LiveView
    * `pid` - The Pid of the running LiveView

  See the `Phoenix.LiveViewTest` documentation for usage.
  """
  defstruct id: nil,
            module: nil,
            pid: nil,
            proxy: nil
end
