defmodule Phoenix.LiveView.Socket do
  @moduledoc """
  TODO
  """
  use Phoenix.Socket

  @salt_length 8

  @private_key :phx_live_view
  @private %{
    id: nil,
    view: nil,
    state: :disconnected,
    signing_salt: nil,
    signed_params: nil
  }

  channel "views:*", Phoenix.LiveView.Channel

  @impl Phoenix.Socket
  def connect(_params, socket, _connect_info) do
    {:ok, build_socket(socket, %{})}
  end

  @impl Phoenix.Socket
  def id(_socket), do: nil

  @doc false
  def build_socket(endpoint, opts) when is_atom(endpoint) do
    build_socket(%Phoenix.Socket{endpoint: endpoint}, opts)
  end
  def build_socket(%Phoenix.Socket{endpoint: endpoint} = socket, opts) do
    salt = configured_signing_salt!(endpoint)
    live_view_opts = Map.merge(@private, private_opts!(opts))

    socket
    |> Map.update!(:private, fn priv -> Map.put(priv, @private_key, live_view_opts) end)
    |> update_private(:signing_salt, fn _ -> salt end)
  end
  defp private_opts!(%{} = private) do
    valid_keys = Map.keys(@private)
    provided_keys = Map.keys(private)
    if provided_keys -- valid_keys != [], do: raise ArgumentError, """
    invalid private socket assigns. Expected keys #{inspect(valid_keys)}, got #{inspect(provided_keys)}
    """
    private
  end

  @doc false
  def dom_id(%Phoenix.Socket{private: %{@private_key => live}}) do
    Map.fetch!(live, :id)
  end

  @doc false
  def view(%Phoenix.Socket{private: %{@private_key => live}}) do
    Map.fetch!(live, :view)
  end

  @doc false
  def signed_params(%Phoenix.Socket{private: %{@private_key => live}}) do
    Map.fetch!(live, :signed_params)
  end

  @doc false
  def signing_salt(%Phoenix.Socket{private: %{@private_key => live}}) do
    Map.fetch!(live, :signing_salt)
  end

  @doc false
  def update_private(%Phoenix.Socket{private: %{@private_key => live}} = socket, key, func) do
    case Map.fetch(live, key) do
      {:ok, val} ->
        put_in(socket.private[@private_key][key], func.(val))

      :error -> raise ArgumentError, """
        unknown live view key, #{inspect(key)}, for socket. Allowed keys include:

            #{inspect(Map.keys(@private))}

        """
    end
  end

  @doc false
  def configured_signing_salt!(endpoint) when is_atom(endpoint) do
    endpoint.config(:live_view)[:signing_salt] || raise ArgumentError, """
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
end
