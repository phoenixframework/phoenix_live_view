defmodule Phoenix.LiveComponent do
  @moduledoc ~S'''
  LiveComponents are a mechanism to compartmentalize state, markup, and
  events in LiveView.

  LiveComponents are defined by using `Phoenix.LiveComponent` and are used
  by calling `Phoenix.Component.live_component/1` in a parent LiveView.
  They run inside the LiveView process but have their own state and
  life-cycle. For this reason, they are also often called "stateful components".
  This is a contrast to `Phoenix.Component`, also known as "function components",
  which are stateless and can only compartmentalize markup.

  The smallest LiveComponent only needs to define a `c:render/1` function:

      defmodule HeroComponent do
        # In Phoenix apps, the line is typically: use MyAppWeb, :live_component
        use Phoenix.LiveComponent

        def render(assigns) do
          ~H"""
          <div class="hero"><%= @content %></div>
          """
        end
      end

  A LiveComponent is rendered as:

      <.live_component module={HeroComponent} id="hero" content={@content} />

  You must always pass the `module` and `id` attributes. The `id` will be
  available as an assign and it must be used to uniquely identify the
  component. All other attributes will be available as assigns inside the
  LiveComponent.

  > #### Functional components or live components? {: .neutral}
  >
  > Generally speaking, you should prefer functional components over live
  > components, as they are a simpler abstraction, with a smaller surface
  > area. The use case for live components only arises when there is a need
  > for encapsulating both event handling and additional state.

  ## Life-cycle

  ### Mount and update

  Live components are identified by the component module and their ID.
  We often tie the component ID to some application based ID:

      <.live_component module={UserComponent} id={@user.id} user={@user} />

  When [`live_component/1`](`Phoenix.Component.live_component/1`) is called,
  `c:mount/1` is called once, when the component is first added to the page.
  `c:mount/1` receives a `socket` as its argument. Note that this is *not* the
  same `socket` struct from the parent LiveView. It doesn't contain the parent
  LiveView's `assigns`, and updating it won't affect the parent LiveView's
  `socket`.

  Then `c:update/2` is invoked with all of the assigns passed to
  [`live_component/1`](`Phoenix.Component.live_component/1`). The assigns
  received as the first argument to `c:update/2` will only include those
  assigns given to [`live_component/1`](`Phoenix.Component.live_component/1`),
  and not any pre-existing assigns in `socket.assigns` such as those assigned
  by `c:mount/1`.

  If `c:update/2` is not defined then all assigns given to
  [`live_component/1`](`Phoenix.Component.live_component/1`) will simply be
  merged into `socket.assigns`.

  Both `c:mount/1` and `c:update/2` must return a tuple whose first element is
  `:ok` and whose second element is the updated `socket`.

  After the component is updated, `c:render/1` is called with all assigns.
  On first render, we get:

      mount(socket) -> update(assigns, socket) -> render(assigns)

  On further rendering:

      update(assigns, socket) -> render(assigns)

  Two live components with the same module and ID are treated as the same component,
  regardless of where they are in the page. Therefore, if you change the location
  of where a component is rendered within its parent LiveView, it won't be remounted.
  This means you can use live components to implement cards and other elements that
  can be moved around without losing state. A component is only discarded when the
  client observes it is removed from the page.

  Finally, the given `id` is not automatically used as the DOM ID. If you want to set
  a DOM ID, it is your responsibility to do so when rendering:

      defmodule UserComponent do
        # In Phoenix apps, the line is typically: use MyAppWeb, :live_component
        use Phoenix.LiveComponent

        def render(assigns) do
          ~H"""
          <div id={"user-#{@id}"} class="user">
            <%= @user.name %>
          </div>
          """
        end
      end

  ### Events

  LiveComponents can also implement the `c:handle_event/3` callback
  that works exactly the same as in LiveView. For a client event to
  reach a component, the tag must be annotated with a `phx-target`.
  If you want to send the event to yourself, you can simply use the
  `@myself` assign, which is an *internal unique reference* to the
  component instance:

      <a href="#" phx-click="say_hello" phx-target={@myself}>
        Say hello!
      </a>

  Note that `@myself` is not set for stateless components, as they cannot
  receive events.

  If you want to target another component, you can also pass an ID
  or a class selector to any element inside the targeted component.
  For example, if there is a `UserComponent` with the DOM ID of `"user-13"`,
  using a query selector, we can send an event to it with:

      <a href="#" phx-click="say_hello" phx-target="#user-13">
        Say hello!
      </a>

  In both cases, `c:handle_event/3` will be called with the
  "say_hello" event. When `c:handle_event/3` is called for a component,
  only the diff of the component is sent to the client, making them
  extremely efficient.

  Any valid query selector for `phx-target` is supported, provided that the
  matched nodes are children of a LiveView or LiveComponent, for example
  to send the `close` event to multiple components:

      <a href="#" phx-click="close" phx-target="#modal, #sidebar">
        Dismiss
      </a>

  ### Update many

  Live components also support an optional `c:update_many/1` callback
  as an alternative to `c:update/2`. While `c:update/2` is called for
  each component individually, `c:update_many/1` is called with all
  LiveComponents of the same module being currently rendered/updated.
  The advantage is that you can preload data from the database using
  a single query for all components, instead of running one query per
  component.

  To provide a more complete understanding of why both callbacks are necessary,
  let's see an example. Imagine you are implementing a component and the component
  needs to load some state from the database. For example:

      <.live_component module={UserComponent} id={user_id} />

  A possible implementation would be to load the user on the `c:update/2`
  callback:

      def update(assigns, socket) do
        user = Repo.get!(User, assigns.id)
        {:ok, assign(socket, :user, user)}
      end

  However, the issue with said approach is that, if you are rendering
  multiple user components in the same page, you have a N+1 query problem.
  By using `c:update_many/1` instead of `c:update/2` , we receive a list
  of all assigns and sockets, allowing us to update many at once:

      def update_many(assigns_sockets) do
        list_of_ids = Enum.map(assigns_sockets, fn {assigns, _sockets} -> assigns.id end)

        users =
          from(u in User, where: u.id in ^list_of_ids, select: {u.id, u})
          |> Repo.all()
          |> Map.new()

        Enum.map(assigns_sockets, fn {assigns, socket} ->
          assign(socket, :user, users[assigns.id])
        end)
      end

  Now only a single query to the database will be made. In fact, the
  `update_many/1` algorithm is a breadth-first tree traversal, which means
  that even for nested components, the amount of queries are kept to
  a minimum.

  Finally, note that `c:update_many/1` must return an updated list of
  sockets in the same order as they are given. If `c:update_many/1` is
  defined, `c:update/2` is not invoked.

  ### Summary

  All of the life-cycle events are summarized in the diagram below.
  The bubble events in white are triggers that invoke the component.
  In blue you have component callbacks, where the underlined names
  represent required callbacks:

  ```mermaid
  flowchart LR
      *((start)):::event-.->M
      WE([wait for<br>parent changes]):::event-.->M
      W([wait for<br>events]):::event-.->H

      subgraph j__transparent[" "]

        subgraph i[" "]
          direction TB
          M(mount/1<br><em>only once</em>):::callback
          M-->U
          M-->UM
        end

        U(update/2):::callback-->A
        UM(update_many/1):::callback-->A

        subgraph j[" "]
          direction TB
          A --> |yes| R
          H(handle_event/3):::callback-->A{any<br>changes?}:::diamond
        end

        A --> |no| W

      end

      R(render/1):::callback_req-->W

      classDef event fill:#fff,color:#000,stroke:#000
      classDef diamond fill:#FFC28C,color:#000,stroke:#000
      classDef callback fill:#B7ADFF,color:#000,stroke-width:0
      classDef callback_req fill:#B7ADFF,color:#000,stroke-width:0,text-decoration:underline
  ```

  ## Managing state

  Now that we have learned how to define and use components, as well as
  how to use `c:update_many/1` as a data loading optimization, it is important
  to talk about how to manage state in components.

  Generally speaking, you want to avoid both the parent LiveView and the
  LiveComponent working on two different copies of the state. Instead, you
  should assume only one of them to be the source of truth. Let's discuss
  the two different approaches in detail.

  Imagine a scenario where a LiveView represents a board with each card
  in it as a separate LiveComponent. Each card has a form to
  allow update of the card title directly in the component, as follows:

      defmodule CardComponent do
        use Phoenix.LiveComponent

        def render(assigns) do
          ~H"""
          <form phx-submit="..." phx-target={@myself}>
            <input name="title"><%= @card.title %></input>
            ...
          </form>
          """
        end

        ...
      end

  We will see how to organize the data flow to keep either the board LiveView or
  the card LiveComponents as the source of truth.

  ### LiveView as the source of truth

  If the board LiveView is the source of truth, it will be responsible
  for fetching all of the cards in a board. Then it will call
  [`live_component/1`](`Phoenix.Component.live_component/1`)
  for each card, passing the card struct as argument to `CardComponent`:

      <%= for card <- @cards do %>
        <.live_component module={CardComponent} card={card} id={card.id} board_id={@id} />
      <% end %>

  Now, when the user submits the form, `CardComponent.handle_event/3`
  will be triggered. However, if the update succeeds, you must not
  change the card struct inside the component. If you do so, the card
  struct in the component will get out of sync with the LiveView.  Since
  the LiveView is the source of truth, you should instead tell the
  LiveView that the card was updated.

  Luckily, because the component and the view run in the same process,
  sending a message from the LiveComponent to the parent LiveView is as
  simple as sending a message to `self()`:

      defmodule CardComponent do
        ...
        def handle_event("update_title", %{"title" => title}, socket) do
          send self(), {:updated_card, %{socket.assigns.card | title: title}}
          {:noreply, socket}
        end
      end

  The LiveView then receives this event using `c:Phoenix.LiveView.handle_info/2`:

      defmodule BoardView do
        ...
        def handle_info({:updated_card, card}, socket) do
          # update the list of cards in the socket
          {:noreply, updated_socket}
        end
      end

  Because the list of cards in the parent socket was updated, the parent
  LiveView will be re-rendered, sending the updated card to the component.
  So in the end, the component does get the updated card, but always
  driven from the parent.

  Alternatively, instead of having the component send a message directly to the
  parent view, the component could broadcast the update using `Phoenix.PubSub`.
  Such as:

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

  As long as the parent LiveView subscribes to the `board:<ID>` topic,
  it will receive updates. The advantage of using PubSub is that we get
  distributed updates out of the box. Now, if any user connected to the
  board changes a card, all other users will see the change.

  ### LiveComponent as the source of truth

  If each card LiveComponent is the source of truth, then the board LiveView
  must no longer fetch the card structs from the database. Instead, the board
  LiveView must only fetch the card ids, then render each component only by
  passing an ID:

      <%= for card_id <- @card_ids do %>
        <.live_component module={CardComponent} id={card_id} board_id={@id} />
      <% end %>

  Now, each CardComponent will load its own card. Of course, doing so
  per card could be expensive and lead to N queries, where N is the
  number of cards, so we can use the `c:update_many/1` callback to make it
  efficient.

  Once the card components are started, they can each manage their own
  card, without concerning themselves with the parent LiveView.

  However, note that components do not have a `c:Phoenix.LiveView.handle_info/2`
  callback. Therefore, if you want to track distributed changes on a card,
  you must have the parent LiveView receive those events and redirect them
  to the appropriate card. For example, assuming card updates are sent
  to the "board:ID" topic, and that the board LiveView is subscribed to
  said topic, one could do:

      def handle_info({:updated_card, card}, socket) do
        send_update CardComponent, id: card.id, board_id: socket.assigns.id
        {:noreply, socket}
      end

  With `Phoenix.LiveView.send_update/3`, the `CardComponent` given by `id`
  will be invoked, triggering the update or update_many callback, which will
  load the most up to date data from the database.

  ### Unifying LiveView and LiveComponent communication

  In the examples above, we have used `send/2` to communicate with LiveView
  and `send_update/2` to communicate with components. This introduces a problem:
  what if you have a component that may be mounted both inside a LiveView
  or another component? Given each uses a different API for exchanging data,
  this may seem tricky at first, but an elegant solution is to use anonymous
  functions as callbacks. Let's see an example.

  In the sections above, we wrote the following code in our `CardComponent`:

  ```elixir
  def handle_event("update_title", %{"title" => title}, socket) do
    send self(), {:updated_card, %{socket.assigns.card | title: title}}
    {:noreply, socket}
  end
  ```

  The issue with this code is that, if CardComponent is mounted inside another
  component, it will still message the LiveView. Not only that, this code may
  be hard to maintain because the message sent by the component is defined far
  away from the LiveView that will receive it.

  Instead let's define a callback that will be invoked by CardComponent:

  ```elixir
  def handle_event("update_title", %{"title" => title}, socket) do
    socket.assigns.on_card_update.(%{socket.assigns.card | title: title})
    {:noreply, socket}
  end
  ```

  And now when initializing the CardComponent from a LiveView, we may write:

  ```heex
  <.live_component
    module={CardComponent}
    card={card}
    id={card.id}
    board_id={@id}
    on_card_update={fn card -> send(self(), {:updated_card, card}) end} />
  ```

  If initializing it inside another component, one may write:

  ```heex
  <.live_component
    module={CardComponent}
    card={card}
    id={card.id}
    board_id={@id}
    on_card_update={fn card -> send_update(@myself, card: card) end} />
  ```

  The major benefit in both cases is that the parent has explicit control
  over the messages it will receive.

  ## Slots

  LiveComponent can also receive slots, in the same way as a `Phoenix.Component`:

      <.live_component module={MyComponent} id={@data.id} >
        <div>Inner content here</div>
      </.live_component>

  If the LiveComponent defines an `c:update/2`, be sure that the socket it returns
  includes the `:inner_block` assign it received.

  See [the docs](Phoenix.Component.html#module-slots.md) for `Phoenix.Component` for more information.

  ## Live patches and live redirects

  A template rendered inside a component can use `<.link patch={...}>` and
  `<.link navigate={...}>`. Patches are always handled by the parent LiveView,
  as components do not provide `handle_params`.

  ## Cost of live components

  The internal infrastructure LiveView uses to keep track of live
  components is very lightweight. However, be aware that in order to
  provide change tracking and to send diffs over the wire, all of the
  components' assigns are kept in memory - exactly as it is done in
  LiveViews themselves.

  Therefore it is your responsibility to keep only the assigns necessary
  in each component. For example, avoid passing all of LiveView's assigns
  when rendering a component:

      <.live_component module={MyComponent} {assigns} />

  Instead pass only the keys that you need:

      <.live_component module={MyComponent} user={@user} org={@org} />

  Luckily, because LiveViews and LiveComponents are in the same process,
  they share the data structure representations in memory. For example,
  in the code above, the view and the component will share the same copies
  of the `@user` and `@org` assigns.

  You should also avoid using live components to provide abstract DOM
  components. As a guideline, a good LiveComponent encapsulates
  application concerns and not DOM functionality. For example, if you
  have a page that shows products for sale, you can encapsulate the
  rendering of each of those products in a component. This component
  may have many buttons and events within it. On the opposite side,
  do not write a component that is simply encapsulating generic DOM
  components. For instance, do not do this:

      defmodule MyButton do
        use Phoenix.LiveComponent

        def render(assigns) do
          ~H"""
          <button class="css-framework-class" phx-click="click">
            <%= @text %>
          </button>
          """
        end

        def handle_event("click", _, socket) do
          _ = socket.assigns.on_click.()
          {:noreply, socket}
        end
      end

  Instead, it is much simpler to create a function component:

      def my_button(%{text: _, click: _} = assigns) do
        ~H"""
        <button class="css-framework-class" phx-click={@click}>
          <%= @text %>
        </button>
        """
      end

  If you keep components mostly as an application concern with
  only the necessary assigns, it is unlikely you will run into
  issues related to live components.

  ## Limitations

  Live Components require a single HTML tag at the root. It is not possible
  to have components that render only text or multiple tags.
  '''

  defmodule CID do
    @moduledoc """
    The struct representing an internal unique reference to the component instance,
    available as the `@myself` assign in live components.

    Read more about the uses of `@myself` in the `Phoenix.LiveComponent` docs.
    """

    defstruct [:cid]

    defimpl Phoenix.HTML.Safe do
      def to_iodata(%{cid: cid}), do: Integer.to_string(cid)
    end

    defimpl String.Chars do
      def to_string(%{cid: cid}), do: Integer.to_string(cid)
    end
  end

  alias Phoenix.LiveView.Socket

  @doc """
  Uses LiveComponent in the current module.

      use Phoenix.LiveComponent

  ## Options

    * `:global_prefixes` - the global prefixes to use for components. See
      `Global Attributes` in `Phoenix.Component` for more information.
  """
  defmacro __using__(opts \\ []) do
    quote do
      import Phoenix.LiveView
      @behaviour Phoenix.LiveComponent
      @before_compile Phoenix.LiveView.Renderer

      # Phoenix.Component must come last so its @before_compile runs last
      use Phoenix.Component, Keyword.take(unquote(opts), [:global_prefixes])

      @doc false
      def __live__, do: %{kind: :component, layout: false}
    end
  end

  @callback mount(socket :: Socket.t()) ::
              {:ok, Socket.t()} | {:ok, Socket.t(), keyword()}

  @callback update(assigns :: Socket.assigns(), socket :: Socket.t()) :: {:ok, Socket.t()}

  @callback update_many([{Socket.assigns(), Socket.t()}]) :: [Socket.t()]

  @callback render(assigns :: Socket.assigns()) :: Phoenix.LiveView.Rendered.t()

  @callback handle_event(
              event :: binary,
              unsigned_params :: Phoenix.LiveView.unsigned_params(),
              socket :: Socket.t()
            ) ::
              {:noreply, Socket.t()} | {:reply, map, Socket.t()}

  @callback handle_async(
              name :: term,
              async_fun_result :: {:ok, term} | {:exit, term},
              socket :: Socket.t()
            ) ::
              {:noreply, Socket.t()}

  @optional_callbacks mount: 1,
                      update_many: 1,
                      update: 2,
                      render: 1,
                      handle_event: 3,
                      handle_async: 3
end
