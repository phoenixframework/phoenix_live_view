defmodule Phoenix.LiveViewTest.E2E.Issue4323Live do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:counter, 0)
      |> assign(:render_in_root, fn assigns ->
        ~H"""
        <script>
          // Case 1 & 2: Basic FACE, no shadow DOM
          class FaceBasic extends HTMLElement {
            static formAssociated = true;
            constructor() { super(); this.attachInternals(); }
          }
          customElements.define("face-basic", FaceBasic);

          // Case 3: FACE with shadow DOM + slot (no delegatesFocus)
          class FaceSlotted extends HTMLElement {
            static formAssociated = true;
            constructor() {
              super();
              this.attachInternals();
              this.attachShadow({ mode: "open" });
              this.shadowRoot.innerHTML = "<div><slot></slot></div>";
            }
          }
          customElements.define("face-slotted", FaceSlotted);

          // Case 4: FACE with shadow DOM + delegatesFocus
          class FaceDelegates extends HTMLElement {
            static formAssociated = true;
            constructor() {
              super();
              this.attachInternals();
              this.attachShadow({ mode: "open", delegatesFocus: true });
              this.shadowRoot.innerHTML = '<input type="text" />';
            }
          }
          customElements.define("face-delegates", FaceDelegates);

          // Case 5: Non-FACE custom element
          class NonFaceEl extends HTMLElement {}
          customElements.define("non-face-el", NonFaceEl);
        </script>
        """
      end)

    {:ok, socket}
  end

  def handle_event("inc", _params, socket) do
    {:noreply, assign(socket, :counter, socket.assigns.counter + 1)}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <form id="test-form" phx-change="validate">
      <%!-- Case 1: Basic FACE, focusable via tabindex --%>
      <face-basic id="case1" tabindex="0">
        <span id="case1-child">count:{@counter}</span>
      </face-basic>

      <%!-- Case 2: FACE with light DOM input child --%>
      <face-basic id="case2" tabindex="0">
        <span id="case2-child">count:{@counter}</span>
        <input id="case2-input" type="text" name="case2_input" />
      </face-basic>

      <%!-- Case 3: FACE with slotted input --%>
      <face-slotted id="case3">
        <input id="case3-input" type="text" name="case3_input" />
        <span id="case3-child">count:{@counter}</span>
      </face-slotted>

      <%!-- Case 4: FACE with delegatesFocus --%>
      <face-delegates id="case4">
        <span id="case4-child">count:{@counter}</span>
      </face-delegates>

      <%!-- Case 5: Non-FACE custom element --%>
      <non-face-el id="case5" tabindex="0">
        <span id="case5-child">count:{@counter}</span>
      </non-face-el>

      <button id="inc-btn" type="button" phx-click="inc">Increment</button>
    </form>
    """
  end
end
