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

  When navigating to the current LiveView,
  `c:Phoenix.LiveView.handle_params/3` is
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
  def live_patch(text, opts)

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
  def live_redirect(text, opts)

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

      <%= live_component(MyApp.WeatherComponent, id: "thermostat", city: "Kraków") %>

  Note the `:id` won't necessarily be used as the DOM ID.
  That's up to the component. However, note that the `:id` has
  a special meaning: whenever an `:id` is given, the component
  becomes stateful. Otherwise, `:id` is always set to `nil`.
  """
  defmacro live_component(component, assigns \\ [], do_block \\ []) do
    if match?({:@, _, [{:socket, _, _}]}, component) or match?({:socket, _, _}, component) do
      IO.warn(
        "passing the @socket to live_component is no longer necessary, " <>
          "please remove the socket argument",
        Macro.Env.stacktrace(__CALLER__)
      )
    end

    {inner_block, do_block, assigns} =
      case {do_block, assigns} do
        {[do: do_block], _} -> {rewrite_do(do_block, __CALLER__), [], assigns}
        {_, [do: do_block]} -> {rewrite_do(do_block, __CALLER__), [], []}
        {_, _} -> {nil, do_block, assigns}
      end

    if match?({:__aliases__, _, _}, component) or is_atom(component) or is_list(assigns) or is_map(assigns) do
      quote do
        Phoenix.LiveView.Helpers.__live_component__(
          unquote(component).__live__(),
          unquote(assigns),
          unquote(inner_block)
        )
      end
    else
      quote do
        case unquote(component) do
          %Phoenix.LiveView.Socket{} ->
            Phoenix.LiveView.Helpers.__live_component__(
              unquote(assigns).__live__(),
              unquote(do_block),
              unquote(inner_block)
            )

          component ->
            Phoenix.LiveView.Helpers.__live_component__(
              component.__live__(),
              unquote(assigns),
              unquote(inner_block)
            )
        end
      end
    end
  end

  defmacro live_component(socket, component, assigns, do_block) do
    IO.warn(
      "passing the @socket to live_component is no longer necessary, " <>
        "please remove the socket argument",
      Macro.Env.stacktrace(__CALLER__)
    )

    {inner_block, assigns} =
      case {do_block, assigns} do
        {[do: do_block], _} -> {rewrite_do(do_block, __CALLER__), assigns}
        {_, [do: do_block]} -> {rewrite_do(do_block, __CALLER__), []}
        {_, _} -> {nil, assigns}
      end

    quote do
      # Fixes unused variable compilation warning
      _ = unquote(socket)

      Phoenix.LiveView.Helpers.__live_component__(
        unquote(component).__live__(),
        unquote(assigns),
        unquote(inner_block)
      )
    end
  end

  @doc """
  Renders a component defined by the given function.

  It takes two optional arguments, the assigns to pass to the given function
  and a do-block - which will be converted into a `@inner_block`  assign (see
  `render_block/3` for more information).

  The given function must expect one argument, which are the `assigns` as a
  map.

  ## Examples

  The function can be either local:

      <%= component(&weather_component/1, city: "Kraków") %>

  Or remote:

      <%= component(&MyApp.Weather.component/1, city: "Kraków") %>

  """
  defmacro component(func, assigns \\ [], do_block \\ []) do
    {inner_block, assigns} =
      case {do_block, assigns} do
        {[do: do_block], _} -> {rewrite_do(do_block, __CALLER__), assigns}
        {_, [do: do_block]} -> {rewrite_do(do_block, __CALLER__), []}
        {_, _} -> {nil, assigns}
      end

    quote do
      Phoenix.LiveView.Helpers.__component__(
        unquote(func),
        unquote(assigns),
        unquote(inner_block)
      )
    end
  end

  defp rewrite_do([{:->, meta, _} | _] = do_block, _caller) do
    inner_fun = {:fn, meta, do_block}

    quote do
      fn parent_changed, arg ->
        var!(assigns) = unquote(__MODULE__).__render_inner_fun__(var!(assigns), parent_changed)
        unquote(inner_fun).(arg)
      end
    end
  end

  defp rewrite_do(do_block, caller) do
    unless Macro.Env.has_var?(caller, {:assigns, nil}) and
             Macro.Env.has_var?(caller, {:changed, Phoenix.LiveView.Engine}) do
      raise ArgumentError, """
      cannot use live_component do/end blocks because we could not find existing assigns.

      Please pass a `->` clause to do/end instead, for example:

          live_component GridComponent, entries: @entries do
            new_assigns -> "New entry: " <> new_assigns[:entry]
          end
      """
    end

    # TODO: deprecate implicit assigns (i.e. do/end without -> should not get any assign)
    quote do
      fn changed, extra_assigns ->
        var!(assigns) =
          unquote(__MODULE__).__render_inner_do__(var!(assigns), changed, extra_assigns)

        unquote(do_block)
      end
    end
  end

  @doc false
  def __render_inner_fun__(assigns, parent_changed) do
    if is_nil(parent_changed) or parent_changed[:inner_block] == true do
      assigns
    else
      Map.put(assigns, :__changed__, %{})
    end
  end

  @doc false
  def __render_inner_do__(assigns, parent_changed, extra_assigns) do
    # If the parent is tracking changes or the inner content changed,
    # we will keep the current __changed__ values
    changed =
      if is_nil(parent_changed) or parent_changed[:inner_block] == true do
        Map.get(assigns, :__changed__)
      else
        %{}
      end

    assigns = Enum.into(extra_assigns, assigns)

    changed =
      changed &&
        for {key, _} <- extra_assigns,
            key != :socket,
            into: changed,
            do: {key, true}

    Map.put(assigns, :__changed__, changed)
  end

  @doc false
  def __live_component__(%{kind: :component, module: component}, assigns, inner)
      when is_list(assigns) or is_map(assigns) do
    assigns = assigns |> Map.new() |> Map.put_new(:id, nil)
    assigns = if inner, do: Map.put(assigns, :inner_block, inner), else: assigns
    id = assigns[:id]

    # TODO: Deprecate stateless live component
    if is_nil(id) and
         (function_exported?(component, :handle_event, 3) or
            function_exported?(component, :preload, 1)) do
      raise "a component #{inspect(component)} that has implemented handle_event/3 or preload/1 " <>
              "requires an :id assign to be given"
    end

    %Component{id: id, assigns: assigns, component: component}
  end

  def __live_component__(%{kind: kind, module: module}, assigns)
      when is_list(assigns) or is_map(assigns) do
    raise "expected #{inspect(module)} to be a component, but it is a #{kind}"
  end

  @doc false
  def __component__(func, assigns, inner)
      when is_function(func, 1) and is_list(assigns) or is_map(assigns) do
    assigns = Map.new(assigns)
    assigns = if inner, do: Map.put(assigns, :inner_block, inner), else: assigns

    func.(assigns)
  end

  def __component__(func, assigns, _) when is_list(assigns) or is_map(assigns) do
    raise ArgumentError, """
    component/3 expected an anonymous function with 1-arity, got: #{inspect(func)}

    Please call component with a 1-arity function, for example:

        <%= component &func/1 %>

        def func(assigns) do
          ~L\"""
          Hello
          \"""
        end
    """
  end

  @doc """
  Renders the `@inner_block` assign of a component with the given `argument`.

      <%= render_block(@inner_block, value: @value)

  """
  defmacro render_block(inner_block, argument \\ []) do
    quote do
      unquote(inner_block).(var!(changed, Phoenix.LiveView.Engine), unquote(argument))
    end
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
  Returns the entry errors for an upload.

  The following errors may be returned:

    * `:too_many_files` - The number of selected files exceeds the `:max_entries` constraint

  ## Examples

      def error_to_string(:too_many_files), do: "You have selected too many files"

      <%= for err <- upload_errors(@uploads.avatar) do %>
        <div class="alert alert-danger">
          <%= error_to_string(err) %>
        </div>
      <% end %>
  """
  def upload_errors(%Phoenix.LiveView.UploadConfig{} = conf) do
    for {ref, error} <- conf.errors, ref == conf.ref, do: error
  end

  @doc """
  Returns the entry errors for an upload.

  The following errors may be returned:

    * `:too_large` - The entry exceeds the `:max_file_size` constraint
    * `:not_accepted` - The entry does not match the `:accept` MIME types

  ## Examples

      def error_to_string(:too_large), do: "Too large"
      def error_to_string(:not_accepted), do: "You have selected an unacceptable file type"

      <%= for entry <- @uploads.avatar.entries do %>
        <%= for err <- upload_errors(@uploads.avatar, entry) do %>
          <div class="alert alert-danger">
            <%= error_to_string(err) %>
          </div>
        <% end %>
      <% end %>
  """
  def upload_errors(
        %Phoenix.LiveView.UploadConfig{} = conf,
        %Phoenix.LiveView.UploadEntry{} = entry
      ) do
    for {ref, error} <- conf.errors, ref == entry.ref, do: error
  end

  @doc """
  Generates an image preview on the client for a selected file.

  ## Examples

      <%= for entry <- @uploads.avatar.entries do %>
        <%= live_img_preview entry, width: 75 %>
      <% end %>
  """
  def live_img_preview(%Phoenix.LiveView.UploadEntry{ref: ref} = entry, opts \\ []) do
    opts =
      Keyword.merge(opts,
        id: "phx-preview-#{ref}",
        data_phx_upload_ref: entry.upload_ref,
        data_phx_entry_ref: ref,
        data_phx_hook: "Phoenix.LiveImgPreview",
        data_phx_update: "ignore"
      )

    Phoenix.HTML.Tag.content_tag(:img, "", opts)
  end

  @doc """
  Builds a file input tag for a LiveView upload.

  Options may be passed through to the tag builder for custom attributes.

  ## Drag and Drop

  Drag and drop is supported by annotating the droppable container with a `phx-drop-target`
  attribute pointing to the DOM ID of the file input. By default, the file input ID is the
  upload `ref`, so the following markup is all that is required for drag and drop support:

      <div class="container" phx-drop-target="<%= @uploads.avatar.ref %>">
          ...
          <%= live_file_input @uploads.avatar %>
      </div>

  ## Examples

      <%= live_file_input @uploads.avatar %>
  """
  def live_file_input(%Phoenix.LiveView.UploadConfig{} = conf, opts \\ []) do
    if opts[:id], do: raise(ArgumentError, "the :id cannot be overridden on a live_file_input")

    opts =
      if conf.max_entries > 1 do
        Keyword.put(opts, :multiple, true)
      else
        opts
      end

    preflighted_entries = for entry <- conf.entries, entry.preflighted?, do: entry
    done_entries = for entry <- conf.entries, entry.done?, do: entry
    valid? = Enum.any?(conf.entries) && Enum.empty?(conf.errors)

    Phoenix.HTML.Tag.content_tag(
      :input,
      "",
      Keyword.merge(opts,
        type: "file",
        id: conf.ref,
        name: conf.name,
        accept: if(conf.accept != :any, do: conf.accept),
        phx_hook: "Phoenix.LiveFileUpload",
        data_phx_update: "ignore",
        data_phx_upload_ref: conf.ref,
        data_phx_active_refs: Enum.map_join(conf.entries, ",", & &1.ref),
        data_phx_done_refs: Enum.map_join(done_entries, ",", & &1.ref),
        data_phx_preflighted_refs: Enum.map_join(preflighted_entries, ",", & &1.ref),
        data_phx_auto_upload: valid? && conf.auto_upload?
      )
    )
  end

  @doc """
  Renders a title tag with automatic prefix/suffix on `@page_title` updates.

  ## Examples

      <%= live_title_tag assigns[:page_title] || "Welcome", prefix: "MyApp – " %>

      <%= live_title_tag assigns[:page_title] || "Welcome", suffix: " – MyApp" %>
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
