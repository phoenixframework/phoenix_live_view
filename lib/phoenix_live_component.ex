defmodule Phoenix.LiveComponent do
  @moduledoc ~S"""
  Components are a mechanism to compartmentalize state, markup, and
  events in LiveView.

  Components are defined by using `Phoenix.LiveComponent` and are used
  by calling `Phoenix.LiveView.live_component/3` in a parent LiveView.
  Components run inside the LiveView process, but may have their own
  state and event handling.

  The simplest component only needs to define a `render` function:

      defmodule HeroComponent do
        use Phoenix.LiveComponent

        def render(assigns) do
          ~L"\""
          <div class="hero"><%= @content %></div>
          "\""
        end
      end

  When `use Phoenix.LiveComponent` is used, all functions in
  `Phoenix.LiveView` are imported. A component can be invoked as:

      <%= live_component @socket, HeroComponent, content: @content %>

  Components come in two shapes, stateless or stateful. The component
  above is a stateless component. Of course, the component above is not
  any different compared to a regular function. However, as we will see,
  components do provide their own exclusive feature set.

  ## Stateless components life-cycle

  When `live_component` is called, the following callbacks will be invoked
  in the component:

      mount(socket) -> update(assigns, socket) -> render(assigns)

  First `c:mount/1` is called only with the socket. `mount/1` can be used
  to set any initial state. Then `c:update/2` is invoked with all of the
  assigns given to `live_component/2`. The default implementation of
  `c:update/2` simply merges all assigns into the socket. Then, after the
  component is updated, `c:render/1` is called with all assigns.

  A stateless component is always mounted, updated, and rendered whenever
  the parent template changes. That's why they are stateless: no state
  is kept after the component.

  However, any component can be made stateful by passing an `:id` assign.

  ## Stateful components life-cycle

  A stateful component is a component that receives an `:id` on `live_component/2`:

      <%= live_component @socket, HeroComponent, id: :hero, content: @content %>

  Stateful components are identified by the component module and their ID.
  Therefore, two different component modules with the same ID are different
  components. This means we can often tie the component ID to some application
  based ID:

      <%= live_component @socket, UserComponent, id: @user.id, user: @user %>

  Also note the given `:id` is not necessarily used as the DOM ID. If you
  want to set a DOM ID, it is your responsibility to set it when rendering:

      defmodule HeroComponent do
        use Phoenix.LiveComponent

        def render(assigns) do
          ~L"\""
          <div id="<%= @id %>" class="hero"><%= @content %></div>
          "\""
        end
      end

  In stateful components, `c:mount/1` is called only once, when the
  component is first rendered. Then for each rendering, the optional
  `c:preload/1` and `c:update/2` callbacks are called before `c:render/1`.

  Stateful components can also implement a `handle_event/3` callback,
  that works exactly the same as in LiveView. When `handle_event/3` is
  called for a component, only the diff of the component is sent to the
  client, making them extremely efficient.

  ### Preloading and update

  Every time a stateful component is rendered, both `c:preload/1` and
  `c:update/2` is called. To understand why both callbacks are necessary,
  imagine that you implement a component and the component needs to load
  some state from the database. For example:

      <%= live_component @socket, UserComponent, id: user_id %>

  A possible implementation would be to load the user on the `c:update/2`
  callback:

      def update(assigns, socket) do
        user = Repo.get! User, assigns.id
        {:ok, assign(socket, :user, user)}
      end

  However, the issue with said approach is that, if you are rendering
  multiple user components in the same page, you have a N+1 query problem.
  The `c:preload/1` callback helps address this problem as it is invoked
  with a list of assigns for all components of the same type. For example,
  instead of implementing `c:update/2` as above, one could implement:

      def preload(list_of_assigns) do
        list_of_ids = Enum.map(list_of_assigns, & &1.id)

        users =
          from(u in User, where: u.id in ^list_of_ids, select: {u.id, u})
          |> Repo.all()
          |> Map.new()

        Enum.map(list_of_assigns, fn assigns ->
          Map.put(assigns, :user, users[assigns.id])
        end)
      end

  Now only a single query to the database will be made. In fact, the
  preloading algorithm is a breadth-first tree traversal, which means
  that even for nested components, the amount of queries are kept to
  a minimum.

  Finally, note that `c:preload/1` must return an updated `list_of_assigns`,
  keeping the assigns in the same order as they were given.

  ## Live component blocks

  When `live_component` is invoked, it is also possible to pass a `do/end`
  block:

      <%= live_component @socket, GridComponent, entries: @entries do %>
        New entry: <%= @entry %>
      <% end %>

  The `do/end` will be available as an anonymous function in an assign named
  `@inner_content`. The anonymous function must be invoked passing a new set
  of assigns that will be merged into the user assigns. For example, the grid
  component above could be implemented as:

      defmodule TableComponent do
        use Phoenix.LiveComponent

        def render(assigns) do
          ~L"\""
          <div class="grid">
            <%= for entry <- @entries do %>
              <div class="column">
                <%= @inner_content.(entry: entry) %>
              </div>
            <% end %>
          </div>
          "\""
        end
      end

  Where the `:entry` assign was injected into the `do/end` block.

  The approach above is the preferred one when passing blocks to `do/end`.
  However, if you are outside of a .leex template and you want to invoke a
  component passing `do/end` blocks, you will have to explicitly handle the
  assigns by giving it a clause:

      live_component @socket, GridComponent, entries: @entries do
        new_assigns -> "New entry: " <> new_assigns[:entry]
      end

  ## Communicating with the parent LiveView

  Since components run in the LiveView process, sending a message to the
  parent LiveView is simply a matter of sending a message to `self()`:

      send self(), :do_something

  The parent LiveView can then handle said message in its `handle_info/2`
  callback:

      def handle_info(:do_something, socket) do
        ...
      end

  ## Live links and live redirects

  A template rendered inside a component can use `live_link` calls. The
  `live_link` is always handled by the parent `LiveView`, as components
  do not provide `handle_params`. `live_redirect` from inside a component
  is not currently supported. For such, you must send a message to the
  LiveView itself, as mentioned above, which may then redirect.

  ## Limitations

  Components must only contain HTML tags at their root. At least one HTML
  tag must be present. It is not possible to have components that render
  only text or text mixed with tags at the root.

  Another limitation of components is that they must always be change
  tracked. For example, if you render a component inside `form_for`, like
  this:

      <%= form_for @changeset, "#", fn f -> %>
        <%= live_component @socket, SomeComponent, f: f %>
      <% end %>

  The component ends up enclosed by the form markup, where LiveView
  cannot track it. In such cases, you may receive an error such as:

      ** (ArgumentError) cannot convert component SomeComponent to HTML.
      A component must always be returned directly as part of a LiveView template

  In this particular case, this can be addressed by using the `form_for`
  variant without anonymous functions:

      <%= f = form_for @changeset, "#" %>
        <%= live_component @socket, SomeComponent, f: f %>
      </form>

  This issue can also happen with other helpers, such as `content_tag`:

      <%= content_tag :div do %>
        <%= live_component @socket, SomeComponent, f: f %>
      <% end %>

  In this case, the solution is to not use `content_tag` and rely on LiveEEx
  to build the markup.
  """
  defmacro __using__(_) do
    quote do
      import Phoenix.LiveView

      @doc false
      def __live__, do: %{kind: :component, module: __MODULE__}
    end
  end

  @callback mount(socket :: Socket.t()) ::
              {:ok, Socket.t()} | {:ok, Socket.t(), keyword()}

  @callback preload([Socket.assigns()]) :: [Socket.assigns()]

  @callback update(Socket.assigns(), socket :: Socket.t()) ::
              {:ok, Socket.t()}

  @callback render(assigns :: Socket.assigns()) :: Phoenix.LiveView.Rendered.t()

  @callback handle_event(event :: binary, Phoenix.LiveView.unsigned_params, socket :: Socket.t()) ::
              {:noreply, Socket.t()}

  @optional_callbacks mount: 1, update: 2, handle_event: 3
end
