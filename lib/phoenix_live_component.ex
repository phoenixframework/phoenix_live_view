defmodule Phoenix.LiveComponent do
  @moduledoc """
  Components are a mechanism to compartmentalize state, markup, and
  events in LiveView.

  Components are defined by using `Phoenix.LiveComponent` and are used
  by calling `Phoenix.LiveView.Helpers.live_component/3` in a parent LiveView.
  Components run inside the LiveView process, but may have their own
  state and event handling.

  The simplest component only needs to define a `render` function:

      defmodule HeroComponent do
        use Phoenix.LiveComponent

        def render(assigns) do
          ~L\"""
          <div class="hero"><%= @content %></div>
          \"""
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
  assigns given to `live_component/3`. The default implementation of
  `c:update/2` simply merges all assigns into the socket. Then, after the
  component is updated, `c:render/1` is called with all assigns.

  A stateless component is always mounted, updated, and rendered whenever
  the parent template changes. That's why they are stateless: no state
  is kept after the component.

  However, any component can be made stateful by passing an `:id` assign.

  ## Stateful components life-cycle

  A stateful component is a component that receives an `:id` on `live_component/3`:

      <%= live_component @socket, HeroComponent, id: :hero, content: @content %>

  Stateful components are identified by the component module and their ID.
  Therefore, two different component modules with the same ID are different
  components. This means we can often tie the component ID to some application
  based ID:

      <%= live_component @socket, UserComponent, id: @user.id, user: @user %>

  Also note the given `:id` is not necessarily used as the DOM ID. If you
  want to set a DOM ID, it is your responsibility to set it when rendering:

      defmodule UserComponent do
        use Phoenix.LiveComponent

        def render(assigns) do
          ~L\"""
          <div id="user-<%= @id %>" class="user"><%= @user.name %></div>
          \"""
        end
      end

  In stateful components, `c:mount/1` is called only once, when the
  component is first rendered. Then for each rendering, the optional
  `c:preload/1` and `c:update/2` callbacks are called before `c:render/1`.

  ## Targeting Component Events

  Stateful components can also implement the `c:handle_event/3` callback
  that works exactly the same as in LiveView. For a client event to
  reach a component, the tag must be annotated with a `phx-target`
  annotation which must be a query selector to an element inside the
  component. For example, if the `UserComponent` above is started with
  the `:id` of `13`, it will have the DOM ID of `user-13`. Using a query
  selector, we can sent an event to it with:

      <a href="#" phx-click="say_hello" phx-target="#user-13">
        Say hello!
      </a>

  Then `c:handle_event/3` will be called by with the "say_hello" event.
  When `c:handle_event/3` is called for a component, only the diff of
  the component is sent to the client, making them extremely efficient.

  Any valid query selector for `phx-target` is supported, provided the
  matched nodes are children of a LiveView or LiveComponent, for example
  to send the `close` event to multiple components:

      <a href="#" phx-click="close" phx-target="#modal, #sidebar">
        Dismiss
      </a>

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

  ## Managing state

  Now that we have learned how to define and use components, as well as
  how to use `c:preload/1` as a data loading optimization, it is important
  to talk about how to manage state in components.

  Generally speaking, you want to avoid both the parent LiveView and the
  LiveComponent working on two different copies of the state. Instead, you
  should assume only one of them to be the source of truth. Let's discuss
  these approaches in detail.

  Imagine that the scenario we will explore is that we have a LiveView
  representing a board, where each card in the board is a separate component.
  Each card has a form that allows to update the form title directly in the
  component. We will see how to organize the data flow keeping either the
  view or the component as the source of truth.

  ### LiveView as the source of truth

  If the LiveView is the source of truth, the LiveView will be responsible
  for fetching all of the cards in a board. Then it will call `live_component/3`
  for each card, passing the card struct as argument to CardComponent:

      <%= for card <- @cards do %>
        <%= live_component @socket, CardComponent, card: card, board_id: @id %>
      <% end %>

  Now, when the user submits a form inside the CardComponent to update the
  card, `CardComponent.handle_event/3` will be triggered. However, if the
  update succeeds, you must not change the card struct inside the component.
  If you do so, the card struct in the component will get out of sync with
  the LiveView. Since the LiveView is the source of truth, we should instead
  tell the LiveView the card was updated.

  Luckily, because the component and the view run in the same process,
  sending a message from the component to the parent LiveView is as simple
  as sending a message to self:

      defmodule CardComponent do
        ...
        def handle_event("update_title", %{"title" => title}, socket) do
          send self(), {:updated_card, %{socket.assigns.card | title: title}}
          {:noreply, socket}
        end
      end

  The LiveView can receive this event using `handle_info`:

      defmodule BoardView do
        ...
        def handle_info({:updated_card, card}, socket) do
          # update the list of cards in the socket
          {:noreply, updated_socket}
        end
      end

  As the list of cards in the parent socket was updated, the parent
  will be re-rendered, sending the updated card to the component.
  So in the end, the component does get the updated card, but always
  driven from the parent.

  Alternatively, instead of having the component directly send a
  message to the parent, the component could broadcast the update
  using `Phoenix.PubSub`. Such as:

      defmodule CardComponent do
        ...
        def handle_event("update_title", %{"title" => title}, socket) do
          message = {:updated_card, %{socket.assigns.card | title: title}}
          Phoenix.PubSub.broadcast(MyApp.PubSub, board_topic(socket), message)
          {:noreply, socket}
        end

        defp board_topic(socket) do
          "board:" <> socket.assigns.board_id
        end
      end

  As long as the parent LiveView subscribes to the "board:ID" topic,
  it will receive updates. The advantage of using PubSub is that we get
  distributed updates out of the box. Now if any user connected to the
  board changes a card, all other users will see the change.

  ### LiveComponent as the source of truth

  If the component is the source of truth, then the LiveView must no
  longer fetch all of the cards structs from the database. Instead,
  the view must only fetch all of the card ids and render the component
  only by passing the IDs:

      <%= for card_id <- @card_ids do %>
        <%= live_component @socket, CardComponent, card_id: card_id, board_id: @id %>
      <% end %>

  Now, each CardComponent loads their own card. Of course, doing so per
  card would be expensive and lead to N queries, where N is the number
  of components, so we must use the `c:preload/1` callback to make it
  efficient.

  Once all card components are started, they can fully manage each
  card as a whole, without concerning themselves with the parent LiveView.

  However, note that components do not have a `handle_info/2` callback.
  Therefore, if you want to track distributed changes on a card, you
  must have the parent LiveView receive those events and redirect them
  to the appropriate card. For example, assuming card updates are sent
  to the "board:ID" topic, and that the board LiveView is subscribed to
  said topic, one could do:

      def handle_info({:updated_card, card}, socket) do
        send_update CardComponent, id: card.id, board_id: socket.assigns.id
        {:noreply, socket}
      end

  With `send_update`, the CardComponent given by `id` will be invoked,
  triggering both preload and update callbacks, which will load the
  most up to date data from the database.

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

      defmodule GridComponent do
        use Phoenix.LiveComponent

        def render(assigns) do
          ~L\"""
          <div class="grid">
            <%= for entry <- @entries do %>
              <div class="column">
                <%= @inner_content.(entry: entry) %>
              </div>
            <% end %>
          </div>
          \"""
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

  alias Phoenix.LiveView.Socket

  defmacro __using__(_) do
    quote do
      import Phoenix.LiveView
      import Phoenix.LiveView.Helpers
      @behaviour Phoenix.LiveComponent
      @before_compile Phoenix.LiveView.Renderer

      @doc false
      def __live__, do: %{kind: :component, module: __MODULE__}
    end
  end

  @callback mount(socket :: Socket.t()) ::
              {:ok, Socket.t()} | {:ok, Socket.t(), keyword()}

  @callback preload(list_of_assigns :: [Socket.assigns()]) ::
              list_of_assigns :: [Socket.assigns()]

  @callback update(assigns :: Socket.assigns(), socket :: Socket.t()) ::
              {:ok, Socket.t()}

  @callback render(assigns :: Socket.assigns()) :: Phoenix.LiveView.Rendered.t()

  @callback handle_event(
              event :: binary,
              unsigned_params :: Socket.unsigned_params(),
              socket :: Socket.t()
            ) ::
              {:noreply, Socket.t()}

  @optional_callbacks mount: 1, preload: 1, update: 2, handle_event: 3
end
