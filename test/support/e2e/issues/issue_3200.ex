defmodule Phoenix.LiveViewTest.E2E.Issue3200 do
  # https://github.com/phoenixframework/phoenix_live_view/issues/3200

  defmodule PanelLive do
    use Phoenix.LiveView

    alias Phoenix.LiveView.JS

    def render(assigns) do
      ~H"""
      <div>
        <div>
          <div>
            <.tab_button text="Messages tab" route="/issues/3200/messages" />
            <.tab_button text="Settings tab" route="/issues/3200/settings" />
          </div>

          <aside>
            <div>
              <div :if={@live_action == :messages_tab}>
                <.live_component
                  module={Phoenix.LiveViewTest.E2E.Issue3200.MessagesTab}
                  id="messages_tab"
                />
              </div>
              <div :if={@live_action == :settings_tab}>
                <.live_component
                  module={Phoenix.LiveViewTest.E2E.Issue3200.SettingsTab}
                  id="settings_tab"
                />
              </div>
            </div>
          </aside>
        </div>
      </div>
      """
    end

    def handle_params(_params, _uri, socket), do: {:noreply, socket}

    defp tab_button(assigns) do
      ~H"""
      <button type="button" phx-click={JS.patch(@route)}>
        <%= @text %>
      </button>
      """
    end
  end

  defmodule SettingsTab do
    use Phoenix.LiveComponent

    @impl Phoenix.LiveComponent
    def render(assigns) do
      ~H"""
      <div>Settings</div>
      """
    end
  end

  defmodule MessagesTab do
    use Phoenix.LiveComponent

    def update(assigns, socket) do
      {
        :ok,
        assign(socket, id: assigns.id, value: "")
      }
    end

    def render(assigns) do
      ~H"""
      <div>
        <.live_component
          module={Phoenix.LiveViewTest.E2E.Issue3200.MessageComponent}
          id="some_unique_message_id"
          message="Example message"
        />
        <form
          id="full_add_message_form"
          phx-change="add_message_change"
          phx-submit="add_message"
          phx-target="#full_add_message_form"
        >
          <.input id="new_message_input" name="new_message" value={@value} />
        </form>
      </div>
      """
    end

    def input(assigns) do
      ~H"""
      <div phx-feedback-for={@name}>
        <input name={@name} id={@id} value={@value} />
      </div>
      """
    end

    def handle_event("add_message_change", %{"new_message" => value}, socket) do
      {:noreply, assign(socket, :value, value)}
    end
  end

  defmodule MessageComponent do
    use Phoenix.LiveComponent

    def render(assigns) do
      ~H"""
      <div><%= @message %></div>
      """
    end
  end
end
