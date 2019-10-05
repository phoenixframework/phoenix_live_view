defmodule Phoenix.LiveComponent do
  @moduledoc ~S"""
  Components are a mechanism to compartimentalize state, markup, and
  events in LiveView.

  Components are defined by using `Phoenix.LiveComponent` and are used
  by calling `Phoenix.LiveView.live_component/2` in a parent LiveView.
  Components run inside the LiveView process, but may have their own
  state and event handling.

  The simplest component simply defines a `render` function:

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

      <%= live_component HeroComponent, content: @content %>

  Components come in two shapes, stateless or stateful. The component
  above is a stateless component. Of course, the component above is not
  any different compared to a regular function. However, as we will see,
  components do provide their own exclusive feature set.

  ## Stateless components life-cycle

  When `live_component` is called, the following callbacks will invoked
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

      <%= live_component HeroComponent, id: :hero, content: @content %>

  Stateful components are identified by the component module and their ID.
  Therefore, two different component module with the same ID are different
  components. This means we can often tie the component ID to some application
  based ID:

      <%= live_component UserComponent, id: @user.id, user: @user %>

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
  component is first rendered. Then `c:update/2` is called immediately
  after `c:mount/1` as well as before each re-rendering.

  Stateful components can also implement a `handle_event/3` callback,
  that works exactly the same as in LiveView. When `handle_event/3` is
  called for a component, only the diff of the component is sent to the
  client, making them extremely efficient.

  ## Limitations

  Components must only contain HTML tags at their root. At least one HTML
  tag must be present. It is not possible to have components that render
  only text or text mixed with tags at the root.
  """
  defmacro __using__(_) do
    quote do
      import Phoenix.LiveView

      @doc false
      def __live__, do: %{kind: :component}
    end
  end

  @callback mount(socket :: Socket.t()) ::
              {:ok, Socket.t()} | {:ok, Socket.t(), keyword()}

  @callback update(Socket.assigns(), socket :: Socket.t()) ::
              {:ok, Socket.t()} | {:ok, Socket.t(), keyword()}

  @callback render(assigns :: Socket.assigns()) :: Phoenix.LiveView.Rendered.t()

  @callback handle_event(event :: binary, Phoenix.LiveView.unsigned_params, socket :: Socket.t()) ::
              {:noreply, Socket.t()}

  @optional_callbacks mount: 1, update: 2, handle_event: 3
end
