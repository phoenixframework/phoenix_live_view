defmodule Phoenix.LiveViewTest.E2E.FormDynamicInputsLive do
  use Phoenix.LiveView

  alias Phoenix.LiveView.JS

  @impl Phoenix.LiveView
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign_form(%{})
     |> assign(:checkboxes, params["checkboxes"] == "1")
     |> assign(:submitted, false)}
  end

  defp assign_form(socket, params) do
    form =
      Map.take(params, ["name"])
      |> Map.put(
        "users",
        build_users(
          params["users"] || %{},
          params["users_sort"] || [],
          params["users_drop"] || []
        )
      )
      |> to_form(as: :my_form, id: "my-form", default: [])

    assign(socket, :form, form)
  end

  defp build_users(value, sort, drop) do
    {sorted, pending} =
      if is_list(sort) do
        Enum.map_reduce(sort -- drop, value, &Map.pop(&2, &1, %{"name" => nil}))
      else
        {[], value}
      end

    result =
      sorted ++
        (pending
         |> Map.drop(drop)
         |> Enum.map(&key_as_int/1)
         |> Enum.sort()
         |> Enum.map(&elem(&1, 1)))

    Enum.with_index(result)
    |> Map.new(fn {item, i} -> {to_string(i), item} end)
  end

  defp key_as_int({key, val}) when is_binary(key) and byte_size(key) < 32 do
    case Integer.parse(key) do
      {key, ""} -> {key, val}
      _ -> {key, val}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("validate", %{"my_form" => params}, socket) do
    {:noreply, assign_form(socket, params)}
  end

  def handle_event("save", %{"my_form" => params}, socket) do
    socket
    |> assign_form(params)
    |> assign(:submitted, true)
    |> then(&{:noreply, &1})
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.form
      for={@form}
      phx-change="validate"
      phx-submit="save"
      style="display: flex; flex-direction: column; gap: 4px; max-width: 500px;"
    >
      <fieldset>
        <input
          type="text"
          id={@form[:name].id}
          name={@form[:name].name}
          value={@form[:name].value}
          placeholder="name"
        />
        <.inputs_for :let={ef} field={@form[:users]} default={[]}>
          <div style="padding: 4px; border: 1px solid gray;">
            <input type="hidden" name="my_form[users_sort][]" value={ef.index} />
            <input
              type="text"
              id={ef[:name].id}
              name={ef[:name].name}
              value={ef[:name].value}
              placeholder="name"
            />

            <button
              :if={!@checkboxes}
              type="button"
              name="my_form[users_drop][]"
              value={ef.index}
              phx-click={JS.dispatch("change")}
            >
              Remove
            </button>
            <label :if={@checkboxes}>
              <input type="checkbox" name="my_form[users_drop][]" value={ef.index} /> Remove
            </label>
          </div>
        </.inputs_for>
      </fieldset>

      <input type="hidden" name="my_form[users_drop][]" />

      <button
        :if={!@checkboxes}
        type="button"
        name="my_form[users_sort][]"
        value="new"
        phx-click={JS.dispatch("change")}
      >
        add more
      </button>
      <label :if={@checkboxes}>
        <input type="checkbox" name="my_form[users_sort][]" /> add more
      </label>
    </.form>

    <p :if={@submitted}>Form was submitted!</p>
    """
  end
end
