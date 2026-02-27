defmodule Phoenix.LiveViewTest.E2E.Issue3647Live do
  # https://github.com/phoenixframework/phoenix_live_view/issues/3647
  #
  # The above issue was caused by LV uploads relying on DOM attributes like
  # data-phx-active-refs="1,2,3" being in the DOM to track uploads. The problem
  # arises when the upload input is inside a form that is locked due to another,
  # unrelated change. The following would happen:
  #
  # 1. User clicks on a button to upload a file
  # 2. A hook calls this.uploadTo(), which triggers a validate event and locks the form
  # 3. The hook also changes another input in ANOTHER form, which also triggers a separate validate
  #    event and locks the form
  # 4. The first validate completes, but the attributes are patched to the clone of the form,
  #    the real DOM does not contain it.
  # 5. LiveView tries to start uploading, but does not find any active files.
  #
  # This case is special in that the upload input belongs to a separate form (<input form="form-id">),
  # so it's not the upload input's form that is locked.
  #
  # The fix for this is to only try to upload when the closest locked element starting from
  # the upload input is unlocked.
  #
  # There was a separate problem though: LiveView relied on a separate DOM patching mechanism
  # when patching cloned trees that did not fully share the same logic as the default DOMPatch.
  # In this case, it did not merge data-attributes on elements that are ignored (phx-update="ignore" / data-phx-update="ignore"),
  # therefore, the first fix alone would not work.
  # Now, we use the same patching logic for regular DOM patches and element unlocks.
  #
  # This difference in DOM patching logic also caused other issues, notably:
  #   * https://github.com/phoenixframework/phoenix_live_view/issues/3591
  #   * https://github.com/phoenixframework/phoenix_live_view/issues/3651
  use Phoenix.LiveView

  defmodule User do
    import Ecto.Changeset
    use Ecto.Schema

    schema "users" do
      field(:name)
    end

    def change_user(user, params \\ %{}) do
      user |> cast(params, [:name])
    end
  end

  def render("live.html", assigns) do
    ~H"""
    <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
    <script src="/assets/phoenix/phoenix.min.js">
    </script>
    <script type="module">
      import { LiveSocket } from "/assets/phoenix_live_view/phoenix_live_view.esm.js";

      let csrfToken = document
        .querySelector("meta[name='csrf-token']")
        .getAttribute("content");
      let liveSocket = new LiveSocket("/live", window.Phoenix.Socket, {
        params: { _csrf_token: csrfToken },
        hooks: {
          JsUpload: {
            mounted() {
              this.el.addEventListener("click", () => {
                const fillBefore = "before" in this.el.dataset;
                if (fillBefore) this.fill_input();
                this.js_upload();
                if (!fillBefore) this.fill_input();
              });
            },

            js_upload() {
              const content = "x".repeat(1024).repeat(1024);
              const file = new File([content], "1mb_of_x.txt", {
                type: "text/plain",
              });
              const input = document.querySelector("input[type=file]");
              this.uploadTo(input.form, input.name, [file]);
            },

            fill_input() {
              const input = document.querySelector("input[type=text]");
              input.value = input.value + input.value.length;
              const event = new Event("input", { bubbles: true });
              input.dispatchEvent(event);
            },
          },
        },
      });
      liveSocket.connect();
      window.liveSocket = liveSocket;
    </script>
    <style>
      * { font-size: 1.1em; }
    </style>

    <main>{@inner_content}</main>
    """
  end

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(form: to_form(User.change_user(%User{})))
     |> assign(:uploaded_files, [])
     |> allow_upload(:avatar,
       accept: ~w(.txt .md),
       max_entries: 2,
       auto_upload: true,
       progress: &handle_progress/3
     ), layout: {__MODULE__, :live}}
  end

  # with auto_upload: true we can consume files here
  defp handle_progress(:avatar, entry, socket) do
    if entry.done? do
      uuid =
        consume_uploaded_entry(socket, entry, fn _meta ->
          {:ok, entry.uuid}
        end)

      {:noreply, update(socket, :uploaded_files, &[uuid | &1])}
    else
      {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("validate-user", %{"user" => params}, socket) do
    form =
      %User{}
      |> User.change_user(params)
      |> to_form(action: :validate)

    {:noreply, assign(socket, form: form)}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :avatar, ref)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.form for={@form} phx-change="validate-user" id="user-form">
      <input id={@form[:name].id} name={@form[:name].name} value={@form[:name].value} type="text" />
      <button id="x" type="button" phx-hook="JsUpload">
        Upload then Input
      </button>
      <button id="y" type="button" phx-hook="JsUpload" data-before>
        Input then Upload
      </button>
      <.live_file_input upload={@uploads.avatar} form="auto-form" />
    </.form>

    <form id="auto-form" phx-change="validate"></form>
    <section class="pending-uploads" phx-drop-target={@uploads.avatar.ref} style="min-height: 100%;">
      <h3>Pending Uploads ({length(@uploads.avatar.entries)})</h3>

      <%= for entry <- @uploads[:avatar].entries do %>
        <div>
          <progress value={entry.progress} max="100">{entry.progress}%</progress>
          <div>
            {entry.uuid}<br />
            <a
              href="#"
              phx-click="cancel-upload"
              phx-value-ref={entry.ref}
              class="upload-entry__cancel"
            >
              Cancel Upload
            </a>
          </div>
        </div>
      <% end %>
    </section>

    <ul>
      <li :for={file <- @uploaded_files}><a href={file}>{Path.basename(file)}</a></li>
    </ul>
    """
  end
end
