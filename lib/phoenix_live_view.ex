defmodule Phoenix.LiveView do
  @moduledoc """
  TODO
  - don't spawn extra process. Keep callbacks in channel

  Naming
  - init?
  - socket.connected? vs socket.joined et al
  """

  @behaviour Plug

  alias Phoenix.LiveView
  alias Phoenix.LiveView.Socket

  @type unsigned_params :: map
  @type from :: binary

  @callback mount(Socket.session(), Socket.t()) :: {:ok, Socket.t()} | {:error, term}
  @callback render(Socket.assigns()) :: binary | list
  @callback terminate(reason :: :normal | :shutdown | {:shutdown, :left | :closed | term}, Socket.t()) :: term
  @callback handle_event(event :: binary, from, unsigned_params, Socket.t()) ::
    {:noreply, Socket.t()} | {:stop, reason :: term, Socket.t()}

  @optional_callbacks terminate: 2, mount: 2, handle_event: 4

  def connected?(%Socket{} = socket), do: LiveView.Socket.connected?(socket)

  def assign(%Socket{assigns: assigns} = socket, key, value) do
    %Socket{socket | assigns: Map.put(assigns, key, value)}
  end
  def assign(%Socket{assigns: assigns} = socket, attrs)
      when is_map(attrs) or is_list(attrs) do
    %Socket{socket | assigns: Enum.into(attrs, assigns)}
  end
  def update(%Socket{assigns: assigns} = socket, key, func) do
    %Socket{socket | assigns: Map.update!(assigns, key, func)}
  end

  def put_flash(%Socket{private: private} = socket, kind, msg) do
    %Socket{socket | private: Map.update(private, :flash, %{kind => msg}, &Map.put(&1, kind, msg))}
  end

  def redirect(%Socket{} = socket, opts) do
    {:stop, {:redirect, to: Keyword.fetch!(opts, :to), flash: flash(socket)}, socket}
  end
  defp flash(%Socket{private: %{flash: flash}}), do: flash
  defp flash(%Socket{}), do: nil

  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__), except: [render: 2]
      import Phoenix.HTML # TODO don't import this, users can

      @behaviour unquote(__MODULE__)
      @impl unquote(__MODULE__)
      def mount(_session, socket), do: {:ok, socket}
      @impl unquote(__MODULE__)
      def terminate(reason, state), do: {:ok, state}
      defoverridable mount: 2, terminate: 2
    end
  end

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, view) do
    live_render(conn, view, session: %{params: conn.path_params})
  end

  @doc false
  # Phoenix.LiveView acts as a view via put_view to spawn the render
  def render("template.html", %{conn: conn}) do
    {root_view, opts} = conn.private.phoenix_live_view

    conn
    |> Phoenix.Controller.endpoint_module()
    |> LiveView.Server.static_render(root_view, opts)
  end

  @doc """
  TODO
  """
  def live_render(conn_or_socket, view, opts \\ []) do
    session = opts[:session] || %{}
    do_live_render(conn_or_socket, view, session: session)
  end
  defp do_live_render(%Plug.Conn{} = conn, view, opts) do
    conn
    |> Plug.Conn.put_private(:phoenix_live_view, {view, opts})
    |> Phoenix.Controller.put_view(__MODULE__)
    |> Phoenix.Controller.render("template.html")
  end
  defp do_live_render(%Socket{} = parent, view, opts) do
    LiveView.Server.nested_static_render(parent, view, opts)
  end
end
