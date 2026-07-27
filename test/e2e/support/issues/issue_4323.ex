defmodule Phoenix.LiveViewTest.E2E.Issue4323Live do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:counter, 0)
      |> assign(:render_in_root, fn assigns ->
        ~H"""
        <script>
          class Issue4323Face extends HTMLElement {
            static formAssociated = true;
            constructor() {
              super();
              this.attachInternals();
            }
          }
          customElements.define("issue-4323-face", Issue4323Face);

          class Issue4323DelegatesFace extends HTMLElement {
            static formAssociated = true;
            constructor() {
              super();
              this.attachInternals();
              this.attachShadow({ mode: "open", delegatesFocus: true });
              this.shadowRoot.innerHTML = '<input type="text"><slot></slot>';
            }
          }
          customElements.define("issue-4323-delegates-face", Issue4323DelegatesFace);
        </script>
        """
      end)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <form id="test-form">
      <issue-4323-face id="face-default" tabindex="0">
        <span id="face-default-child">count:{@counter}</span>
      </issue-4323-face>

      <issue-4323-face id="face-opt-in" tabindex="0" phx-patch-focused>
        <span id="face-opt-in-child">count:{@counter}</span>
      </issue-4323-face>

      <issue-4323-delegates-face id="face-delegates" phx-patch-focused>
        <span id="face-delegates-child">count:{@counter}</span>
      </issue-4323-delegates-face>

      <input id="native-default" value={@counter} />
      <input id="native-opt-in" value={@counter} phx-patch-focused />
    </form>
    """
  end
end
