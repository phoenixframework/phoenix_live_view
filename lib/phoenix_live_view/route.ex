defmodule Phoenix.LiveView.Route do
  @moduledoc false

  alias Phoenix.LiveView.{Route, Socket}

  defstruct path: nil,
            view: nil,
            action: nil,
            opts: [],
            live_session: %{},
            params: %{},
            uri: nil

  @doc """
  Computes the container from the route options and falls backs to use options.
  """
  def container(%Route{} = route) do
    route.opts[:container] || route.view.__live__()[:container]
  end

  @doc """
  Returns the internal or external matched LiveView route info for the given socket
  and uri, raises if none is available.
  """
  def live_link_info!(%Socket{router: nil}, view, _uri) do
    raise ArgumentError,
          "cannot invoke handle_params/3 on #{inspect(view)} " <>
            "because it is not mounted nor accessed through the router live/3 macro"
  end

  def live_link_info!(%Socket{} = socket, view, uri) do
    case live_link_info(socket.endpoint, socket.router, uri) do
      {:internal, %Route{view: ^view} = route} ->
        {:internal, route}

      {:internal, %Route{view: _view} = route} ->
        {:external, route.uri}

      {:external, _parsed_uri} = external ->
        external

      :error ->
        raise ArgumentError,
              "cannot invoke handle_params nor navigate/patch to #{inspect(uri)} " <>
                "because it isn't defined in #{inspect(socket.router)}"
    end
  end

  @doc """
  Returns the internal or external matched LiveView route info for the given uri.
  """
  def live_link_info(endpoint, router, uri) when is_binary(uri) do
    live_link_info(endpoint, router, URI.parse(uri))
  end

  def live_link_info(endpoint, router, %URI{} = parsed_uri)
      when is_atom(endpoint) and is_atom(router) do
    %URI{host: host, path: path, query: query} = parsed_uri
    query_params = if query, do: Plug.Conn.Query.decode(query), else: %{}

    split_path =
      for segment <- String.split(path || "", "/"), segment != "", do: URI.decode(segment)

    route_path = strip_segments(endpoint.script_name(), split_path) || split_path

    case Phoenix.Router.route_info(router, "GET", route_path, host) do
      %{plug: Phoenix.LiveView.Plug, phoenix_live_view: lv, path_params: path_params} ->
        {view, action, opts, live_session} = lv

        route = %Route{
          view: view,
          path: route_path,
          action: action,
          uri: parsed_uri,
          opts: opts,
          live_session: live_session,
          params: Map.merge(query_params, path_params)
        }

        {:internal, route}

      %{} ->
        {:external, parsed_uri}

      :error ->
        :error
    end
  end

  defp strip_segments([head | tail1], [head | tail2]), do: strip_segments(tail1, tail2)
  defp strip_segments([], tail2), do: tail2
  defp strip_segments(_, _), do: nil
end
