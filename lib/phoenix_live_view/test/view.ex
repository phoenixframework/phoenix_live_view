defmodule Phoenix.LiveViewTest.View do
  @moduledoc false
  alias Phoenix.LiveViewTest.View

  defstruct session_token: nil,
            static_token: nil,
            module: nil,
            mount_path: nil,
            router: nil,
            endpoint: nil,
            pid: :static,
            proxy: nil,
            topic: nil,
            ref: nil,
            rendered: nil,
            children: MapSet.new(),
            child_statics: %{},
            dom_id: nil,
            connect_params: %{}

  def build(attrs) do
    topic = "phx-" <> Base.encode64(:crypto.strong_rand_bytes(8))

    attrs_with_defaults =
      attrs
      |> Keyword.merge(topic: topic)
      |> Keyword.put_new_lazy(:ref, fn -> make_ref() end)

    struct(__MODULE__, attrs_with_defaults)
  end

  def build_child(%View{ref: ref, proxy: proxy} = parent, attrs) do
    attrs
    |> Keyword.merge(
      ref: ref,
      proxy: proxy,
      router: parent.router,
      endpoint: parent.endpoint,
      mount_path: parent.mount_path
    )
    |> build()
  end

  def put_child(%View{} = parent, session) do
    %View{parent | children: MapSet.put(parent.children, session)}
  end

  def drop_child(%View{} = parent, session) do
    %View{parent | children: MapSet.delete(parent.children, session)}
  end

  def prune_children(%View{} = parent) do
    %View{parent | children: MapSet.new()}
  end

  def removed_children(%View{} = parent, children_before) do
    MapSet.difference(children_before, parent.children)
  end

  def connected?(%View{pid: pid}) when is_pid(pid), do: true
  def connected?(%View{pid: :static}), do: false
end
