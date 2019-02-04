defmodule Phoenix.LiveViewTest do
  @moduledoc """
  TODO

  - timeouts
  """

  import ExUnit.Assertions

  defmodule ClientProxy do
    use GenServer

    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts)
    end

    def init(opts) do
      client = Keyword.fetch!(opts, :client)
      view = Keyword.fetch!(opts, :view)
      timeout = Keyword.fetch!(opts, :timeout)
      socket = %Phoenix.Socket{
        transport_pid: self(),
        serializer: Phoenix.LiveViewTest,
        channel: view.module,
        endpoint: view.endpoint,
        private: %{log_join: false},
        topic: view.topic,
      }
      ref = make_ref()

      case Phoenix.LiveView.Channel.start_link({%{"session" => view.token}, {self(), ref}, socket}) do
        {:ok, pid} ->
          receive do
            {^ref, %{rendered: rendered}} ->
              send(client, {view.topic, :mounted, pid, render(rendered)})
              {:ok, %{client: client, view_pid: pid, topic: view.topic, rendered: rendered}}
          after timeout ->
            exit(:timout)
          end

        :ignore ->
          receive do
            {^ref, reason} ->
              send(client, {view.topic, reason})
              :ignore
          end
      end
    end

    def handle_info(%Phoenix.Socket.Message{
        event: "render",
        topic: topic,
        payload: diff,
      }, %{topic: topic} = state) do

      rendered = deep_merge(state.rendered, diff)
      html = render_diff(rendered)
      send(state.client, {topic, :rendered, html})
      {:noreply, %{state | rendered: rendered}}
    end

    defp render(%{static: statics} = rendered) do
      for {static, i} <- Enum.with_index(statics), into: "",
        do: static <> to_string(rendered[i])
    end

    defp render_diff(rendered) do
      rendered
      |> to_output_buffer([])
      |> Enum.reverse()
      |> Enum.join("")
    end
    defp to_output_buffer(%{dynamics: dynamics, static: statics}, acc) do
      Enum.reduce(dynamics, acc, fn {_dynamic, index}, acc ->
        Enum.reduce(tl(statics), [Enum.at(statics, 0) | acc], fn static, acc ->
          [static | dynamic_to_buffer(dynamics[index - 1], acc)]
        end)
      end)
    end
    defp to_output_buffer(%{static: statics} = rendered, acc) do
      statics
      |> Enum.with_index()
      |> tl()
      |> Enum.reduce([Enum.at(statics, 0) | acc], fn {static, index}, acc ->
          [static | dynamic_to_buffer(rendered[index - 1], acc)]
      end)
    end

    defp dynamic_to_buffer(%{} = rendered, acc), do: to_output_buffer(rendered, []) ++ acc
    defp dynamic_to_buffer(str, acc), do: [str | acc]

    defp deep_merge(target, source) do
      Map.merge(target, source, fn
        _, %{} = target, %{} = source -> deep_merge(target, source)
        _, _target, source -> source
      end)
    end
  end

  defmodule View do
    defstruct token: nil, module: nil, endpoint: nil, pid: :static, proxy: nil, topic: nil

    def build(attrs) do
      topic = "phx-" <> Base.encode64(:crypto.strong_rand_bytes(8))
      struct(__MODULE__, Keyword.put_new(attrs, :topic, topic))
    end
  end

  def instrument(:phoenix_controller_render, _, _, func), do: func.()

  def config(:live_view), do: [signing_salt: "11234567821234567831234567841234"]
  def config(:secret_key_base), do: "5678567899556789656789756789856789956789"

  defmacro live_render_static(view_module, opts) do
    quote unquote: true, bind_quoted: binding() do
      endpoint = unquote(__MODULE__)
      conn =
        Phoenix.ConnTest.build_conn()
        |> Plug.Conn.put_private(:phoenix_endpoint, endpoint)
        |> Phoenix.LiveView.live_render(view_module, Keyword.put_new(opts, :caller, self()))

      html = Phoenix.ConnTest.html_response(conn, 200)
      assert_receive {:static_mount, token}
      {:ok, View.build(token: token, module: view_module, endpoint: endpoint), html}
    end
  end

  def live_render_connect(%View{topic: topic} = view, opts \\ []) do
    timeout = opts[:timeout] || 5000

    case ClientProxy.start_link(client: self(), view: view, timeout: timeout) do
      {:ok, proxy_pid} ->
        receive do
          {^topic, :mounted, view_pid, html} ->
            view = %View{view | pid: view_pid, proxy: proxy_pid, topic: topic}
            {:ok, view, html}
        end

      :ignore ->
        receive do
          {^topic, reason} -> {:error, reason}
        end
    end
  end

  defmacro assert_render(view, html_match, opts \\ []) do
    quote bind_quoted: binding(), unquote: true do
      timeout = opts[:timeout] || 100

      case unquote(__MODULE__).__all_rendered__(view.topic, timeout) do
        {:ok, all_html, formatted_html} ->
          assert unquote(__MODULE__).__matching_render__?(all_html, html_match, view.topic), """
          expected rendered content to match:

              #{inspect(html_match)}

          The following content was rendered:

          #{formatted_html}
          """
        {:error, :timeout} -> flunk "no content rendered within #{timeout}ms"
      end
    end
  end

  @doc false
  def __matching_render__?(all_html, %Regex{} = html_match, topic) do
    matched_index = Enum.find_index(all_html, fn html -> html =~ html_match end)
    replay_render(all_html, topic, matched_index)

    matched_index
  end
  def __matching_render__?(all_html, html_match, topic) when is_binary(html_match) do
    matched_index = Enum.find_index(all_html, fn html -> html == html_match end)
    replay_render(all_html, topic, matched_index)

    matched_index
  end
  defp replay_render(_all_html, _topic, nil), do: :noop
  defp replay_render(all_html, topic, matched_index) do
    for {html, index} <- Enum.with_index(all_html), index != matched_index do
      send(self(), {topic, :rendered, html})
    end
  end

  @doc false
  def __all_rendered__(topic, timeout) do
    receive do
      {^topic, :rendered, html} -> all_rendered(topic, [html])
    after timeout -> {:error, :timeout}
    end
  end
  defp all_rendered(topic, acc) do
    receive do
      {^topic, :rendered, html} -> all_rendered(topic, [html | acc])
    after 0 ->
      all = Enum.reverse(acc)
      {:ok, all, formatted_html(all)}
    end
  end
  defp formatted_html(all) do
    all
    |> Enum.with_index()
    |> Enum.map(fn {html, index} ->
      """
      #{index}:

          #{html}
      """
    end)
    |> Enum.join("")
  end

  @doc false
  def encode!(msg), do: msg
end
