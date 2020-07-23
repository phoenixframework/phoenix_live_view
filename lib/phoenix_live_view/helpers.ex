defmodule Phoenix.LiveView.Helpers do
  @moduledoc """
  A collection of helpers to be imported into your views.
  """

  alias Phoenix.LiveView.{Component, Socket, Static}

  @doc false
  def live_patch(opts) when is_list(opts) do
    live_link("patch", Keyword.fetch!(opts, :do), Keyword.delete(opts, :do))
  end

  @doc """
  Generates a link that will patch the current LiveView.

  When navigating to the current LiveView, `c:handle_params/3` is
  immediately invoked to handle the change of params and URL state.
  Then the new state is pushed to the client, without reloading the
  whole page while also maintaining the current scroll position.
  For live redirects to another LiveView, use `live_redirect/2`.

  ## Options

    * `:to` - the required path to link to.
    * `:replace` - the flag to replace the current history or push a new state.
      Defaults `false`.

  All other options are forwarded to the anchor tag.

  ## Examples

      <%= live_patch "home", to: Routes.page_path(@socket, :index) %>
      <%= live_patch "next", to: Routes.live_path(@socket, MyLive, @page + 1) %>
      <%= live_patch to: Routes.live_path(@socket, MyLive, dir: :asc), replace: false do %>
        Sort By Price
      <% end %>

  """
  def live_patch(%Socket{}, _) do
    raise """
    you are invoking live_patch/2 with a socket but a socket is not expected.

    If you want to live_patch/2 inside a LiveView, use push_patch/2 instead.
    If you are inside a template, make the sure the first argument is a string.
    """
  end

  def live_patch(opts, do: block) when is_list(opts) do
    live_link("patch", block, opts)
  end

  def live_patch(text, opts) when is_list(opts) do
    live_link("patch", text, opts)
  end

  @doc false
  def live_redirect(opts) when is_list(opts) do
    live_link("redirect", Keyword.fetch!(opts, :do), Keyword.delete(opts, :do))
  end

  @doc """
  Generates a link that will redirect to a new LiveView.

  The current LiveView will be shut down and a new one will be mounted
  in its place, without reloading the whole page. This can
  also be used to remount the same LiveView, in case you want to start
  fresh. If you want to navigate to the same LiveView without remounting
  it, use `live_patch/2` instead.

  ## Options

    * `:to` - the required path to link to.
    * `:replace` - the flag to replace the current history or push a new state.
      Defaults `false`.

  All other options are forwarded to the anchor tag.

  ## Examples

      <%= live_redirect "home", to: Routes.page_path(@socket, :index) %>
      <%= live_redirect "next", to: Routes.live_path(@socket, MyLive, @page + 1) %>
      <%= live_redirect to: Routes.live_path(@socket, MyLive, dir: :asc), replace: false do %>
        Sort By Price
      <% end %>

  """
  def live_redirect(%Socket{}, _) do
    raise """
    you are invoking live_redirect/2 with a socket but a socket is not expected.

    If you want to live_redirect/2 inside a LiveView, use push_redirect/2 instead.
    If you are inside a template, make the sure the first argument is a string.
    """
  end

  def live_redirect(opts, do: block) when is_list(opts) do
    live_link("redirect", block, opts)
  end

  def live_redirect(text, opts) when is_list(opts) do
    live_link("redirect", text, opts)
  end

  defp live_link(type, block_or_text, opts) do
    uri = Keyword.fetch!(opts, :to)
    replace = Keyword.get(opts, :replace, false)
    kind = if replace, do: "replace", else: "push"

    data = [phx_link: type, phx_link_state: kind]

    opts =
      opts
      |> Keyword.update(:data, data, &Keyword.merge(&1, data))
      |> Keyword.put(:href, uri)

    Phoenix.HTML.Tag.content_tag(:a, Keyword.delete(opts, :to), do: block_or_text)
  end

  @doc """
  Renders a LiveView within an originating plug request or
  within a parent LiveView.

  ## Options

    * `:session` - the map of extra session data to be serialized
      and sent to the client. Note that all session data currently in
      the connection is automatically available in LiveViews. You
      can use this option to provide extra data. Also note that the keys
      in the session are strings keys, as a reminder that data has
      to be serialized first.
    * `:container` - an optional tuple for the HTML tag and DOM
      attributes to be used for the LiveView container. For example:
      `{:li, style: "color: blue;"}`. By default it uses the module
      definition container. See the "Containers" section below for more
      information.
    * `:id` - both the DOM ID and the ID to uniquely identify a LiveView.
      An `:id` is automatically generated when rendering root LiveViews
      but it is a required option when rendering a child LiveView.
    * `:router` - an optional router that enables this LiveView to
      perform live navigation. Only a single LiveView in a page may
      have the `:router` set. LiveViews defined at the router with
      the `live` macro automatically have the `:router` option set.

  ## Examples

      # within eex template
      <%= live_render(@conn, MyApp.ThermostatLive) %>

      # within leex template
      <%= live_render(@socket, MyApp.ThermostatLive, id: "thermostat") %>

  ## Containers

  When a `LiveView` is rendered, its contents are wrapped in a container.
  By default, said container is a `div` tag with a handful of `LiveView`
  specific attributes.

  The container can be customized in different ways:

    * You can change the default `container` on `use Phoenix.LiveView`:

          use Phoenix.LiveView, container: {:tr, id: "foo-bar"}

    * You can override the container tag and pass extra attributes when
      calling `live_render` (as well as on your `live` call in your router):

          live_render socket, MyLiveView, container: {:tr, class: "highlight"}

  """
  def live_render(conn_or_socket, view, opts \\ [])

  def live_render(%Plug.Conn{} = conn, view, opts) do
    case Static.render(conn, view, opts) do
      {:ok, content, _assigns} ->
        content

      {:stop, _} ->
        raise RuntimeError, "cannot redirect from a child LiveView"
    end
  end

  def live_render(%Socket{} = parent, view, opts) do
    Static.nested_render(parent, view, opts)
  end

  @doc """
  Renders a `Phoenix.LiveComponent` within a parent LiveView.

  While `LiveView`s can be nested, each LiveView starts its
  own process. A LiveComponent provides similar functionality
  to LiveView, except they run in the same process as the
  `LiveView`, with its own encapsulated state.

  LiveComponent comes in two shapes, stateful and stateless.
  See `Phoenix.LiveComponent` for more information.

  ## Examples

  All of the `assigns` given are forwarded directly to the
  `live_component`:

      <%= live_component(@socket, MyApp.WeatherComponent, id: "thermostat", city: "Kraków") %>

  Note the `:id` won't necessarily be used as the DOM ID.
  That's up to the component. However, note that the `:id` has
  a special meaning: whenever an `:id` is given, the component
  becomes stateful. Otherwise, `:id` is always set to `nil`.
  """
  defmacro live_component(socket, component, assigns \\ [], do_block \\ []) do
    {do_block, assigns} =
      case {do_block, assigns} do
        {[do: do_block], _} -> {do_block, assigns}
        {_, [do: do_block]} -> {do_block, []}
        {_, _} -> {nil, assigns}
      end

    {assigns, inner_content} = rewrite_do(do_block, assigns, __CALLER__)

    quote do
      Phoenix.LiveView.Helpers.__live_component__(
        unquote(socket),
        unquote(component).__live__(),
        unquote(assigns),
        unquote(inner_content)
      )
    end
  end

  defp rewrite_do(nil, opts, _caller), do: {opts, nil}

  defp rewrite_do([{:->, meta, _} | _] = do_block, opts, _caller) do
    {opts, {:fn, meta, do_block}}
  end

  defp rewrite_do(do_block, opts, caller) do
    unless Macro.Env.has_var?(caller, {:assigns, nil}) and
             Macro.Env.has_var?(caller, {:changed, Phoenix.LiveView.Engine}) do
      raise ArgumentError, """
      cannot use live_component do/end blocks because we could not find existing assigns.

      Please pass a `->` clause to do/end instead, for example:

          live_component @socket, GridComponent, entries: @entries do
            new_assigns -> "New entry: " <> new_assigns[:entry]
          end
      """
    end

    quoted =
      quote do
        fn extra_assigns ->
          var!(assigns) =
            case Enum.to_list(extra_assigns) do
              [] ->
                var!(assigns)

              _ ->
                assigns = Enum.into(extra_assigns, var!(assigns))

                if var = var!(changed, Phoenix.LiveView.Engine) do
                  changed =
                    for {key, _} <- extra_assigns, key != :socket, into: var, do: {key, true}

                  put_in(assigns.__changed__, changed)
                else
                  assigns
                end
            end

          unquote(do_block)
        end
      end

    {opts, quoted}
  end

  def __live_component__(%Socket{}, %{kind: :component, module: component}, assigns, inner)
      when is_list(assigns) or is_map(assigns) do
    assigns = assigns |> Map.new() |> Map.put_new(:id, nil)
    assigns = if inner, do: Map.put(assigns, :inner_content, inner), else: assigns
    id = assigns[:id]

    if is_nil(id) and
         (function_exported?(component, :handle_event, 3) or
            function_exported?(component, :preload, 1)) do
      raise "a component #{inspect(component)} that has implemented handle_event/3 or preload/1 " <>
              "requires an :id assign to be given"
    end

    %Component{id: id, assigns: assigns, component: component}
  end

  def __live_component__(%Socket{}, %{kind: kind, module: module}, assigns)
      when is_list(assigns) or is_map(assigns) do
    raise "expected #{inspect(module)} to be a component, but it is a #{kind}"
  end

  @doc """
  Returns the flash message from the LiveView flash assign.

  ## Examples

      <p class="alert alert-info"><%= live_flash(@flash, :info) %></p>
      <p class="alert alert-danger"><%= live_flash(@flash, :error) %></p>
  """
  def live_flash(%_struct{} = other, _key) do
    raise ArgumentError, "live_flash/2 expects a @flash assign, got: #{inspect(other)}"
  end

  def live_flash(%{} = flash, key), do: Map.get(flash, to_string(key))

  @doc """
  Provides `~L` sigil with HTML safe Live EEx syntax inside source files.

      iex> ~L"\""
      ...> Hello <%= "world" %>
      ...> "\""
      {:safe, ["Hello ", "world", "\\n"]}

  """
  defmacro sigil_L({:<<>>, meta, [expr]}, []) do
    options = [
      engine: Phoenix.LiveView.Engine,
      file: __CALLER__.file,
      line: __CALLER__.line + 1,
      indentation: meta[:indentation] || 0
    ]

    EEx.compile_string(expr, options)
  end

  @doc """
  Renders a title tag with automatic prefix/suffix on `@page_title` updates.

  ## Examples

      <%= live_title_tag @page_title, prefix: "MyApp – " %>

      <%= live_title_tag @page_title, suffix: " – MyApp" %>
  """
  def live_title_tag(title, opts \\ []) do
    title_tag(title, opts[:prefix], opts[:suffix], opts)
  end

  defp title_tag(title, nil = _prefix, "" <> suffix, _opts) do
    Phoenix.HTML.Tag.content_tag(:title, title <> suffix, data: [suffix: suffix])
  end

  defp title_tag(title, "" <> prefix, nil = _suffix, _opts) do
    Phoenix.HTML.Tag.content_tag(:title, prefix <> title, data: [prefix: prefix])
  end

  defp title_tag(title, "" <> pre, "" <> post, _opts) do
    Phoenix.HTML.Tag.content_tag(:title, pre <> title <> post, data: [prefix: pre, suffix: post])
  end

  defp title_tag(title, _prefix = nil, _postfix = nil, []) do
    Phoenix.HTML.Tag.content_tag(:title, title)
  end

  defp title_tag(_title, _prefix = nil, _suffix = nil, opts) do
    raise ArgumentError,
          "live_title_tag/2 expects a :prefix and/or :suffix option, got: #{inspect(opts)}"
  end
end
