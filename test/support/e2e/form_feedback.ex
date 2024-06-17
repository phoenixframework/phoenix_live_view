defmodule Phoenix.LiveViewTest.E2E.FormFeedbackLive do
  use Phoenix.LiveView, layout: {__MODULE__, :live}

  def render("live.html", assigns) do
    ~H"""
    <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
    <script src="/assets/phoenix/phoenix.min.js">
    </script>
    <script type="module">
      import {LiveSocket} from "/assets/phoenix_live_view/phoenix_live_view.esm.js"
      let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
      let liveSocket = new LiveSocket("/live", window.Phoenix.Socket, {
        params: {_csrf_token: csrfToken}
      })
      liveSocket.connect()
      window.liveSocket = liveSocket
    </script>

    <%= @inner_content %>
    """
  end

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, assign(socket, count: 0, submit_count: 0, validate_count: 0, feedback: true)}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", _params, socket) do
    {:noreply, assign(socket, :validate_count, socket.assigns.validate_count + 1)}
  end

  def handle_event("submit", _params, socket) do
    {:noreply, assign(socket, :submit_count, socket.assigns.submit_count + 1)}
  end

  def handle_event("inc", _params, socket) do
    {:noreply, assign(socket, :count, socket.assigns.count + 1)}
  end

  def handle_event("dec", _params, socket) do
    {:noreply, assign(socket, :count, socket.assigns.count - 1)}
  end

  def handle_event("toggle-feedback", _, socket) do
    {:noreply, assign(socket, :feedback, !socket.assigns.feedback)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <style>
      .phx-no-feedback {
        display: none;
      }
    </style>
    <p>Button Count: <%= @count %></p>
    <p>Validate Count: <%= @validate_count %></p>
    <p>Submit Count: <%= @submit_count %></p>
    <button phx-click="inc" class="bg-blue-500 text-white p-4">+</button>
    <button phx-click="dec" class="bg-blue-500 text-white p-4">-</button>

    <.myform />

    <% # render inside function component to trigger the phx-magic-id optimization %>
    <.myfeedback feedback={@feedback} />

    <button phx-click="toggle-feedback">Toggle feedback</button>
    """
  end

  defp myform(assigns) do
    ~H"""
    <form id="myform" name="test" phx-change="validate" phx-submit="submit">
      <input type="text" name="name" class="border border-gray-500" placeholder="type sth" />

      <.other_input />

      <button type="submit">Submit</button>
      <button type="reset">Reset</button>
    </form>
    """
  end

  defp myfeedback(assigns) do
    ~H"""
    <div phx-feedback-for={@feedback && "myfeedback"} data-feedback-container>
      I am visible, because phx-no-feedback is not set for myfeedback!
    </div>
    """
  end

  defp other_input(assigns) do
    ~H"""
    <input type="text" name="myfeedback" class="border border-gray-500" placeholder="myfeedback" />
    """
  end
end
