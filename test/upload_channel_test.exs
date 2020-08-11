defmodule Phoenix.LiveView.UploadChannelTest do
  use ExUnit.Case, async: true


  import Phoenix.LiveViewTest

  alias Phoenix.LiveView
  alias Phoenix.LiveViewTest.UploadClient

  @endpoint Phoenix.LiveViewTest.Endpoint
  require Phoenix.ChannelTest

  def inspect_html_safe(term) do
    term
    |> inspect()
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end

  def valid_token(lv_pid, ref) do
    LiveView.Static.sign_token(@endpoint, %{pid: lv_pid, ref: ref})
  end

  def mount_lv(setup) when is_function(setup, 1) do
    conn = Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), %{})
    {:ok, lv, _} = live_isolated(conn, Phoenix.LiveViewTest.UploadLive, session: %{})
    :ok = GenServer.call(lv.pid, {:run, setup})
    {:ok, lv}
  end

  defp build_entries(count, opts \\ []) do
    for i <- 1..count do
      Enum.into(opts, %{
        last_modified: 1_594_171_879_000,
        name: "myfile#{i}.jpeg",
        content: String.duplicate("0", 100),
        size: 1_396_009,
        type: "image/jpeg"
      })
    end
  end

  setup_all do
    ExUnit.CaptureLog.capture_log(fn ->
      {:ok, _} = @endpoint.start_link()

      {:ok, _} =
        Supervisor.start_link([Phoenix.PubSub.child_spec(name: Phoenix.LiveView.PubSub)],
          strategy: :one_for_one
        )
    end)

    :ok
  end

  test "rejects invalid token" do
    {:ok, socket} = Phoenix.ChannelTest.connect(Phoenix.LiveView.Socket, %{}, %{})

    assert {:error, %{reason: "invalid_token"}} =
             Phoenix.ChannelTest.subscribe_and_join(socket, "lvu:123", %{"token" => "bad"})
  end

  describe "with valid token" do
    setup %{allow: opts} do
      {:ok, lv} = mount_lv(fn socket -> Phoenix.LiveView.allow_upload(socket, :avatar, opts) end)
      {:ok, lv: lv}
    end

    @tag allow: [accept: :any]
    test "upload channel exits when LiveView channel exits", %{lv: lv} do
      avatar = file_input(lv, "input[name=avatar]", build_entries(1))
      assert render_upload(avatar, "myfile1.jpeg", 1) =~ "myfile1.jpeg:1%"
      assert %{"myfile1.jpeg" => channel_pid} = UploadClient.channel_pids(avatar)

      Process.unlink(proxy_pid(lv))
      Process.unlink(avatar.pid)
      Process.unlink(channel_pid)
      Process.monitor(channel_pid)
      Process.exit(lv.pid, :kill)
      assert_receive {:DOWN, _ref, :process, ^channel_pid, :killed}
    end

    @tag allow: [accept: :any]
    test "abnormal channel exit brings down LiveView", %{lv: lv} do
      avatar = file_input(lv, "input[name=avatar]", build_entries(1))
      assert render_upload(avatar, "myfile1.jpeg", 1) =~ "myfile1.jpeg:1%"
      assert %{"myfile1.jpeg" => channel_pid} = UploadClient.channel_pids(avatar)

      lv_pid = lv.pid
      Process.unlink(proxy_pid(lv))
      Process.unlink(avatar.pid)
      Process.unlink(channel_pid)
      Process.monitor(lv_pid)
      Process.exit(channel_pid, :kill)

      assert_receive {:DOWN, _ref, :process, ^lv_pid,
                      {:shutdown, {:channel_upload_exit, :killed}}}
    end

    @tag allow: [accept: :any]
    test "normal channel exit is cleaned up by LiveView", %{lv: lv} do
      avatar = file_input(lv, "input[name=avatar]", build_entries(1))
      assert render_upload(avatar, "myfile1.jpeg", 1) =~ "myfile1.jpeg:1%"
      assert %{"myfile1.jpeg" => channel_pid} = UploadClient.channel_pids(avatar)

      lv_pid = lv.pid
      Process.unlink(proxy_pid(lv))
      Process.unlink(channel_pid)
      Process.monitor(lv_pid)
      assert render(lv) =~ "channel:#{inspect_html_safe(channel_pid)}"
      GenServer.stop(channel_pid, :normal)
      refute_receive {:DOWN, _ref, :process, ^lv_pid, _}
      assert render(lv) =~ "channel:nil"
    end

    @tag allow: [max_entries: 3, accept: :any]
    test "multiple entries under max", %{lv: lv} do
      avatar = file_input(lv, "input[name='avatar[]']", build_entries(2))
      assert render_upload(avatar, "myfile1.jpeg", 1) =~ "myfile1.jpeg:1%"
      assert render_upload(avatar, "myfile2.jpeg", 2) =~ "myfile2.jpeg:2%"
      assert %{"myfile1.jpeg" => chan1_pid, "myfile2.jpeg" => chan2_pid} = UploadClient.channel_pids(avatar)

      assert render(lv) =~ "channel:#{inspect_html_safe(chan1_pid)}"
      assert render(lv) =~ "channel:#{inspect_html_safe(chan2_pid)}"
    end

    @tag allow: [max_entries: 1, accept: :any]
    test "too many entries over max", %{lv: lv} do
      avatar = file_input(lv, "input[name=avatar]", build_entries(2))
      assert {:error, [_ref, :too_many_files]} =
             render_upload(avatar, "myfile1.jpeg", 1)
    end

    @tag allow: [max_entries: 3, accept: :any]
    test "preflight_upload", %{lv: lv} do
      avatar = file_input(lv, "input[name='avatar[]']", build_entries(1))
      assert {:ok, %{ref: _ref, config: %{chunk_size: _}}} = preflight_upload(avatar)
    end

    @tag allow: [max_entries: 3, accept: :any]
    test "starting an already in progress entry is denied", %{lv: lv} do
      avatar = file_input(lv, "input[name='avatar[]']", build_entries(1))
      assert render_upload(avatar, "myfile1.jpeg", 1) =~ "1%"
      assert %{"myfile1.jpeg" => channel_pid} = UploadClient.channel_pids(avatar)

      assert render(lv) =~ "channel:#{inspect_html_safe(channel_pid)}"
      assert {:error, [_ref, :already_started]} = preflight_upload(avatar)
      assert render(lv) =~ "channel:#{inspect_html_safe(channel_pid)}"
    end

    @tag allow: [max_entries: 3, chunk_size: 20, accept: :any]
    test "render_upload uploads entire file by default", %{lv: lv} do
      avatar = file_input(lv, "input[name='avatar[]']", [%{name: "foo.jpeg", content: String.duplicate("0", 100)}]) # %Upload{}
      assert render_upload(avatar, "foo.jpeg") =~ "100%"
    end

    @tag allow: [max_entries: 3, chunk_size: 20, accept: :any]
    test "render_upload uploads specified chunk percentage", %{lv: lv} do
      avatar = file_input(lv, "input[name='avatar[]']", [%{name: "foo.jpeg", content: String.duplicate("0", 100)}]) # %Upload{}
      assert render_upload(avatar, "foo.jpeg", 20) =~ "foo.jpeg:20%"
      assert render_upload(avatar, "foo.jpeg", 25) =~ "foo.jpeg:45%"
    end

    @tag allow: [max_entries: 3, chunk_size: 20, accept: :any]
    test "render_upload with unknown entry", %{lv: lv} do
      avatar = file_input(lv, "input[name='avatar[]']", [%{name: "foo.jpeg", content: String.duplicate("0", 100)}]) # %Upload{}
      Process.unlink(proxy_pid(lv))
      Process.unlink(avatar.pid)
      try do
        render_upload(avatar, "unknown.jpeg")
      catch
        :exit, {{%RuntimeError{message: msg}, _}, _} ->
          assert msg =~ "no file input with name \"unknown.jpeg\""
      end
    end
  end
end
