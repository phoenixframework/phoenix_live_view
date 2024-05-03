defmodule Phoenix.LiveViewTest.E2E.Issue2787Live do
  use Phoenix.LiveView

  # https://github.com/phoenixframework/phoenix_live_view/issues/2787

  @greetings ["hello", "hallo", "hei"]
  @goodbyes ["goodbye", "auf wiedersehen", "ha det bra"]

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       form: to_form(changeset(%{}), as: :demo),
       select1_opts: ["greetings", "goodbyes"],
       select2_opts: []
     )}
  end

  @types %{
    select1: :string,
    select2: :string,
    dummy: :string
  }

  def changeset(params) do
    Ecto.Changeset.cast({%{}, @types}, params, [:select1, :select2, :dummy])
  end

  @impl Phoenix.LiveView
  def handle_event("updated", %{"demo" => demo_params}, socket) do
    select2_opts =
      case Map.get(demo_params, "select1") do
        "greetings" -> @greetings
        "goodbyes" -> @goodbyes
        _ -> []
      end

    # Ideally select2 gets reset when select1 updates but we'll leave it off
    # for simplicity

    {:noreply,
     assign(socket, form: to_form(changeset(demo_params), as: :demo), select2_opts: select2_opts)}
  end

  def handle_event("submitted", %{"demo" => _demo_params}, socket) do
    {:noreply,
     assign(socket,
       form: to_form(changeset(%{}), as: :demo),
       select2_opts: []
     )}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <script src="https://cdn.tailwindcss.com/3.4.3"></script>
    <div class="p-20">
      <.form for={@form} phx-change="updated" phx-submit="submitted" class="space-y-4">
        <.input
          type="select"
          field={@form[:select1]}
          label="select1"
          prompt="Select"
          options={@select1_opts}
        />

        <.input
          type="select"
          field={@form[:select2]}
          label="select2"
          prompt="Select"
          options={@select2_opts}
        />

        <.input type="text" field={@form[:dummy]} label="Some text" />

        <button class="text-sm border bg-zinc-200" type="submit">Submit</button>
      </.form>
    </div>
    """
  end

  attr :for, :string, default: nil
  slot(:inner_block, required: true)

  def label(assigns) do
    ~H"""
    <label for={@for} class="block text-sm font-semibold leading-6 text-zinc-800">
      <%= render_slot(@inner_block) %>
    </label>
    """
  end

  ###
  # Input components copied and adjusted from generated core_components

  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               range search select tel text textarea time url week)

  attr :field, Phoenix.HTML.FormField

  attr :errors, :list, default: []
  attr :checked, :boolean
  attr :prompt, :string
  attr :options, :list
  attr :multiple, :boolean, default: false

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  slot(:inner_block)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, errors)
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div>
      <.label for={@id}><%= @label %></.label>
      <select
        id={@id}
        name={@name}
        class="mt-2 block w-full rounded-md border border-gray-300 bg-white shadow-sm focus:border-zinc-400 focus:ring-0 sm:text-sm"
        multiple={@multiple}
        {@rest}
      >
        <option :if={@prompt} value=""><%= @prompt %></option>
        <%= Phoenix.HTML.Form.options_for_select(@options, @value) %>
      </select>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div>
      <.label for={@id}><%= @label %></.label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[
          "mt-2 px-2 block w-full rounded-lg text-zinc-900 border focus:ring-0 sm:text-sm sm:leading-6",
          @errors == [] && "border-zinc-300 focus:border-zinc-400",
          @errors != [] && "border-rose-400 focus:border-rose-400"
        ]}
        {@rest}
      />
    </div>
    """
  end
end
