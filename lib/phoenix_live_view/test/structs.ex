defmodule Phoenix.LiveViewTest.View do
  @moduledoc """
  The struct for testing LiveViews.

  The following public fields represent the LiveView:

    * `id` - The DOM id of the LiveView
    * `module` - The module of the running LiveView
    * `pid` - The Pid of the running LiveView
    * `endpoint` - The endpoint for the LiveView

  See the `Phoenix.LiveViewTest` documentation for usage.
  """
  if Version.match?(System.version(), ">= 1.8.0") do
    @derive {Inspect, only: [:id, :module, :pid, :endpoint]}
  end

  defstruct id: nil,
            module: nil,
            pid: nil,
            proxy: nil,
            endpoint: nil
end

defmodule Phoenix.LiveViewTest.Element do
  @moduledoc """
  The struct returned by `Phoenix.LiveViewTest.element/3`.

  The following public fields represent the element:

    * `selector` - The query selector
    * `text_filter` - The text to further filter the element

  See the `Phoenix.LiveViewTest` documentation for usage.
  """
  if Version.match?(System.version(), ">= 1.8.0") do
    @derive {Inspect, only: [:selector, :text_filter]}
  end

  defstruct proxy: nil,
            selector: nil,
            text_filter: nil,
            event: nil,
            form_data: nil
end
