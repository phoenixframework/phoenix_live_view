defmodule Phoenix.LiveViewTest.E2E.SelectLive do
  use Phoenix.LiveView

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       tick_timer: nil,
       select2_timer: nil,
       select2_countdown: 5,
       select4_timer: nil,
       select4_countdown: 5,
       tick: 0,
       form: to_form(%{"select3" => "2"}, as: :select_form),
       select1_opts: ["these options", "are fixed"],
       select2_opts: Enum.to_list(1..10),
       select3_opts: 1..10,
       select4_opts: 1..10,
       select4_value: "1"
     )}
  end

  @impl Phoenix.LiveView
  def handle_info(:tick, socket) do
    {:noreply, update(socket, :tick, &(&1 + 1))}
  end

  def handle_info(:update_select2_opts, socket) do
    {:noreply,
     update(socket, :select2_opts, fn existing_opts ->
       existing_opts ++ [Enum.max(existing_opts) + 1]
     end)}
  end

  def handle_info(:select2_countdown, socket) do
    if socket.assigns.select2_countdown == 0 do
      send(self(), :update_select2_opts)
      {:noreply, assign(socket, select2_timer: nil)}
    else
      Process.send_after(self(), :select2_countdown, 1000)
      {:noreply, update(socket, :select2_countdown, &(&1 - 1))}
    end
  end

  def handle_info(:select4_countdown, socket) do
    if socket.assigns.select4_countdown == 0 do
      send(self(), :change_select4_value)
      {:noreply, assign(socket, select4_timer: nil)}
    else
      Process.send_after(self(), :select4_countdown, 1000)
      {:noreply, update(socket, :select4_countdown, &(&1 - 1))}
    end
  end

  def handle_info(:change_select4_value, socket) do
    {:noreply, assign(socket, :select4_value, Enum.random(1..10) |> to_string())}
  end

  @types %{
    select1: :string,
    select2: :integer,
    select3: :integer,
    select4: :integer
  }

  def changeset(params) do
    Ecto.Changeset.cast({%{}, @types}, params, [:select1, :select2, :select3, :select4])
    |> Ecto.Changeset.validate_number(:select3, greater_than: 5)
  end

  @impl Phoenix.LiveView
  def handle_event("validate", %{"select_form" => params}, socket) do
    changeset = changeset(params)

    {:noreply, assign(socket, form: to_form(changeset, as: :select_form, action: :validate))}
  end

  def handle_event("toggle-tick", _, socket) do
    case socket.assigns.tick_timer do
      nil ->
        {:ok, timer_ref} = :timer.send_interval(1000, :tick)
        {:noreply, assign(socket, :tick_timer, timer_ref)}

      ref ->
        Process.cancel_timer(ref)
        {:noreply, assign(socket, :tick_timer, nil)}
    end
  end

  def handle_event("schedule-select2-update", _, socket) do
    timer_ref = Process.send_after(self(), :select2_countdown, 1000)
    {:noreply, assign(socket, select2_countdown: 5, select2_timer: timer_ref)}
  end

  def handle_event("schedule-select4-update", _, socket) do
    timer_ref = Process.send_after(self(), :select4_countdown, 1000)
    {:noreply, assign(socket, select4_countdown: 5, select4_timer: timer_ref)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <style>
      * { font-size: unset; }

      body {
        padding: 20px;
        max-width: 500px;
        font-family: sans-serif;
      }

      .has-error {
        border: 5px solid red;
      }

      select {
        border: 1px solid black;
      }
    </style>

    <h1>Select Playgroud</h1>
    <p>
      This page contains multiple select inputs to test various behaviors.
      Sadly, we cannot test all of them automatically, as there is no way to assert the state of an open select's native UI.
    </p>
    Tick: <%= @tick %>

    <div style="display: flex; flex-direction: column; gap: 8px">
      <button phx-click="toggle-tick">
        <%= if @tick_timer, do: "Disable", else: "Enable" %> ticking
      </button>
      <button :if={!@select2_timer} phx-click="schedule-select2-update">
        Schedule select2 update
      </button>
      <span :if={@select2_timer}>Select 2 will update in <%= @select2_countdown %>s</span>
      <button :if={!@select4_timer} phx-click="schedule-select4-update">
        Schedule select4 update
      </button>
      <span :if={@select4_timer}>Select 4 will update in <%= @select4_countdown %>s</span>
    </div>

    <.form for={@form} phx-change="validate">
      <h2>Select 1</h2>
      <p>
        The select should not close when the page is patched while it is open.
        You can simulate patching by enabling ticking above.
      </p>
      <.input type="select" field={@form[:select1]} label="Select 1" options={@select1_opts} />
      <hr />
      <h2>Select 2</h2>
      <p>
        The second select's options will be updated after a 5s timeout (button on top).
        This can be used to test the behavior of the select when its options change while it is open.
      </p>
      <.input type="select" field={@form[:select2]} label="Select 2" options={@select2_opts} />
      <hr />
      <h2>Select 3</h2>
      <p>
        Error classes are correctly applied to the third select.
        It should have a red border for all values from 1 to 5. The border should disappear when selecting 6 or higher.
      </p>
      <.input type="select" field={@form[:select3]} label="Select 3" options={@select3_opts} />
      <hr />
      <h2>Select 4</h2>
      <p>
        The selected value of this field changes after a 5s timeout (button on top).
        This can be used to test the behavior of the select when its value changes while it is open.
        We expect the value to be ignored if the select is open, as value changes to focused inputs are ignored.
      </p>
      <.input
        type="select"
        field={@form[:select4]}
        value={@select4_value}
        label="Select 4"
        options={@select4_opts}
      />
      <hr />
    </.form>
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
  attr :prompt, :string, default: nil
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
      <select
        id={@id}
        name={@name}
        class={if @errors != [], do: "has-error"}
        multiple={@multiple}
        {@rest}
      >
        <option :if={@prompt} value=""><%= @prompt %></option>
        <%= Phoenix.HTML.Form.options_for_select(@options, @value) %>
      </select>
    </div>
    """
  end
end
