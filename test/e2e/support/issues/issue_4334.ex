defmodule Phoenix.LiveViewTest.E2E.Issue4334Live do
  # https://github.com/phoenixframework/phoenix_live_view/issues/4334
  use Phoenix.LiveView

  defmodule RootChangingComponent do
    use Phoenix.LiveComponent

    @impl true
    def mount(socket), do: {:ok, assign(socket, changed: false)}

    @impl true
    def handle_event("change-root-id", _params, socket) do
      {:noreply, assign(socket, changed: true)}
    end

    @impl true
    def render(assigns) do
      ~H"""
      <section
        id={if @changed, do: "new-root", else: "old-root"}
        data-testid="component-root"
        phx-hook="RootChange"
        style="min-height: 10rem; margin-top: 2rem; padding: 1.5rem; border: 4px solid #dc2626;"
      >
        <button
          id="change-root"
          phx-click="change-root-id"
          phx-target={@myself}
          style="padding: 0.75rem 1rem; background: #111827; color: white;"
        >
          Change component root ID
        </button>

        <p id={if @changed, do: "new-child", else: "old-child"} style="font-size: 1.25rem;">
          {if @changed, do: "NEW CHILD SHOULD REMAIN VISIBLE", else: "Old child is visible"}
        </p>
      </section>
      """
    end
  end

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    assigns = %{}

    pre_script =
      ~H"""
      <script>
        window.hooks.RootChange = {
          mounted() {
            console.log("MyHook mounted");
          },
          updated() {
            console.log("MyHook updated");
          },
        };
      </script>
      """

    {:ok, assign(socket, count: 0, pre_script: pre_script)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <main style="max-width: 48rem; margin: 4rem auto; font-family: system-ui;">
      <h1>LiveComponent root ID corruption repro</h1>
      <p id="instructions">
        Click the button. The component root changes from <code>old-root</code>
        to <code>new-root</code>. On affected LiveView versions, the replacement root remains
        but all of its new children disappear.
      </p>

      <.live_component module={RootChangingComponent} id="demo-component" />
    </main>
    """
  end
end
