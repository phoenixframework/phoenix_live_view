defmodule Phoenix.LiveView do
  @moduledoc """
  TODO
  """

  @behaviour Plug

  alias Phoenix.LiveView.Socket

  @type unsigned_params :: map

  @callback upgrade(Plug.Conn.t(), unsigned_params) :: {:ok, Socket.t()} | {:error, term}
  @callback prepare(Socket.signed_params(), Socket.t()) :: {:ok, Socket.t()} | {:error, term}
  @callback init(Socket.t()) :: {:ok, Socket.t()} | {:error, term}
  @callback render(Socket.assigns()) :: binary | list
  @callback terminate(reason :: :normal | :shutdown | {:shutdown, :left | :closed | term}, Socket.t()) :: term

  @optional_callbacks terminate: 2, prepare: 2, init: 1, upgrade: 2

  def push_params(%Socket{} = socket, attrs)
    when is_list(attrs) or is_map(attrs) do
    %Socket{socket | signed_params: Enum.into(attrs, socket.signed_params)}
  end

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
      def upgrade(%Plug.Conn{}, %{} = _unsigned_params) do
        {:ok, %{}}
      end
      @impl unquote(__MODULE__)
      def prepare(%{} = _signed_params, socket) do
        {:ok, socket}
      end
      @impl unquote(__MODULE__)
      def init(socket), do: {:ok, socket}
      @impl unquote(__MODULE__)
      def terminate(reason, state), do: {:ok, state}
      defoverridable upgrade: 2, prepare: 2, init: 1, terminate: 2
    end
  end

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, view) do
    conn
    |> Plug.Conn.put_private(:phoenix_live_view, view)
    |> Phoenix.Controller.put_view(__MODULE__)
    |> Phoenix.Controller.render("template.html")
  end

  @doc false
  # Phoenix.LiveView acts as a view via put_view to spawn the render
  def render("template.html", %{conn: conn} = assigns) do
    Phoenix.LiveView.Server.static_render(conn.private.phoenix_live_view, assigns)
  end
end
