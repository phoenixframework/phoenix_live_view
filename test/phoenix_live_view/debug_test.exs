defmodule Phoenix.LiveView.DebugTest do
  use ExUnit.Case, async: true

  alias Phoenix.LiveView.Debug
  import Phoenix.LiveViewTest

  @endpoint Phoenix.LiveViewTest.Support.Endpoint

  defmodule TestLV do
    use Phoenix.LiveView

    defmodule Component do
      use Phoenix.LiveComponent

      def render(assigns) do
        ~H"""
        <p>Hello</p>
        """
      end
    end

    def mount(_params, _session, socket) do
      {:ok, assign(socket, :hello, :world)}
    end

    def render(assigns) do
      ~H"""
      <div>
        <p>Hello</p>
        <.live_component id="component-1" module={Component} />
      </div>
      """
    end
  end

  describe "list_liveviews/0" do
    test "returns a list of all currently connected LiveView processes" do
      conn = Plug.Test.conn(:get, "/")
      {:ok, view, _} = live_isolated(conn, TestLV)
      live_views = Debug.list_liveviews()

      assert is_list(live_views)
      assert lv = Enum.find(live_views, fn lv -> lv.pid == view.pid end)
      assert lv.view == TestLV
      assert lv.transport_pid
      assert lv.topic
    end
  end

  describe "liveview_process?/1" do
    test "returns true if the given pid is a LiveView process" do
      conn = Plug.Test.conn(:get, "/")
      {:ok, view, _} = live_isolated(conn, TestLV)
      assert Debug.liveview_process?(view.pid)
    end
  end

  describe "socket/1" do
    test "returns the socket of the given LiveView process" do
      conn = Plug.Test.conn(:get, "/")
      {:ok, view, _} = live_isolated(conn, TestLV)
      assert {:ok, socket} = Debug.socket(view.pid)
      assert socket.assigns.hello == :world
    end

    test "returns an error if the given pid is not a LiveView process" do
      defmodule NotALiveView do
        use GenServer

        def start_link(opts) do
          GenServer.start_link(__MODULE__, opts)
        end

        def init(opts) do
          {:ok, opts}
        end
      end

      pid = start_supervised!(NotALiveView)
      assert {:error, :not_alive_or_not_a_liveview} = Debug.socket(pid)
    end
  end

  describe "live_components/1" do
    test "returns a list of all LiveComponents rendered in the given LiveView" do
      conn = Plug.Test.conn(:get, "/")
      {:ok, view, _} = live_isolated(conn, TestLV)

      assert {:ok, [%{id: "component-1", module: TestLV.Component}]} =
               Debug.live_components(view.pid)
    end
  end
end
