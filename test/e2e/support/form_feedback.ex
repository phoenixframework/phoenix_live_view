defmodule Phoenix.LiveViewTest.E2E.FormFeedbackLive do
  use Phoenix.LiveView, layout: {__MODULE__, :live}

  def render("live.html", assigns) do
    ~H"""
    <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
    <script src="/assets/phoenix/phoenix.min.js">
    </script>
    <script type="module">
      import {
        LiveSocket,
        isUsedInput,
      } from "/assets/phoenix_live_view/phoenix_live_view.esm.js";
      let resetFeedbacks = (container, feedbacks) => {
        feedbacks =
          feedbacks ||
          Array.from(container.querySelectorAll("[phx-feedback-for]")).map((el) => [
            el,
            el.getAttribute("phx-feedback-for"),
          ]);

        feedbacks.forEach(([feedbackEl, name]) => {
          let query = `[name="${name}"], [name="${name}[]"]`;
          let isUsed = Array.from(container.querySelectorAll(query)).find((input) =>
            isUsedInput(input),
          );
          if (isUsed || !feedbackEl.hasAttribute("phx-feedback-for")) {
            feedbackEl.classList.remove("phx-no-feedback");
          } else {
            feedbackEl.classList.add("phx-no-feedback");
          }
        });
      };

      let phxFeedbackDom = (dom) => {
        window.addEventListener("reset", (e) => resetFeedbacks(document));
        let feedbacks;
        let submitPending = false;
        let inputPending = false;
        window.addEventListener("submit", (e) => (submitPending = e.target));
        window.addEventListener("input", (e) => (inputPending = e.target));
        // extend provided dom options with our own.
        // accumulate phx-feedback-for containers for each patch and reset feedbacks when patch ends
        return {
          onPatchStart(container) {
            feedbacks = [];
            dom.onPatchStart && dom.onPatchStart(container);
          },
          onNodeAdded(node) {
            if (node.hasAttribute && node.hasAttribute("phx-feedback-for")) {
              feedbacks.push([node, node.getAttribute("phx-feedback-for")]);
            }
            dom.onNodeAdded && dom.onNodeAdded(node);
          },
          onBeforeElUpdated(from, to) {
            let fromFor = from.getAttribute("phx-feedback-for");
            let toFor = to.getAttribute("phx-feedback-for");
            if (fromFor || toFor) {
              feedbacks.push([from, fromFor || toFor], [to, toFor || fromFor]);
            }

            dom.onBeforeElUpdated && dom.onBeforeElUpdated(from, to);
          },
          onPatchEnd(container) {
            resetFeedbacks(container, feedbacks);
            // we might not find some feedback nodes if they are skipped in the patch
            // therefore we explicitly reset feedbacks for all nodes when the patch
            // follows a submit or input event
            if (inputPending || submitPending) {
              resetFeedbacks(container);
              inputPending = null;
              submitPending = null;
            }
            dom.onPatchEnd && dom.onPatchEnd(container);
          },
        };
      };
      let csrfToken = document
        .querySelector("meta[name='csrf-token']")
        .getAttribute("content");
      let liveSocket = new LiveSocket("/live", window.Phoenix.Socket, {
        params: { _csrf_token: csrfToken },
        dom: phxFeedbackDom({}),
      });
      liveSocket.connect();
      window.liveSocket = liveSocket;
    </script>

    {@inner_content}
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
    <p>Button Count: {@count}</p>
    <p>Validate Count: {@validate_count}</p>
    <p>Submit Count: {@submit_count}</p>
    <button phx-click="inc" class="bg-blue-500 text-white p-4">+</button>
    <button phx-click="dec" class="bg-blue-500 text-white p-4">-</button>

    <.myform />

    {# render inside function component to trigger the phx-magic-id optimization}
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
