defmodule Phoenix.LiveViewTest.E2E.ColocatedLive do
  use Phoenix.LiveView, layout: {__MODULE__, :live}

  defmodule SyntaxHighlight do
    @behaviour Phoenix.Component.MacroComponent

    @impl true
    def transform({"pre", attrs, children, _tag_meta}, _meta) do
      code = Phoenix.Component.MacroComponent.ast_to_string(children)
      lang = Map.new(attrs)["language"] || raise ArgumentError, "language attribute is required"
      html_doc = highlight(String.trim_leading(code), lang)

      stylesheet =
        Makeup.Styles.HTML.Style.stylesheet(Makeup.Styles.HTML.StyleMap.monokai_style())

      {:ok,
       {"pre", [{"class", "highlight"} | attrs],
        [
          {"style", [], [stylesheet, ".highlight { padding: 8px; border-radius: 4px; }"], %{}},
          html_doc
        ], %{}}}
    end

    defp highlight(code, lang) do
      Application.ensure_all_started([:makeup, :makeup_elixir, :makeup_eex, :makeup_syntect])

      case Makeup.Registry.get_lexer_by_name(lang) do
        {lexer, opts} ->
          Makeup.highlight_inner_html(code, lexer: lexer, lexer_options: opts)

        _ ->
          code
      end
    end
  end

  alias Phoenix.LiveView.ColocatedHook, as: Hook
  alias Phoenix.LiveView.JS

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :phone, nil)}
  end

  def handle_event("submit-phone", params, socket) do
    {:noreply, assign(socket, :phone, params["user"]["phone_number"])}
  end

  def handle_event("push-js", _params, socket) do
    {:noreply, push_js_cmd(socket, JS.toggle(to: "#hello"))}
  end

  def render("live.html", assigns) do
    ~H"""
    <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
    <script src="/assets/phoenix/phoenix.min.js">
    </script>
    <script type="module">
      import {LiveSocket} from "/assets/phoenix_live_view/phoenix_live_view.esm.js"
      import {default as colocated, hooks} from "/assets/colocated/index.js";
      let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
      let liveSocket = new LiveSocket("/live", window.Phoenix.Socket, {
        params: {_csrf_token: csrfToken},
        reloadJitterMin: 50,
        reloadJitterMax: 500,
        hooks
      })
      liveSocket.connect()
      window.liveSocket = liveSocket
      // initialize js exec handler from colocated js
      colocated.js_exec(liveSocket)
    </script>
    <link rel="stylesheet" href="/assets/colocated_css/colocated.css" />

    {@inner_content}
    """
  end

  def render(assigns) do
    ~H"""
    <form phx-submit="submit-phone">
      <input type="text" name="user[phone_number]" id="user-phone-number" phx-hook=".PhoneNumber" />
      <script :type={Hook} name=".PhoneNumber">
        export default {
          mounted() {
            this.el.addEventListener("input", e => {
              let match = this.el.value.replace(/\D/g, "").match(/^(\d{3})(\d{3})(\d{4})$/)
              if(match) {
                this.el.value = `${match[1]}-${match[2]}-${match[3]}`
              }
            })
          }
        }
      </script>
    </form>

    <p id="phone">{@phone}</p>

    <script :type={Phoenix.LiveView.ColocatedJS} name="js_exec">
      export default function(liveSocket) {
        window.addEventListener("phx:js:exec", e => liveSocket.execJS(liveSocket.main.el, e.detail.cmd))
      }
    </script>

    <div id="runtime" phx-hook=".Runtime" style="display: none;">Runtime hook works!</div>
    <script :type={Hook} name=".Runtime" runtime>
      {
        mounted() {
          this.js().show(this.el);
        }
      }
    </script>

    <hr />

    <button phx-click="push-js">Push JS from server</button>
    <h1 id="hello">Hello!</h1>

    <hr />

    <pre :type={SyntaxHighlight} language="elixir" phx-no-curly-interpolation>
    defmodule SyntaxHighlight do
      @behaviour Phoenix.Component.MacroComponent

      @impl true
      def transform({"pre", attrs, children, _tag_meta}, _meta) do
        code = Phoenix.Component.MacroComponent.ast_to_string(children)
        lang = Map.new(attrs)["language"] || raise ArgumentError, "language attribute is required"
        html_doc = highlight(String.trim_leading(code), lang)

        stylesheet =
          Makeup.Styles.HTML.Style.stylesheet(Makeup.Styles.HTML.StyleMap.monokai_style())

        {:ok,
        {"pre", [{"class", "highlight"} | attrs],
          [
            {"style", [], [stylesheet, ".highlight { padding: 8px; border-radius: 4px; }"], %{}},
            html_doc
          ], %{}}}
      end

      defp highlight(code, lang) do
        Application.ensure_all_started([:makeup, :makeup_elixir, :makeup_eex, :makeup_syntect])

        case Makeup.Registry.get_lexer_by_name(lang) do
          {lexer, opts} ->
            Makeup.highlight_inner_html(code, lexer: lexer, lexer_options: opts)

          _ ->
            code
        end
      end
    end
    </pre>

    <.global_colocated_css />
    <p data-test="global" class="test-global-css">Should have red background</p>
    <.scoped_colocated_css />
    <p data-test="scoped" class="test-scoped-css">Should have no background (out of scope)</p>
    <.scoped_inclusive_lower_bound_colocated_css />
    <.scoped_exclusive_lower_bound_colocated_css />

    <.lv_code_sample />
    """
  end

  def push_js_cmd(socket, %JS{ops: ops}) do
    push_event(socket, "js:exec", %{cmd: Phoenix.json_library().encode!(ops)})
  end

  defp lv_code_sample(assigns) do
    ~H'''
    <pre :type={SyntaxHighlight} language="elixir" phx-no-curly-interpolation>
    defmodule MyAppWeb.ThermostatLive do
      use MyAppWeb, :live_view

      def render(assigns) do
        ~H"""
        Current temperature: {@temperature}°F
        <button phx-click="inc_temperature">+</button>
        """
      end

      def mount(_params, _session, socket) do
        temperature = 70 # Let's assume a fixed temperature for now
        {:ok, assign(socket, :temperature, temperature)}
      end

      def handle_event("inc_temperature", _params, socket) do
        {:noreply, update(socket, :temperature, &(&1 + 1))}
      end
    end
    </pre>
    '''
  end

  defp global_colocated_css(assigns) do
    ~H"""
    <style :type={Phoenix.LiveView.ColocatedCSS} global>
      .test-global-css { background-color: rgb(255, 0, 0); }
    </style>
    """
  end

  defp scoped_colocated_css(assigns) do
    ~H"""
    <style :type={Phoenix.LiveView.ColocatedCSS}>
      .test-scoped-css { background-color: rgb(0, 0, 255); }
    </style>
    <div>
      <span data-test-scoped="blue" class="test-scoped-css">Should have blue background</span>
      <.scoped_css_inner_block_one>
        <span data-test-scoped="none" class="test-scoped-css">
          Should have no background (scope root)
          <span data-test-scoped="blue" class="test-scoped-css">
            Should have blue background
          </span>
        </span>
      </.scoped_css_inner_block_one>
      <.scoped_css_inner_block_one>
        <span data-test-scoped="none" class="test-scoped-css">
          Should have no background (scope root)
          <span data-test-scoped="blue" class="test-scoped-css">
            Should have blue background
          </span>
        </span>
      </.scoped_css_inner_block_one>
      <.scoped_css_inner_block_two>
        <span data-test-scoped="none" class="test-scoped-css">
          Should have no background (scope root)
          <span data-test-scoped="blue" class="test-scoped-css">
            Should have blue background
          </span>
        </span>
      </.scoped_css_inner_block_two>
      <.scoped_css_slot_one>
        <:test>
          <span data-test-scoped="none" class="test-scoped-css">
            Should have no background (scope root)
            <span data-test-scoped="blue" class="test-scoped-css">
              Should have blue background
            </span>
          </span>
        </:test>
      </.scoped_css_slot_one>
      <.scoped_css_slot_two>
        <:test>
          <span data-test-scoped="none" class="test-scoped-css">
            Should have no background (scope root)
            <span data-test-scoped="blue" class="test-scoped-css">
              Should have blue background
            </span>
          </span>
        </:test>
      </.scoped_css_slot_two>
    </div>
    """
  end

  slot :inner_block, required: true

  defp scoped_css_inner_block_one(assigns) do
    ~H"""
    {render_slot(@inner_block)}
    """
  end

  slot :inner_block, required: true

  defp scoped_css_inner_block_two(assigns) do
    ~H"""
    <style :type={Phoenix.LiveView.ColocatedCSS}>
      .test-scoped-css { background-color: rgb(255, 255, 0); }
    </style>
    <div>
      <span data-test-scoped="yellow" class="test-scoped-css">Should have yellow background</span>
      {render_slot(@inner_block)}
    </div>
    """
  end

  slot :test, required: true

  defp scoped_css_slot_one(assigns) do
    ~H"""
    {render_slot(@test)}
    """
  end

  slot :test, required: true

  defp scoped_css_slot_two(assigns) do
    ~H"""
    <style :type={Phoenix.LiveView.ColocatedCSS}>
      .test-scoped-css { background-color: rgb(0, 255, 0); }
    </style>
    <div>
      <span data-test-scoped="green" class="test-scoped-css">Should have green background</span>
      {render_slot(@test)}
    </div>
    """
  end

  defp scoped_exclusive_lower_bound_colocated_css(assigns) do
    ~H"""
    <style :type={Phoenix.LiveView.ColocatedCSS}>
      .container:where(:scope) {
        display: flex;

        > * {
          flex: 1;
        }
      }
    </style>
    <div data-test-lower-bound-container class="container">
      <.flex_items should_flex?={false} />
    </div>
    """
  end

  defp scoped_inclusive_lower_bound_colocated_css(assigns) do
    ~H"""
    <style :type={Phoenix.LiveView.ColocatedCSS} lower-bound="inclusive">
      .container:where(:scope) {
        display: flex;

        > * {
          flex: 1;
        }
      }
    </style>
    <div data-test-lower-bound-container class="container">
      <.flex_items should_flex?={true} />
    </div>
    """
  end

  attr :should_flex?, :boolean, required: true

  defp flex_items(assigns) do
    ~H"""
    <p :for={x <- 1..3} data-test-inclusive={if @should_flex?, do: "yes", else: "no"}>
      {if @should_flex?, do: "Should", else: "Shouldn't"} Flex {x}
    </p>
    """
  end
end
