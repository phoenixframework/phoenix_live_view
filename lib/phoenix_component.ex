defmodule Phoenix.Component do
  @moduledoc ~S'''
  API for function components.

  A function component is any function that receives
  an assigns map as argument and returns a rendered
  struct built with [the `~H` sigil](`Phoenix.LiveView.Helpers.sigil_H/2`).

  Here is an example:

      defmodule MyComponent do
        use Phoenix.Component

        # Optionally also bring the HTML helpers
        # use Phoenix.HTML

        def greet(assigns) do
          ~H"""
          <p>Hello, <%= assigns.name %></p>
          """
        end
      end

  The component can be invoked as a regular function:

      MyComponent.greet(%{name: "Jane"})

  But it is typically invoked using the function component
  syntax from the `~H` sigil:

      ~H"""
      <MyComponent.greet name="Jane" />
      """

  If the `MyComponent` module is imported or if the function
  is defined locally, you can skip the module name:

      ~H"""
      <.greet name="Jane" />
      """

  Similar to any HTML tag inside the `~H` sigil, you can
  interpolate attributes values too:

      ~H"""
      <.greet name={@user.name} />
      """

  You can learn more about the `~H` sigil [in its documentation](`Phoenix.LiveView.Helpers.sigil_H/2`).

  ## `use Phoenix.Component`

  Modules that define function components should call
  `use Phoenix.Component` at the top. Doing so will import
  the functions from both `Phoenix.LiveView` and
  `Phoenix.LiveView.Helpers` modules. `Phoenix.LiveView`
  and `Phoenix.LiveComponent` automatically invoke
  `use Phoenix.Component` for you.

  You must avoid defining a module for each component. Instead,
  we should use modules to group side-by-side related function
  components.

  ## Assigns

  While inside a function component, you must use `Phoenix.LiveView.assign/3`
  and `Phoenix.LiveView.assign_new/3` to manipulate assigns,
  so that LiveView can track changes to the assigns values.
  For example, let's imagine a component that receives the first
  name and last name and must compute the name assign. One option
  would be:

      def show_name(assigns) do
        assigns = assign(assigns, :name, assigns.first_name <> assigns.last_name)

        ~H"""
        <p>Your name is: <%= @name %></p>
        """
      end

  However, when possible, it may be cleaner to break the logic over function
  calls instead of precomputed assigns:

      def show_name(assigns) do
        ~H"""
        <p>Your name is: <%= full_name(@first_name, @last_name) %></p>
        """
      end

      defp full_name(first_name, last_name), do: first_name <> last_name

  Another example is making an assign optional by providing
  a default value:

      def field_label(assigns) do
        assigns = assign_new(assigns, :help, fn -> nil end)

        ~H"""
        <label>
          <%= @text %>

          <%= if @help do %>
            <span class="help"><%= @help %></span>
          <% end %>
        </label>
        """
      end

  ## Slots

  Slots is a mechanism to give HTML blocks to function components
  as in regular HTML tags.

  ### Default slots

  Any content you pass inside a component is assigned to a default slot
  called `@inner_block`. For example, imagine you want to create a button
  component like this:

      <.button>
        This renders <strong>inside</strong> the button!
      </.button>

  It is quite simple to do so. Simply define your component and call
  `render_slot(@inner_block)` where you want to inject the content:

      def button(assigns) do
        ~H"""
        <button class="btn">
          <%= render_slot(@inner_block) %>
        </button>
        """
      end

  In a nutshell, the contents given to the component is assigned to
  the `@inner_block` assign and then we use `Phoenix.LiveView.Helpers.render_slot/2`
  to render it.

  You can even have the component give a value back to the caller,
  by using `let`. Imagine this component:

      def unordered_list(assigns) do
        ~H"""
        <ul>
          <%= for entry <- @entries do %>
            <li><%= render_slot(@inner_block, entry) %></li>
          <% end %>
        </ul>
        """
      end

  And now you can invoke it as:

      <.unordered_list let={entry} entries={~w(apple banana cherry)}>
        I like <%= entry %>
      </.unordered_list>

  You can also pattern match the arguments provided to the render block. Let's
  make our `unordered_list` component fancier:

      def unordered_list(assigns) do
        ~H"""
        <ul>
          <%= for entry <- @entries do %>
            <li><%= render_slot(@inner_block, %{entry: entry, gif_url: random_gif()} %></li>
          <% end %>
        </ul>
        """
      end

  And now we can invoke it like this:

      <.unordered_list let={%{entry: entry, gif_url: url}}>
        I like <%= entry %>. <img src={url} />
      </.unordered_list>

  ### Named slots

  Besides `@inner_block`, it is also possible to pass named slots
  to the component. For example, imagine that you want to create
  a modal component. The modal component has a header, a footer,
  and the body of the modal, which we would use like this:

      <.modal>
        <:header>
          This is the top of the modal.
        </:header>

        This is the body - everything not in a
        named slot goes to @inner_block.

        <:footer>
          <button>Save</button>
        </:footer>
      </.modal>

  The component itself could be implemented like this:

      def modal(assigns) do
        ~H"""
        <div class="modal">
          <div class="modal-header">
            <%= render_slot(@header) %>
          </div>

          <div class="modal-body">
            <%= render_slot(@inner_block) %>
          </div>

          <div class="modal-footer">
            <%= render_slot(@footer) %>
          </div>
        </div>
        """
      end

  If you want to make the `@header` and `@footer` optional,
  you can assign them a default of an empty list at the top:

      def modal(assigns) do
        assigns =
          assigns
          |> assign_new(:header, fn -> [] end)
          |> assign_new(:footer, fn -> [] end)

        ~H"""
        <div class="modal">
          ...
      end

  ### Named slots with attributes

  It is also possible to pass the same named slot multiple
  times and also give attributes to each of them.

  If multiple slot entries are defined for the same slot,
  `render_slot/2` will automatically render all entries,
  merging their contents. But sometimes we want more fine
  grained control over each individual slot, including access
  to their attributes. Let's see an example. Imagine we want
  to implement a table component

  For example, imagine a table component:

      <.table rows={@users}>
        <:col let={user} label="Name">
          <%= user.name %>
        </:col>

        <:col let={user} label="Address">
          <%= user.address %>
        </:col>
      </.table>

  At the top level, we pass the rows as an assign and we define
  a `:col` slot for each column we want in the table. Each
  column also has a `label`, which we are going to use in the
  table header.

  Inside the component, you can render the table with headers,
  rows, and columns:

      def table(assigns) do
        ~H"""
        <table>
          <th>
            <%= for col <- @col do %>
              <td><%= col.label %></td>
            <% end %>
          </th>
          <%= for row <- @rows do %>
            <tr>
              <%= for col <- @col do %>
                <td><%= render_slot(col, row) %></td>
              <% end %>
            </tr>
          <% end %>
        </table>
        """
      end

  Each named slot (including the `@inner_block`) is a list of maps,
  where the map contains all slot attributes, allowing us to access
  the label as `col.label`. This gives us complete control over how
  we render them.
  '''

  @doc false
  defmacro __using__(_) do
    quote do
      import Phoenix.LiveView
      import Phoenix.LiveView.Helpers
    end
  end
end
