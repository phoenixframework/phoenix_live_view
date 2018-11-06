defmodule Phoenix.LiveView.Socket do
  @moduledoc """
  TODO
  """
  use Phoenix.Socket

  alias Phoenix.LiveView.Socket

  # TODO
  # - own struct
  # - don't store signing_salt (and other info) in struct. Keep it in parent DS
  # - don't spawn extra process. Keep callbacks in channel
  #
  # Naming
  # - init
  # - socket.connected? vs socket.joined et al

  @salt_length 8

  defstruct id: nil,
            endpoint: nil,
            parent_id: nil,
            view: nil,
            assigns: %{},
            private: %{},
            connected?: false

  channel("views:*", Phoenix.LiveView.Channel)

  @impl Phoenix.Socket
  def connect(_params, %Phoenix.Socket{} = socket, _connect_info) do
    {:ok, socket}
  end

  @impl Phoenix.Socket
  def id(_socket), do: nil


  def dom_id(%Socket{id: id}), do: id

  def view(%Socket{view: view}), do: view

  def connected?(%Socket{connected?: true}), do: true
  def connected?(%Socket{connected?: false}), do: false

  @doc false
  def build_socket(endpoint, %{} = opts) when is_atom(endpoint) do
    opts = normalize_opts!(opts)

    %Socket{
      id: Map.get(opts, :id, random_id()),
      endpoint: endpoint,
      parent_id: opts[:parent_id],
      view: Map.fetch!(opts, :view),
      assigns: Map.get(opts, :assigns, %{}),
      connected?: Map.get(opts, :connected?, false)
    }
  end

  defp normalize_opts!(opts) do
    valid_keys = Map.keys(%Socket{})
    provided_keys = Map.keys(opts)

    if provided_keys -- valid_keys != [],
      do:
        raise(ArgumentError, """
        invalid socket keys. Expected keys #{inspect(valid_keys)}, got #{
          inspect(provided_keys)
        }
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
