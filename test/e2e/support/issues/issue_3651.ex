defmodule Phoenix.LiveViewTest.E2E.Issue3651Live do
  # https://github.com/phoenixframework/phoenix_live_view/issues/3651
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    if connected?(socket) do
      send(self(), :change_id)
    end

    # assigns for pre_script
    assigns = %{}

    socket =
      socket
      |> assign(id: 1, counter: 0)
      |> assign(
        :pre_script,
        ~H"""
        <script>
          window.hooks.OuterHook = {
            mounted() {
              this.pushEvent("lol");
            },
          };
          window.hooks.InnerHook = {
            mounted() {
              console.log("MOUNTED", this.el);
              this.handleEvent("myevent", this._handleEvent(this));
            },
            destroyed() {
              document.getElementById("notice").innerHTML = "";
              console.log("DESTROYED", this.el);
            },
            _handleEvent(self) {
              return () => {
                setTimeout(() => {
                  console.warn("reloading", self.el);
                  self.pushEvent("reload", {});
                }, 50);
              };
            },
          };
        </script>
        """
      )
      |> push_event("myevent", %{})

    {:ok, socket}
  end

  def handle_info(:change_id, socket) do
    {:noreply, assign(socket, id: 2)}
  end

  def handle_event("lol", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("reload", _params, socket) do
    counter = socket.assigns.counter + 1

    socket =
      socket
      |> push_event("myevent", %{})
      |> assign(counter: counter)

    socket =
      if counter > 4096 do
        raise "that's enough, bye!"
      else
        socket
      end

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div id="main" phx-hook="OuterHook">
      <div phx-hook="InnerHook" id={"id-#{@id}"} />
      This is an example of nested hooks resulting in a "ghost" element
      that isn't on the DOM, and is never cleaned up. In this specific example
      a timeout is used to show how the number of events being sent to the server
      grows exponentially.
      <p>Doing any of the following things fixes it:</p>
      <ol>
        <li>Setting the `phx-hook` to use a fixed id.</li>
        <li>Removing the `pushEvent` from the OuterHook `mounted` callback.</li>
        <li>Deferring the pushEvent by wrapping it in a setTimeout.</li>
      </ol>
    </div>
    <div>
      To prevent blowing up your computer, the page will reload after 4096 events, which takes ~12 seconds
    </div>
    <div style="color: blue; font-size: 20px" id="counter">
      Total Event Calls: <span id="total">{@counter}</span>
    </div>
    <div style="color: red; font-size: 72px" id="notice" phx-update="ignore">
      I will disappear if the bug is not present.
    </div>
    """
  end
end
