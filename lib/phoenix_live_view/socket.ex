defmodule Phoenix.LiveView.Socket do
  @moduledoc """
  Holds the live view socket state.
  """
  use Phoenix.Socket

  alias Phoenix.LiveView.Socket

  @salt_length 8

  defstruct id: nil,
            endpoint: nil,
            parent_id: nil,
            view: nil,
            assigns: %{},
            changed: %{},
            root_fingerprint: nil,
            private: %{},
            caller: nil,
            connected?: false

  channel "views:*", Phoenix.LiveView.Channel

  @doc false
  @impl Phoenix.Socket
  def connect(_params, %Phoenix.Socket{} = socket, _connect_info) do
    {:ok, socket}
  end

  @doc false
  @impl Phoenix.Socket
  def id(_socket), do: nil

  @doc false
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
  Returns the socket's live view module.
  """
  def view(%Socket{view: view}), do: view

  @doc """
  Returns true if the socket is connected.
  """
  def connected?(%Socket{connected?: true}), do: true
  def connected?(%Socket{connected?: false}), do: false

  @doc false
  def build_socket(endpoint, %{} = opts) when is_atom(endpoint) do
    opts = normalize_opts!(opts)

    %Socket{
      id: Map.get_lazy(opts, :id, fn -> random_id() end),
      endpoint: endpoint,
      parent_id: opts[:parent_id],
      caller: opts[:caller],
      view: Map.fetch!(opts, :view),
      assigns: Map.get(opts, :assigns, %{}),
      connected?: Map.get(opts, :connected?, false)
    }
  end

  @doc false
  def build_nested_socket(%Socket{endpoint: endpoint} = parent, opts) do
    nested_opts =
      Map.merge(opts, %{
        id: child_dom_id(parent, Map.fetch!(opts, :view)),
        parent_id: dom_id(parent),
        caller: parent.caller,
      })

    build_socket(endpoint, nested_opts)
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

  @doc false
  def configured_signing_salt!(endpoint) when is_atom(endpoint) do
    endpoint.config(:live_view)[:signing_salt] ||
      raise ArgumentError, """
      no signing salt found for #{inspect(endpoint)}.

      Add the following live view configuration to your config/config.exs:

          config :my_app, MyApp.Endpoint,
              ...,
              live_view: [signing_salt: #{random_signing_salt()}]

      """
  end

  @doc false
  def random_signing_salt do
    @salt_length
    |> :crypto.strong_rand_bytes()
    |> Base.encode64()
    |> binary_part(0, @salt_length)
  end

  defp random_id, do: "phx-" <> Base.encode64(:crypto.strong_rand_bytes(8))
end
