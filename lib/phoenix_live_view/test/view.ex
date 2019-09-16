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
            children: [],
            child_statics: %{},
            id: nil,
            connect_params: %{}

  def build(attrs) do
    attrs_with_defaults =
      attrs
      |> Keyword.merge(topic: Phoenix.LiveView.View.random_id())
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

  def put_child(%View{} = parent, id, session) do
    %View{parent | children: [{id, session} | parent.children]}
  end

  def fetch_child_session_by_id(%View{} = parent, id) do
    Enum.find_value(parent.children, fn
      {^id, session} -> {:ok, session}
      {_id, _session} -> false
    end) || :error
  end

  def drop_child(%View{children: children} = parent, id) do
    %View{parent | children: Enum.reject(children, fn {cid, _session} -> id == cid end)}
  end

  def prune_children(%View{} = parent) do
    %View{parent | children: []}
  end

  def connected?(%View{pid: pid}) when is_pid(pid), do: true
  def connected?(%View{pid: :static}), do: false
end
