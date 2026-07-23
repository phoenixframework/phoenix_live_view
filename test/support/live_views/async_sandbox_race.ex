defmodule Phoenix.LiveViewTest.Support.AsyncSandboxRaceLive do
  use Phoenix.LiveView

  alias Phoenix.LiveView.AsyncResult
  alias Phoenix.LiveViewTest.Support.Repo

  def render(assigns) do
    ~H"""
    <div id="async-sandbox-race">
      <p>data: {inspect(@data)}</p>
      <button id="navigate" phx-click="navigate">navigate</button>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    if connected?(socket) do
      test_pid = Process.whereis(:async_sandbox_race_test)

      {:ok,
       assign_async(socket, :data, fn ->
         # Hold a checked-out sandbox connection open so push_navigate can kill the LiveView
         # (and this linked async) while the DB client is active.
         Repo.transaction(fn ->
           if test_pid, do: send(test_pid, {:async_holding_connection, self()})

           # Keep the checkout alive long enough for the test to navigate away.
           Process.sleep(200)
           _ = Repo.query!("SELECT 1")
           %{data: :done}
         end)
       end)}
    else
      {:ok, assign(socket, data: AsyncResult.loading())}
    end
  end

  def handle_event("navigate", _params, socket) do
    {:noreply, push_navigate(socket, to: "/async_sandbox_race/done")}
  end
end

defmodule Phoenix.LiveViewTest.Support.AsyncSandboxRaceDoneLive do
  use Phoenix.LiveView

  def render(assigns) do
    ~H"""
    <div id="async-sandbox-race-done">done</div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
