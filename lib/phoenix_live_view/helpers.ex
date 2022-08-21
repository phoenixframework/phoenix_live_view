defmodule Phoenix.LiveView.Helpers do
  @moduledoc """
  A collection of helpers to be imported into your views.
  """
  use Phoenix.Component

  alias Phoenix.LiveView.{Component, Socket, Utils}

  @doc """
  Provides `~L` sigil with HTML safe Live EEx syntax inside source files.

      iex> ~L"\""
      ...> Hello <%= "world" %>
      ...> "\""
      {:safe, ["Hello ", "world", "\\n"]}

  """
  @doc deprecated: "Use ~H instead"
  defmacro sigil_L({:<<>>, meta, [expr]}, []) do
    options = [
      engine: Phoenix.LiveView.Engine,
      file: __CALLER__.file,
      line: __CALLER__.line + 1,
      indentation: meta[:indentation] || 0
    ]

    EEx.compile_string(expr, options)
  end

  @doc deprecated: "Use link/1 instead"
  # TODO @deprecate in 0.19, remove in 0.20
  def live_patch(opts) when is_list(opts) do
    live_link("patch", Keyword.fetch!(opts, :do), Keyword.delete(opts, :do))
  end

  @doc deprecated: "Use <.link> instead"
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

  @doc deprecated: "Use <.link> instead"
  # TODO @deprecate in 0.19, remove in 0.20
  def live_redirect(opts) when is_list(opts) do
    live_link("redirect", Keyword.fetch!(opts, :do), Keyword.delete(opts, :do))
  end

  @doc deprecated: "Use <.link> instead"
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
      |> Keyword.delete(:to)

    assigns = %{opts: opts, content: block_or_text}

    ~H|<a {@opts}><%= @content %></a>|
  end

  @doc """
  Deprecated API for rendering `LiveComponent`.

  ## Upgrading

  In order to migrate from `<%= live_component ... %>` to `<.live_component>`,
  you must first:

    1. Migrate from `~L` sigil and `.leex` templates to
      `~H` sigil and `.heex` templates

    2. Then instead of:

       ```
       <%= live_component MyModule, id: "hello" do %>
       ...
       <% end %>
       ```

       You should do:

       ```
       <.live_component module={MyModule} id="hello">
       ...
       </.live_component>
       ```

    3. If your component is using `render_block/2`, replace
       it by `render_slot/2`

  """
  @doc deprecated: "Use .live_component (live_component/1) instead"
  defmacro live_component(component, assigns, do_block \\ []) do
    if is_assign?(:socket, component) do
      IO.warn(
        "passing the @socket to live_component is no longer necessary, " <>
          "please remove the socket argument",
        Macro.Env.stacktrace(__CALLER__)
      )
    end

    {inner_block, do_block, assigns} =
      case {do_block, assigns} do
        {[do: do_block], _} -> {rewrite_do!(do_block, :inner_block, __CALLER__), [], assigns}
        {_, [do: do_block]} -> {rewrite_do!(do_block, :inner_block, __CALLER__), [], []}
        {_, _} -> {nil, do_block, assigns}
      end

    if match?({:__aliases__, _, _}, component) or is_atom(component) or is_list(assigns) or
         is_map(assigns) do
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

  @doc false
  def __live_component__(%{kind: :component, module: component}, assigns, inner)
      when is_list(assigns) or is_map(assigns) do
    assigns = assigns |> Map.new() |> Map.put_new(:id, nil)
    assigns = if inner, do: Map.put(assigns, :inner_block, inner), else: assigns
    id = assigns[:id]

    # TODO: Remove logic from Diff once stateless components are removed.
    # TODO: Remove live_component arity checks from Engine
    if is_nil(id) and
         (function_exported?(component, :handle_event, 3) or
            function_exported?(component, :preload, 1)) do
      raise "a component #{inspect(component)} that has implemented handle_event/3 or preload/1 " <>
              "requires an :id assign to be given"
    end

    %Component{id: id, assigns: assigns, component: component}
  end

  def __live_component__(%{kind: kind, module: module}, assigns, _inner)
      when is_list(assigns) or is_map(assigns) do
    raise "expected #{inspect(module)} to be a component, but it is a #{kind}"
  end

  defp rewrite_do!(do_block, key, caller) do
    if Macro.Env.has_var?(caller, {:assigns, nil}) do
      # TODO: make __inner_block__ private once this is removed.
      Phoenix.LiveView.HTMLEngine.__inner_block__(do_block, key)
    else
      raise ArgumentError,
            "cannot use live_component because the assigns var is unbound/unset"
    end
  end

  @doc """
  Renders the `@inner_block` assign of a component with the given `argument`.

      <%= render_block(@inner_block, value: @value)

  This function is deprecated for function components. Use `render_slot/2`
  instead.
  """
  @doc deprecated: "Use render_slot/2 instead"
  defmacro render_block(inner_block, argument \\ []) do
    quote do
      unquote(__MODULE__).__render_block__(unquote(inner_block)).(
        var!(changed, Phoenix.LiveView.Engine),
        unquote(argument)
      )
    end
  end

  @doc false
  def __render_block__([%{inner_block: fun}]), do: fun
  def __render_block__(fun), do: fun

  @doc """
  Generates an image preview on the client for a selected file.

  ## Examples

      <%= for entry <- @uploads.avatar.entries do %>
        <%= live_img_preview entry, width: 75 %>
      <% end %>
  """
  # TODO: convert to function component
  def live_img_preview(%Phoenix.LiveView.UploadEntry{ref: ref} = entry, opts \\ []) do
    attrs =
      Keyword.merge(opts,
        id: opts[:id] || "phx-preview-#{ref}",
        data_phx_upload_ref: entry.upload_ref,
        data_phx_entry_ref: ref,
        data_phx_hook: "Phoenix.LiveImgPreview",
        data_phx_update: "ignore"
      )

    assigns = assign(%{__changed__: nil}, attrs: attrs)

    ~H"<img {@attrs}/>"
  end

  @doc """
  Builds a file input tag for a LiveView upload.

  ## Attributes

    * `:upload` - The `%Phoenix.LiveView.UploadConfig{}` struct.

  Arbitrary attributes may be passed to be applied to the file input tag.

  ## Drag and Drop

  Drag and drop is supported by annotating the droppable container with a `phx-drop-target`
  attribute pointing to the DOM ID of the file input. By default, the file input ID is the
  upload `ref`, so the following markup is all that is required for drag and drop support:

      <div class="container" phx-drop-target={@uploads.avatar.ref}>
          ...
          <.live_file_input upload={@uploads.avatar} />
      </div>

  ## Examples

      <.live_file_input upload={@uploads.avatar} />
  """
  # TODO deprecated, remove non-function component form in in 0.20
  def live_file_input(%Phoenix.LiveView.UploadConfig{} = conf, opts) when is_list(opts) do
    require Phoenix.LiveViewTest
    assigns = Enum.into(opts, %{upload: conf})
    {:safe, Phoenix.LiveViewTest.render_component(&live_file_input/1, assigns)}
  end

  # TODO deprecated, remove non-function component form in in 0.20
  def live_file_input(%Phoenix.LiveView.UploadConfig{} = conf) do
    live_file_input(conf, [])
  end

  # attr :upload, Phoenix.LiveView.UploadConfig, required: true
  # attr :rest, :global
  # TODO define attrs
  def live_file_input(%{} = assigns) do
    conf =
      case assigns do
        %{id: _} -> raise ArgumentError, "the :id cannot be overridden on a live_file_input"
        %{upload: %Phoenix.LiveView.UploadConfig{} = conf} -> conf
        %{} -> raise ArgumentError, "missing required :upload attribute to <.live_file_input/>"
      end

    rest = assigns_to_attributes(assigns, [:upload])

    rest =
      if conf.max_entries > 1 do
        Keyword.put(rest, :multiple, true)
      else
        rest
      end

    preflighted_entries = for entry <- conf.entries, entry.preflighted?, do: entry
    done_entries = for entry <- conf.entries, entry.done?, do: entry
    valid? = Enum.any?(conf.entries) && Enum.empty?(conf.errors)

    rest =
      Keyword.merge(rest,
        data_phx_update: "ignore",
        data_phx_upload_ref: conf.ref,
        data_phx_active_refs: Enum.map_join(conf.entries, ",", & &1.ref),
        data_phx_done_refs: Enum.map_join(done_entries, ",", & &1.ref),
        data_phx_preflighted_refs: Enum.map_join(preflighted_entries, ",", & &1.ref),
        data_phx_auto_upload: valid? && conf.auto_upload?
      )

    assigns = assign(assigns, :rest, rest)

    ~H"""
    <input
      id={@upload.ref}
      type="file"
      name={@upload.name}
      accept={@upload.accept != :any && @upload.accept}
      phx-hook="Phoenix.LiveFileUpload"
      {@rest}
    />
    """
  end

  @doc """
  Renders a title with automatic prefix/suffix on `@page_title` updates.

  ## Examples

      <.live_title prefix="MyApp – "><%= assigns[:page_title] || "Welcome" %></.live_title>

      <.live_title suffix="- MyApp"><%= assigns[:page_title] || "Welcome" %></.live_title>

  """
  attr :prefix, :string, default: nil
  attr :suffix, :string, default: nil

  def live_title(assigns) do
    ~H"""
    <title data-prefix={@prefix} data-suffix={@suffix}><%= @prefix %><%= render_slot(@inner_block) %><%= @suffix %></title>
    """
  end

  @doc """
  Renders a title tag with automatic prefix/suffix on `@page_title` updates.

  ## Examples

      <%= live_title_tag assigns[:page_title] || "Welcome", prefix: "MyApp – " %>

      <%= live_title_tag assigns[:page_title] || "Welcome", suffix: " – MyApp" %>
  """
  @doc deprecated: "Use <.live_title> instead"
  # TODO deprecate in 0.19, remove in 0.20
  def live_title_tag(title, opts \\ []) do
    assigns = %{title: title, prefix: opts[:prefix], suffix: opts[:suffix]}

    ~H"""
    <.live_title prefix={@prefix} suffix={@suffix}><%= @title %></.live_title>
    """
  end

  @doc """
  Renders a form.

  This function is built on top of `Phoenix.HTML.Form.form_for/4`. For
  more information about options and how to build inputs, see
  `Phoenix.HTML.Form`.

  ## Options

  The following attribute is required:

    * `:for` - the form source data

  The following attributes are optional:

    * `:action` - the action to submit the form on. This attribute must be
      given if you intend to submit the form to a URL without LiveView.

    * `:as` - the server side parameter in which all params for this
      form will be collected (i.e. `as: :user_params` would mean all fields
      for this form will be accessed as `conn.params.user_params` server
      side). Automatically inflected when a changeset is given.

    * `:multipart` - when true, sets enctype to "multipart/form-data".
      Required when uploading files

    * `:method` - the HTTP method. It is only used if an `:action` is given.
      If the method is not "get" nor "post", an input tag with name `_method`
      is generated along-side the form tag. Defaults to "post".

    * `:csrf_token` - a token to authenticate the validity of requests.
      One is automatically generated when an action is given and the method
      is not "get". When set to false, no token is generated.

    * `:errors` - use this to manually pass a keyword list of errors to the form
      (for example from `conn.assigns[:errors]`). This option is only used when a
      connection is used as the form source and it will make the errors available
      under `f.errors`

    * `:id` - the ID of the form attribute. If an ID is given, all form inputs
      will also be prefixed by the given ID

  All further assigns will be passed to the form tag.

  ## Examples

  ### Inside LiveView

  The `:for` attribute is typically an [`Ecto.Changeset`](https://hexdocs.pm/ecto/Ecto.Changeset.html):

      <.form :let={f} for={@changeset} phx-change="change_name">
        <%= text_input f, :name %>
      </.form>

      <.form :let={user_form} for={@changeset} multipart phx-change="change_user" phx-submit="save_user">
        <%= text_input user_form, :name %>
        <%= submit "Save" %>
      </.form>

  Notice how both examples use `phx-change`. The LiveView must implement
  the `phx-change` event and store the input values as they arrive on
  change. This is important because, if an unrelated change happens on
  the page, LiveView should re-render the inputs with their updated values.
  Without `phx-change`, the inputs would otherwise be cleared. Alternatively,
  you can use `phx-update="ignore"` on the form to discard any updates.

  The `:for` attribute can also be an atom, in case you don't have an
  existing data layer but you want to use the existing form helpers.
  In this case, you need to pass the input values explicitly as they
  change (or use `phx-update="ignore"` as per the previous paragraph):

      <.form :let={user_form} for={:user} multipart phx-change="change_user" phx-submit="save_user">
        <%= text_input user_form, :name, value: @user_name %>
        <%= submit "Save" %>
      </.form>

  In those cases, it may be more straight-forward to drop `:let` altogether
  and simply rely on HTML to generate inputs:

      <.form for={:form} multipart phx-change="change_user" phx-submit="save_user">
        <input type="text" name="user[name]" value={@user_name}>
        <input type="submit" name="Save">
      </.form>

  ### Outside LiveView

  The `form` component can still be used to submit forms outside
  of LiveView. In such cases, the `action` attribute MUST be given.
  Without said attribute, the `form` method and csrf token are
  discarded.

      <.form :let={f} for={@changeset} action={Routes.comment_path(:create, @comment)}>
        <%= text_input f, :body %>
      </.form>
  """
  attr :for, :any, required: true
  attr :action, :string, default: nil
  attr :as, :atom
  attr :multipart, :boolean, default: false
  attr :method, :string
  attr :csrf_token, :boolean
  attr :errors, :list
  attr :rest, :global

  def form(assigns) do
    # Extract options and then to the same call as form_for
    action = assigns[:action]
    form_for = assigns[:for] || raise ArgumentError, "missing :for assign to form"
    form_options = assigns_to_attributes(Map.merge(assigns, assigns.rest), [:action, :for, :rest])

    # Since FormData may add options, read the actual options from form
    %{options: opts} =
      form = %Phoenix.HTML.Form{
        Phoenix.HTML.FormData.to_form(form_for, form_options)
        | action: action || "#"
      }

    # By default, we will ignore action, method, and csrf token
    # unless the action is given.
    {attrs, hidden_method, csrf_token} =
      if action do
        {method, opts} = Keyword.pop(opts, :method, "post")
        {method, hidden_method} = form_method(method)

        {csrf_token, opts} =
          Keyword.pop_lazy(opts, :csrf_token, fn ->
            if method == "post" do
              Plug.CSRFProtection.get_csrf_token_for(action)
            end
          end)

        {[action: action, method: method] ++ opts, hidden_method, csrf_token}
      else
        {opts, nil, nil}
      end

    attrs =
      case Keyword.pop(attrs, :multipart, false) do
        {false, attrs} -> attrs
        {true, attrs} -> Keyword.put(attrs, :enctype, "multipart/form-data")
      end

    assigns =
      assign(assigns,
        form: form,
        csrf_token: csrf_token,
        hidden_method: hidden_method,
        attrs: attrs
      )

    ~H"""
    <form {@attrs}>
      <%= if @hidden_method && @hidden_method not in ~w(get post) do %>
        <input name="_method" type="hidden" value={@hidden_method}>
      <% end %>
      <%= if @csrf_token do %>
        <input name="_csrf_token" type="hidden" value={@csrf_token}>
      <% end %>
      <%= render_slot(@inner_block, @form) %>
    </form>
    """
  end

  defp form_method(method) when method in ~w(get post), do: {method, nil}
  defp form_method(method) when is_binary(method), do: {"post", method}

  @doc """
  Generates a link for live and href navigation.

  There are three possible types of links, in the order of efficiency:

    * `:href` - uses traditional browser navigation to the new location.
      This means the whole page is reloaded on the browser.

    * `:navigate` - navigates from a LiveView to a new LiveView. The browser
      page is kept, but a new LiveView process is mounted and its content
      on the page reloaded. It is only possible to navigate between LiveViews
      declared under the same router `Phoenix.LiveView.Router.live_session/3`.
      Otherwise a full browser redirect is used.

    * `:patch` - patches the current LiveView. The `handle_params` callback
      of the current LiveView will be invoked and the minimum content will be
      sent over there wire, as any other LiveView diff.

  ## Attributes

    * `:method` - the method to use with the link. In case the method is not
      `:get`, the link is generated inside the form which sets the proper
      information. In order to submit the form, JavaScript must be enabled.

    * `:csrf_token` - a custom token to use for links with a method
      other than `:get`.

     * `:replace` - when using `:patch` or `:navigate`, whether to replace the
       browser's pushState history. Default false.

  Arbitrary global attributes, such as `class`, `id`, etc, will be applied to the
  generated `a` tag.

  ## Examples

      <.link href="/">Regular anchor link</.link>

      <.link navigate={Routes.page_path(@socket, :index)} class="underline">home</.link>

      <.link navigate={Routes.live_path(@socket, MyLive, dir: :asc)} replace={false}>
        Sort By Price
      </.link>

      <.link patch={Routes.page_path(@socket, :index, :details)}>view details</.link>

      <.link href={URI.parse("https://elixir-lang.org")}>hello</.link>

      <.link href="/the_world" method={:delete} data-confirm="Really?">delete</.link>

  ## JavaScript dependency

  In order to support links where `:method` is not `:get` or use the above
  data attributes, `Phoenix.HTML` relies on JavaScript. You can load
  `priv/static/phoenix_html.js` into your build tool.

  ### Data attributes

  Data attributes are added as a keyword list passed to the `data` key.
  The following data attributes are supported:

    * `data-confirm` - shows a confirmation prompt before
      generating and submitting the form when `:method`
      is not `:get`.

  ### Overriding the default confirm behaviour

  `phoenix_html.js` does trigger a custom event `phoenix.link.click` on the
  clicked DOM element when a click happened. This allows you to intercept the
  event on it's way bubbling up to `window` and do your own custom logic to
  enhance or replace how the `data-confirm` attribute is handled.
  You could for example replace the browsers `confirm()` behavior with a
  custom javascript implementation:

  ```javascript
  // listen on document.body, so it's executed before the default of
  // phoenix_html, which is listening on the window object
  document.body.addEventListener('phoenix.link.click', function (e) {
    // Prevent default implementation
    e.stopPropagation();
    // Introduce alternative implementation
    var message = e.target.getAttribute("data-confirm");
    if(!message){ return true; }
    vex.dialog.confirm({
      message: message,
      callback: function (value) {
        if (value == false) { e.preventDefault(); }
      }
    })
  }, false);
  ```

  Or you could attach your own custom behavior.

  ```javascript
  window.addEventListener('phoenix.link.click', function (e) {
    // Introduce custom behaviour
    var message = e.target.getAttribute("data-prompt");
    var answer = e.target.getAttribute("data-prompt-answer");
    if(message && answer && (answer != window.prompt(message))) {
      e.preventDefault();
    }
  }, false);
  ```

  The latter could also be bound to any `click` event, but this way you can be
  sure your custom code is only executed when the code of `phoenix_html.js` is run.

  ## CSRF Protection
  By default, CSRF tokens are generated through `Plug.CSRFProtection`.
  """

  attr :navigate, :string
  attr :patch, :string
  attr :href, :any
  attr :replace, :boolean, default: false
  attr :method, :string, default: "get"
  attr :csrf_token, :string
  attr :rest, :global

  def link(%{navigate: _to} = assigns) do
    ~H"""
    <a
      href={@navigate}
      data-phx-link="redirect"
      data-phx-link-state={if @replace, do: "replace", else: "push"}
      {@rest}
    ><%= render_slot(@inner_block) %></a>
    """
  end

  def link(%{patch: _to} = assigns) do
    ~H"""
    <a
      href={@patch}
      data-phx-link="patch"
      data-phx-link-state={if @replace, do: "replace", else: "push"}
      {@rest}
    ><%= render_slot(@inner_block) %></a>
    """
  end

  def link(%{href: href} = assigns) when href != "#" do
    if is_nil(href), do: raise(ArgumentError, "expected non-nil value for :href in <.link>")

    assigns =
      case Utils.valid_destination!(href, "<.link>") do
        href when is_binary(href) ->
          assigns
          |> assign(:href, href)
          |> assign_new(:csrf_token, fn -> Phoenix.HTML.Tag.csrf_token_value(href) end)

        href ->
          assign(assigns, :href, href)
      end

    ~H"""
    <a
      href={if @method == "get", do: @href, else: "#"}
      data-method={if @method != "get", do: @method}
      data-csrf={if @method != "get", do: @csrf_token}
      data-to={if @method != "get", do: @href}
      {@rest}
    ><%= render_slot(@inner_block) %></a>
    """
  end

  def link(%{} = assigns) do
    ~H"""
    <a href="#" {@rest}><%= render_slot(@inner_block) %></a>
    """
  end

  @doc """
  Wraps tab focus around a container for accessibility.

  This is an essential accessibility feature for interfaces
  such as modals, dialogs, and menus.

  ## Attributes

    * `:id` - The required string container ID

  All other HTML attributes are applied to the rendered container.

  ## Examples

  Simply render your inner content within this component and
  focus will be wrapped around the container as the user tabs
  through the containers content.

      <.focus_wrap id="my-modal" class="bg-white">
        <div id="modal-content">
          Are you sure?
          <button phx-click="cancel">Cancel</button>
          <button phx-click="confirm">OK</button>
        </div>
      </.focus_wrap>
  """
  attr :id, :string, required: true
  attr :rest, :global

  def focus_wrap(assigns) do
    ~H"""
    <div id={@id} phx-hook="Phoenix.FocusWrap" {@rest}>
      <span id={"#{@id}-start"} tabindex="0" aria-hidden="true"></span>
      <%= render_slot(@inner_block) %>
      <span id={"#{@id}-end"} tabindex="0" aria-hidden="true"></span>
    </div>
    """
  end

  @doc """
  Generates a dynamically named HTML tag.

  Raises ArgumentError if the tag name is found to be unsafe HTML.

  ## Attributes

    * `:name` - The required  name of the tag, such as: "div"

  All other attributes are added to the generated tag, ensuring
  proper HTML escaping.

  ## Examples

      <.dynamic_tag name="input" type="text"/>
      => "<input type="text"/>

      <.dynamic_tag name="p">content</.dynamic_tag>
      => "<p>content</p>"
  """
  attr :name, :string, required: true
  attr :rest, :global

  def dynamic_tag(%{name: name, rest: rest} = assigns) do
    tag_name = to_string(name)

    tag =
      case Phoenix.HTML.html_escape(tag_name) do
        {:safe, ^tag_name} ->
          tag_name

        {:safe, _escaped} ->
          raise ArgumentError,
                "expected dynamic_tag name to be safe HTML, got: #{inspect(tag_name)}"
      end

    assigns =
      assigns
      |> assign(:tag, tag)
      |> assign(:escaped_attrs, Phoenix.HTML.attributes_escape(rest))

    if Map.has_key?(assigns, :inner_block) do
      ~H"""
      <%= {:safe, [?<, @tag]} %><%= @escaped_attrs %><%= {:safe, [?>]} %><%= render_slot(@inner_block) %><%= {:safe, [?<, ?/, @tag, ?>]} %>
      """
    else
      ~H"""
      <%= {:safe, [?<, @tag]} %><%= @escaped_attrs %><%= {:safe, [?/, ?>]} %>
      """
    end
  end

  defp is_assign?(assign_name, expression) do
    match?({:@, _, [{^assign_name, _, _}]}, expression) or
      match?({^assign_name, _, _}, expression) or
      match?({{:., _, [{:assigns, _, nil}, ^assign_name]}, _, []}, expression)
  end
end
