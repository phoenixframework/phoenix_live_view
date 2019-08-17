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
            children: %{},
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

  def put_child(%View{} = parent, session, dom_id) do
    %View{parent | children: Map.put(parent.children, session, dom_id)}
  end

  def fetch_child_session_by_id(%View{} = parent, dom_id) do
    Enum.find_value(parent.children, fn
      {session, ^dom_id} -> {:ok, session}
      {_session, _dom_id} -> nil
    end) || :error
  end

  def drop_child(%View{} = parent, session) do
    %View{parent | children: Map.delete(parent.children, session)}
  end

  def prune_children(%View{} = parent) do
    %View{parent | children: %{}}
  end

  def removed_children(%View{} = parent, children_before) do
    children_before
    |> Enum.filter(fn {session, _dom_id} -> !Map.has_key?(parent.children, session) end)
    |> Enum.into(%{})
  end

  def connected?(%View{pid: pid}) when is_pid(pid), do: true
  def connected?(%View{pid: :static}), do: false
end
