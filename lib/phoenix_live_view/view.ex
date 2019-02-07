defmodule Phoenix.LiveView.View do
  @moduledoc false
  import Phoenix.HTML, only: [sigil_E: 2]

  alias Phoenix.LiveView
  alias Phoenix.LiveView.Socket

  @max_session_age 1_209_600

  @doc """
  Renders the view into a `%Phoenix.LiveView.Rendered{}` struct.
  """
  def render(%Socket{} = socket, session) do
    view = Socket.view(socket)
    assigns = Map.merge(socket.assigns, %{session: session, socket: Socket.strip(socket)})

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

      iex> verify_session(AppWeb.Endpoint, encoded_token_string)
      {:ok, %{} = decoeded_session}

      iex> verify_session(AppWeb.Endpoint, "bad token")
      {:error, :invalid}

      iex> verify_session(AppWeb.Endpoint, "expired")
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
  Renders a live view without spawning a liveview server.

  * `endpoint` - the endpoint module
  * `view` - the live view module

  ## Options

    * `session` - the required map of session data
  """
  def static_render(endpoint, view, opts) do
    session = Keyword.fetch!(opts, :session)
    {:ok, socket, signed_session} = static_mount(endpoint, view, session)

    ~E"""
    <div id="<%= LiveView.Socket.dom_id(socket) %>"
         data-phx-view="<%= inspect(view) %>"
         data-phx-session="<%= signed_session %>">
      <%= render(socket, session) %>
    </div>
    <div class="phx-loader"></div>
    """
  end

  @doc """
  Renders a nested live view without spawning a server.

  * `parent` - the parent `%Phoenix.LiveView.Socket{}`
  * `view` - the child live view module

  ## Options

    * `session` - the required map of session data
  """
  def nested_static_render(%Socket{} = parent, view, opts) do
    session = Keyword.fetch!(opts, :session)

    if Socket.connected?(parent) do
      connected_static_render(parent, view, session)
    else
      disconnected_static_render(parent, view, session)
    end
  end

  defp disconnected_static_render(parent, view, session) do
    {:ok, socket, signed_session} = static_mount(parent, view, session)

    ~E"""
    <div disconn id="<%= LiveView.Socket.dom_id(socket) %>"
         data-phx-parent-id="<%= LiveView.Socket.dom_id(parent) %>"
         data-phx-view="<%= inspect(view) %>"
         data-phx-session="<%= signed_session %>">

      <%= render(socket, session) %>
    </div>
    <div class="phx-loader"></div>
    """
  end

  defp connected_static_render(parent, view, session) do
    {child_id, signed_session} = sign_child_session(parent, view, session)

    ~E"""
    <div conn id="<%= child_id %>"
         data-phx-parent-id="<%= LiveView.Socket.dom_id(parent) %>"
         data-phx-view="<%= inspect(view) %>"
         data-phx-session="<%= signed_session %>"></div>
    <div class="phx-loader"></div>
    """
  end

  defp static_mount(%Socket{} = parent, view, session) do
    parent
    |> LiveView.Socket.build_nested_socket(%{view: view})
    |> do_static_mount(view, session)
  end

  defp static_mount(endpoint, view, session) do
    endpoint
    |> LiveView.Socket.build_socket(%{view: view})
    |> do_static_mount(view, session)
  end

  defp do_static_mount(socket, view, session) do
    session
    |> view.mount(socket)
    |> case do
      {:ok, %Socket{} = new_socket} ->
        signed_session = sign_session(socket, session)

        {:ok, new_socket, signed_session}

      other ->
        raise_invalid_mount(other, view)
    end
  end

  defp sign_session(%Socket{} = socket, session) do
    sign_token(socket.endpoint, salt(socket), %{
      id: LiveView.Socket.dom_id(socket),
      view: LiveView.Socket.view(socket),
      session: session
    })
  end

  defp sign_child_session(%Socket{} = parent, child_view, session) do
    id = LiveView.Socket.child_dom_id(parent, child_view)

    token =
      sign_token(parent.endpoint, salt(parent), %{
        id: id,
        parent_id: LiveView.Socket.dom_id(parent),
        view: child_view,
        session: session
      })

    {id, token}
  end

  defp salt(%Socket{endpoint: endpoint}) do
    salt(endpoint)
  end

  defp salt(endpoint) when is_atom(endpoint) do
    LiveView.Socket.configured_signing_salt!(endpoint)
  end

  defp sign_token(endpoint_mod, salt, data) do
    encoded_data = data |> :erlang.term_to_binary() |> Base.encode64()
    Phoenix.Token.sign(endpoint_mod, salt, encoded_data)
  end
end
