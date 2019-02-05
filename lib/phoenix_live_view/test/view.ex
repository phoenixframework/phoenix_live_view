defmodule Phoenix.LiveViewTest.View do
  @moduledoc false
  alias Phoenix.LiveViewTest.View

  defstruct token: nil,
            module: nil,
            endpoint: nil,
            pid: :static,
            proxy: nil,
            topic: nil,
            ref: nil

  def build(attrs) do
    topic = "phx-" <> Base.encode64(:crypto.strong_rand_bytes(8))
    struct(__MODULE__, Keyword.put_new(attrs, :topic, topic))
  end

  def connected?(%View{pid: pid}) when is_pid(pid), do: true
  def connected?(%View{pid: :static}), do: false
end
