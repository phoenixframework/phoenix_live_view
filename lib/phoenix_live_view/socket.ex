defmodule Phoenix.LiveView.Socket do
  @moduledoc false

  alias Phoenix.LiveView.Socket

  defstruct id: nil,
            endpoint: nil,
            parent_pid: nil,
            view: nil,
            assigns: %{},
            changed: %{},
            root_fingerprint: nil,
            private: %{},
            stopped: nil,
            connected?: false

  @doc """
  Strips socket of redudant assign data for rendering.
  """
  def strip(%Socket{} = socket) do
    %Socket{socket | assigns: :unset}
  end

  @doc """
  Clears the changes from the socket assigns.
  """
  def clear_changed(%Socket{} = socket) do
    %Socket{socket | changed: nil}
  end

  @doc """
  Returns the socket's flash messages.
  """
  def get_flash(%Socket{private: private}) do
    private[:flash]
  end

  @doc """
  Puts the root fingerprint.
  """
  def put_root(%Socket{} = socket, root_fingerprint) do
    %Socket{socket | root_fingerprint: root_fingerprint}
  end

  @doc """
  Returns the browser's DOM id for the socket's view.
  """
  def dom_id(%Socket{id: id}), do: id

  @doc """
  Returns the browser's DOM id for the child view module of a parent socket.
  """
  def child_dom_id(%Socket{} = parent, child_view) do
    dom_id(parent) <> ":#{inspect(child_view)}"
  end

  @doc """
  Returns the socket's Live View module.
  """
  def view(%Socket{view: view}), do: view

  @doc """
  Returns true if the socket is connected.
  """
  def connected?(%Socket{connected?: true}), do: true
  def connected?(%Socket{connected?: false}), do: false

  def build_socket(endpoint, %{} = opts) when is_atom(endpoint) do
    opts = normalize_opts!(opts)

    %Socket{
      id: Map.get_lazy(opts, :id, fn -> random_id() end),
      endpoint: endpoint,
      parent_pid: opts[:parent_pid],
      view: Map.fetch!(opts, :view),
      assigns: Map.get(opts, :assigns, %{}),
      connected?: Map.get(opts, :connected?, false)
    }
  end

  def build_nested_socket(%Socket{endpoint: endpoint} = parent, opts) do
    nested_opts =
      Map.merge(opts, %{
        id: child_dom_id(parent, Map.fetch!(opts, :view)),
        parent_pid: self(),
      })

    build_socket(endpoint, nested_opts)
  end

  def put_redirect(%Socket{stopped: nil} = socket, to) do
    %Socket{socket | stopped: {:redirect, %{to: to}}}
  end
  def put_redirect(%Socket{stopped: reason} = _socket, _to) do
    raise ArgumentError, "socket already prepared to stop for #{inspect(reason)}"
  end

  defp normalize_opts!(opts) do
    valid_keys = Map.keys(%Socket{})
    provided_keys = Map.keys(opts)

    if provided_keys -- valid_keys != [],
      do:
        raise(ArgumentError, """
        invalid socket keys. Expected keys #{inspect(valid_keys)}, got #{inspect(provided_keys)}
        """)

    opts
  end

  defp random_id, do: "phx-" <> Base.encode64(:crypto.strong_rand_bytes(8))
end
