defmodule Phoenix.LiveViewTest.E2E.KeyedComprehensionLive do
  use Phoenix.LiveView

  @count 10

  def render(assigns) do
    ~H"""
    <link href="https://cdn.jsdelivr.net/npm/daisyui@5" rel="stylesheet" type="text/css" />
    <div class="p-8">
      <div class="border-b border-gray-200 mb-6">
        <nav role="tablist" class="tabs tabs-border">
          <.link
            role="tab"
            class={"tab #{if @active_tab == "all_keyed", do: "tab-active"}"}
            patch="/keyed-comprehension?tab=all_keyed"
          >
            All keyed
          </.link>
          <.link
            role="tab"
            class={"tab #{if @active_tab == "rows_keyed", do: "tab-active"}"}
            patch="/keyed-comprehension?tab=rows_keyed"
          >
            Rows keyed
          </.link>
          <.link
            role="tab"
            class={"tab #{if @active_tab == "no_keyed", do: "tab-active"}"}
            patch="/keyed-comprehension?tab=no_keyed"
          >
            No keyed
          </.link>
        </nav>
      </div>

      <button class="btn" phx-click="randomize">randomize</button>
      <button class="btn" phx-click="change_0">change first</button>
      <button class="btn" phx-click="change_other">change other</button>

      <form>
        <input phx-change="change_size" name="size" value={@size} />
      </form>

      <div :for={i <- 1..2} :key={i}>
        <.table_with_all_keyed
          :if={@active_tab == "all_keyed"}
          rows={@items}
          id={fn row -> row.id end}
        >
          <:col :let={%{entry: entry}} id="1" name="Foo">
            <.my_component my_count={@count} the_name={entry.foo.bar} /> {i}
          </:col>
          <:col id="2" name="Count">{@count}</:col>
        </.table_with_all_keyed>

        <.table_with_rows_keyed
          :if={@active_tab == "rows_keyed"}
          rows={@items}
          id={fn row -> row.id end}
        >
          <:col :let={%{entry: entry}} id="1" name="Foo">
            <.my_component my_count={@count} the_name={entry.foo.bar} /> {i}
          </:col>
          <:col id="2" name="Count">{@count}</:col>
        </.table_with_rows_keyed>

        <.table_with_no_keyed :if={@active_tab == "no_keyed"} rows={@items} id={fn row -> row.id end}>
          <:col :let={%{entry: entry}} id="1" name="Foo">
            <.my_component my_count={@count} the_name={entry.foo.bar} /> {i}
          </:col>
          <:col id="2" name="Count">{@count}</:col>
        </.table_with_no_keyed>
      </div>
    </div>
    """
  end

  defp my_component(assigns) do
    ~H"""
    <span>
      Count: {@my_count} Name: {@the_name}
    </span>
    """
  end

  attr :rows, :list, required: true
  slot :col

  defp table_with_all_keyed(assigns) do
    ~H"""
    <div class="mt-8 flow-root">
      <div class="-mx-4 -my-2 overflow-x-auto sm:-mx-6 lg:-mx-8">
        <div class="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8">
          <table class="min-w-full divide-y divide-gray-300">
            <thead>
              <tr>
                <th
                  :for={slot <- @col}
                  :key={slot.id}
                  scope="col"
                  class="py-3.5 first:pr-3 first:pl-4 px-3 text-left text-sm font-semibold text-gray-900 first:sm:pl-0"
                >
                  {slot.name}
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-200">
              <tr :for={row <- @rows} :key={@id.(row)}>
                <td
                  :for={slot <- @col}
                  :key={"#{@id.(row)}_#{slot.id}"}
                  class="py-4 first:pr-3 first:pl-4 px-3 text-sm first:font-medium whitespace-nowrap first:text-gray-900 text-gray-500 first:sm:pl-0"
                >
                  {render_slot(slot, row)}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end

  attr :rows, :list, required: true
  slot :col

  defp table_with_rows_keyed(assigns) do
    ~H"""
    <div class="mt-8 flow-root">
      <div class="-mx-4 -my-2 overflow-x-auto sm:-mx-6 lg:-mx-8">
        <div class="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8">
          <table class="min-w-full divide-y divide-gray-300">
            <thead>
              <tr>
                <th
                  :for={slot <- @col}
                  scope="col"
                  class="py-3.5 first:pr-3 first:pl-4 px-3 text-left text-sm font-semibold text-gray-900 first:sm:pl-0"
                >
                  {slot.name}
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-200">
              <tr :for={row <- @rows} :key={@id.(row)}>
                <td
                  :for={slot <- @col}
                  class="py-4 first:pr-3 first:pl-4 px-3 text-sm first:font-medium whitespace-nowrap first:text-gray-900 text-gray-500 first:sm:pl-0"
                >
                  {render_slot(slot, row)}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end

  attr :rows, :list, required: true
  slot :col

  defp table_with_no_keyed(assigns) do
    ~H"""
    <div class="mt-8 flow-root">
      <div class="-mx-4 -my-2 overflow-x-auto sm:-mx-6 lg:-mx-8">
        <div class="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8">
          <table class="min-w-full divide-y divide-gray-300">
            <thead>
              <tr>
                <th
                  :for={slot <- @col}
                  scope="col"
                  class="py-3.5 first:pr-3 first:pl-4 px-3 text-left text-sm font-semibold text-gray-900 first:sm:pl-0"
                >
                  {slot.name}
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-200">
              <tr :for={row <- @rows}>
                <td
                  :for={slot <- @col}
                  class="py-4 first:pr-3 first:pl-4 px-3 text-sm first:font-medium whitespace-nowrap first:text-gray-900 text-gray-500 first:sm:pl-0"
                >
                  {render_slot(slot, row)}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    :timer.send_interval(1000, :report_memory)
    {:ok, assign(socket, count: 0, items: random_items(@count), size: @count, tailwind: true)}
  end

  def handle_params(params, _session, socket) do
    {:noreply, assign_tab(socket, params)}
  end

  defp assign_tab(socket, %{"tab" => tab}) when tab in ["all_keyed", "rows_keyed", "no_keyed"] do
    assign(socket, :active_tab, tab)
  end

  defp assign_tab(socket, _), do: assign(socket, :active_tab, "all_keyed")

  def handle_event("randomize", _params, socket) do
    {:noreply,
     socket |> assign(:items, random_items(socket.assigns.size)) |> update(:count, &(&1 + 1))}
  end

  def handle_event("change_size", %{"size" => size}, socket) do
    size =
      case size do
        "" -> 0
        _ -> String.to_integer(size)
      end

    {:noreply,
     socket
     |> assign(:items, random_items(size))
     |> assign(:size, size)
     |> update(:count, &(&1 + 1))}
  end

  def handle_event("change_0", _params, socket) do
    {:noreply,
     socket
     |> assign(:items, [
       %{id: 2000, entry: %{other: "hey", foo: %{bar: "#{System.unique_integer()}"}}}
       | Enum.slice(socket.assigns.items, 1..(socket.assigns.size + 1))
     ])}
  end

  def handle_event("change_other", _params, socket) do
    {:noreply,
     socket
     |> assign(
       :items,
       Enum.map(socket.assigns.items, fn item ->
         %{item | entry: %{item.entry | other: "hey #{System.unique_integer()}"}}
       end)
     )}
  end

  def handle_info(:report_memory, socket) do
    :erlang.garbage_collect()
    IO.puts("Heap size: #{Process.info(self())[:total_heap_size]}")

    {:noreply, socket}
  end

  def random_items(size) do
    1..(size * 2)
    |> Enum.take_random(size)
    |> Enum.map(&%{id: &1, entry: %{other: "hey", foo: %{bar: "New#{&1 + 1}"}}})
  end
end
