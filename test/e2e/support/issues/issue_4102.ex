defmodule Phoenix.LiveViewTest.E2E.Issue4102Live do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, socket |> assign(form: to_form(%{"name" => "Test"}))}
  end

  def handle_event("validate", %{"name" => name}, socket) do
    IO.inspect(name, label: "Name")
    {:noreply, socket |> assign(form: to_form(%{"name" => name}))}
  end

  def handle_event("submit", %{"name" => name}, socket) do
    IO.inspect(name, label: "Name")
    {:noreply, socket |> assign(form: to_form(%{"name" => name}))}
  end

  def render(assigns) do
    ~H"""
    <div>
      <input
        form="my-form"
        phx-debounce="500"
        name={@form[:name].name}
        id={@form[:name].id}
        value={@form[:name].value}
        type="text"
      />
      <.form for={@form} id="my-form" phx-change="validate" phx-submit="submit">
        <button type="submit" phx-disable-with="Submitting...">Submit</button>
      </.form>
    </div>
    """
  end
end
