defmodule Phoenix.LiveView.View do
  @moduledoc false
  import Phoenix.HTML, only: [sigil_E: 2]

  alias Phoenix.LiveView
  alias Phoenix.LiveView.Socket

  @max_session_age 1_209_600

  @salt_length 8

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

  @doc """
  Builds a `%Phoenix.LiveViewSocket{}`.
  """
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

  @doc """
  Builds a nested child `%Phoenix.LiveViewSocket{}`.
  """
  def build_nested_socket(%Socket{endpoint: endpoint} = parent, opts) do
    nested_opts =
      Map.merge(opts, %{
        id: child_dom_id(parent, Map.fetch!(opts, :view)),
        parent_pid: self(),
      })

    build_socket(endpoint, nested_opts)
  end

  @doc """
  Annotates the socket for redirect.
  """
  def put_redirect(%Socket{stopped: nil} = socket, to) do
    %Socket{socket | stopped: {:redirect, %{to: to}}}
  end
  def put_redirect(%Socket{stopped: reason} = _socket, _to) do
    raise ArgumentError, "socket already prepared to stop for #{inspect(reason)}"
  end

  @doc """
  Renders the view into a `%Phoenix.LiveView.Rendered{}` struct.
  """
  def render(%Socket{} = socket, session) do
    view = view(socket)
    assigns = Map.merge(socket.assigns, %{session: session, socket: strip(socket)})

    case view.render(assigns) do
      %Phoenix.LiveView.Rendered{} = rendered ->
        rendered

      other ->
        raise RuntimeError, """
        expected #{inspect(view)}.render/1 to return a %Phoenix.LiveView.Rendered{} struct

        Ensure your render function uses ~L, or your eex template uses the .leex extension.

        Got:

            #{inspect(other)}

        """
    end
  end

  @doc """
  Verifies the session token.

  Returns the decoded map of session data or an error.

  ## Examples

      iex> verify_session(MyAppWeb.Endpoint, encoded_token_string)
      {:ok, %{} = decoeded_session}

      iex> verify_session(MyAppWeb.Endpoint, "bad token")
      {:error, :invalid}

      iex> verify_session(MyAppWeb.Endpoint, "expired")
      {:error, :expired}
  """
  def verify_session(endpoint_mod, token) do
    case Phoenix.Token.verify(endpoint_mod, salt(endpoint_mod), token, max_age: @max_session_age) do
      {:ok, encoded_term} ->
        term = encoded_term |> Base.decode64!() |> :erlang.binary_to_term()
        {:ok, term}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Signs the socket's flash into a token if it has been set.
  """
  def sign_flash(%Socket{}, nil), do: nil

  def sign_flash(%Socket{endpoint: endpoint}, %{} = flash) do
    LiveView.Flash.sign_token(endpoint, salt(endpoint), flash)
  end

  @doc """
  Raises error message for invalid view mount.
  """
  def raise_invalid_mount(other, view) do
    raise ArgumentError, """
    invalid result returned from #{inspect(view)}.mount/2.

    Expected {:ok, socket}, got: #{inspect(other)}
    """
  end

  @doc """
  Renders a Live View without spawning a Live View server.

  * `endpoint` - the endpoint module
  * `view` - the Live View module

  ## Options

    * `session` - the required map of session data
  """
  def static_render(endpoint, view, opts) do
    session = Keyword.fetch!(opts, :session)
    case static_mount(endpoint, view, session) do
      {:ok, socket, signed_session} ->
        html = ~E"""
        <div id="<%= dom_id(socket) %>"
            data-phx-view="<%= inspect(view) %>"
            data-phx-session="<%= signed_session %>">
          <%= render(socket, session) %>
        </div>
        <div class="phx-loader"></div>
        """
        {:ok, html}

      {:stop, reason} -> {:stop, reason}
    end
  catch
    :throw, {:stop, reason} -> {:stop, reason}
  end

  @doc """
  Renders a nested Live View without spawning a server.

  * `parent` - the parent `%Phoenix.LiveView.Socket{}`
  * `view` - the child Live View module

  ## Options

    * `session` - the required map of session data
  """
  def nested_static_render(%Socket{} = parent, view, opts) do
    session = Keyword.fetch!(opts, :session)

    if connected?(parent) do
      connected_nested_static_render(parent, view, session)
    else
      disconnected_nested_static_render(parent, view, session)
    end
  end

  def configured_signing_salt!(endpoint) when is_atom(endpoint) do
    endpoint.config(:live_view)[:signing_salt] ||
      raise ArgumentError, """
      no signing salt found for #{inspect(endpoint)}.

      Add the following Live View configuration to your config/config.exs:

          config :my_app, MyApp.Endpoint,
              ...,
              live_view: [signing_salt: "#{random_signing_salt()}"]

      """
  end

  defp disconnected_nested_static_render(parent, view, session) do
    case static_mount(parent, view, session) do
      {:ok, socket, signed_session} ->
        html = ~E"""
        <div id="<%= dom_id(socket) %>"
            data-phx-parent-id="<%= dom_id(parent) %>"
            data-phx-view="<%= inspect(view) %>"
            data-phx-session="<%= signed_session %>">

          <%= render(socket, session) %>
        </div>
        <div class="phx-loader"></div>
        """
        {:ok, html}


      {:stop, reason} -> {:stop, reason}
    end
  end

  defp connected_nested_static_render(parent, view, session) do
    {child_id, signed_session} = sign_child_session(parent, view, session)

    html = ~E"""
    <div conn id="<%= child_id %>"
         data-phx-parent-id="<%= dom_id(parent) %>"
         data-phx-view="<%= inspect(view) %>"
         data-phx-session="<%= signed_session %>"></div>
    <div class="phx-loader"></div>
    """

    {:ok, html}
  end

  defp static_mount(%Socket{} = parent, view, session) do
    parent
    |> build_nested_socket(%{view: view})
    |> do_static_mount(view, session)
  end

  defp static_mount(endpoint, view, session) do
    endpoint
    |> build_socket(%{view: view})
    |> do_static_mount(view, session)
  end

  defp do_static_mount(socket, view, session) do
    session
    |> view.mount(socket)
    |> case do
      {:ok, %Socket{} = new_socket} ->
        signed_session = sign_session(socket, session)

        {:ok, new_socket, signed_session}

      {:stop, socket} ->
        {:stop, socket.stopped}

      other ->
        raise_invalid_mount(other, view)
    end
  end

  defp sign_session(%Socket{} = socket, session) do
    sign_token(socket.endpoint, salt(socket), %{
      id: dom_id(socket),
      parent_pid: nil,
      view: view(socket),
      session: session
    })
  end

  defp sign_child_session(%Socket{} = parent, child_view, session) do
    id = child_dom_id(parent, child_view)

    token =
      sign_token(parent.endpoint, salt(parent), %{
        id: id,
        parent_pid: self(),
        view: child_view,
        session: session
      })

    {id, token}
  end

  defp salt(%Socket{endpoint: endpoint}) do
    salt(endpoint)
  end

  defp salt(endpoint) when is_atom(endpoint) do
    configured_signing_salt!(endpoint)
  end

  defp random_signing_salt do
    @salt_length
    |> :crypto.strong_rand_bytes()
    |> Base.encode64()
    |> binary_part(0, @salt_length)
  end

  defp random_id, do: "phx-" <> Base.encode64(:crypto.strong_rand_bytes(8))

  defp sign_token(endpoint_mod, salt, data) do
    encoded_data = data |> :erlang.term_to_binary() |> Base.encode64()
    Phoenix.Token.sign(endpoint_mod, salt, encoded_data)
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
end
