defmodule Phoenix.LiveView.UploadChannelTest do
  use ExUnit.Case, async: true
  require Phoenix.ChannelTest

  import Phoenix.LiveViewTest

  alias Phoenix.LiveView
  alias Phoenix.LiveViewTest.UploadClient

  @endpoint Phoenix.LiveViewTest.Endpoint

  def inspect_html_safe(term) do
    term
    |> inspect()
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end

  def valid_token(lv_pid, ref) do
    LiveView.Static.sign_token(@endpoint, %{pid: lv_pid, ref: ref})
  end

  def run(lv, func) do
    GenServer.call(lv.pid, {:run, func})
  end

  def mount_lv(setup) when is_function(setup, 1) do
    conn = Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), %{})
    {:ok, lv, _} = live_isolated(conn, Phoenix.LiveViewTest.UploadLive, session: %{})
    :ok = GenServer.call(lv.pid, {:setup, setup})
    {:ok, lv}
  end

  def get_uploaded_entries(lv, name) do
    run(lv, fn socket -> {:reply, Phoenix.LiveView.uploaded_entries(socket, name), socket} end)
  end

  def build_entries(count, opts \\ []) do
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

  def unlink(
        channel_pid,
        %Phoenix.LiveViewTest.View{} = lv,
        %Phoenix.LiveViewTest.Upload{} = upload
      ) do
    Process.unlink(upload.pid)
    unlink(channel_pid, lv)
  end

  def unlink(channel_pid, %Phoenix.LiveViewTest.View{} = lv) do
    Process.flag(:trap_exit, true)
    Process.unlink(proxy_pid(lv))
    Process.unlink(lv.pid)
    Process.unlink(channel_pid)
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
      avatar = file_input(lv, "form", :avatar, build_entries(1))
      assert render_upload(avatar, "myfile1.jpeg", 1) =~ "myfile1.jpeg:1%"
      assert %{"myfile1.jpeg" => channel_pid} = UploadClient.channel_pids(avatar)

      unlink(channel_pid, lv, avatar)
      Process.monitor(channel_pid)
      Process.exit(lv.pid, :kill)
      assert_receive {:DOWN, _ref, :process, ^channel_pid, :killed}
    end

    @tag allow: [accept: :any]
    test "abnormal channel exit brings down LiveView", %{lv: lv} do
      avatar = file_input(lv, "form", :avatar, build_entries(1))
      assert render_upload(avatar, "myfile1.jpeg", 1) =~ "myfile1.jpeg:1%"
      assert %{"myfile1.jpeg" => channel_pid} = UploadClient.channel_pids(avatar)

      lv_pid = lv.pid
      unlink(channel_pid, lv, avatar)
      Process.monitor(lv_pid)
      Process.exit(channel_pid, :kill)

      assert_receive {:DOWN, _ref, :process, ^lv_pid,
                      {:shutdown, {:channel_upload_exit, :killed}}}
    end

    @tag allow: [accept: :any]
    test "normal channel exit is cleaned up by LiveView", %{lv: lv} do
      avatar = file_input(lv, "form", :avatar, build_entries(1))
      assert render_upload(avatar, "myfile1.jpeg", 1) =~ "myfile1.jpeg:1%"
      assert %{"myfile1.jpeg" => channel_pid} = UploadClient.channel_pids(avatar)

      lv_pid = lv.pid
      unlink(channel_pid, lv)
      Process.monitor(lv_pid)

      assert render(lv) =~ "channel:#{inspect_html_safe(channel_pid)}"
      GenServer.stop(channel_pid, :normal)
      refute_receive {:DOWN, _ref, :process, ^lv_pid, _}
      refute render(lv) =~ "channel:"
    end

    @tag allow: [accept: :any, max_file_size: 100]
    test "upload channel exits when client sends more bytes than allowed", %{lv: lv} do
      avatar =
        file_input(lv, "form", :avatar, [%{name: "foo.jpeg", content: String.duplicate("0", 100)}])

      assert render_upload(avatar, "foo.jpeg", 1) =~ "foo.jpeg:1%"
      assert %{"foo.jpeg" => channel_pid} = UploadClient.channel_pids(avatar)

      unlink(channel_pid, lv)
      Process.monitor(channel_pid)

      assert UploadClient.simulate_attacker_chunk(avatar, "foo.jpeg", String.duplicate("0", 1000)) ==
               {:error, %{limit: 100, reason: "file_size_limit_exceeded"}}

      assert_receive {:DOWN, _ref, :process, ^channel_pid, {:shutdown, :closed}}
    end

    @tag allow: [accept: :any, max_file_size: 100, chunk_timeout: 500]
    test "upload channel exits when client does not send chunk after timeout", %{lv: lv} do
      avatar =
        file_input(lv, "form", :avatar, [%{name: "foo.jpeg", content: String.duplicate("0", 100)}])

      assert render_upload(avatar, "foo.jpeg", 1) =~ "foo.jpeg:1%"
      assert %{"foo.jpeg" => channel_pid} = UploadClient.channel_pids(avatar)

      unlink(channel_pid, lv)
      Process.monitor(channel_pid)

      assert_receive {:DOWN, _ref, :process, ^channel_pid, {:shutdown, :closed}}, 1000
    end

    @tag allow: [max_entries: 3, accept: :any]
    test "multiple entries under max", %{lv: lv} do
      avatar = file_input(lv, "form", :avatar, build_entries(2))
      assert render_upload(avatar, "myfile1.jpeg", 1) =~ "myfile1.jpeg:1%"
      assert render_upload(avatar, "myfile2.jpeg", 2) =~ "myfile2.jpeg:2%"

      assert %{"myfile1.jpeg" => chan1_pid, "myfile2.jpeg" => chan2_pid} =
               UploadClient.channel_pids(avatar)

      assert render(lv) =~ "channel:#{inspect_html_safe(chan1_pid)}"
      assert render(lv) =~ "channel:#{inspect_html_safe(chan2_pid)}"
    end

    @tag allow: [max_entries: 1, accept: :any]
    test "too many entries over max", %{lv: lv} do
      avatar = file_input(lv, "form", :avatar, build_entries(2))

      assert {:error, [%{"reason" => "too_many_files", "ref" => _}]} =
               render_upload(avatar, "myfile1.jpeg", 1)
    end

    @tag allow: [max_entries: 3, accept: :any]
    test "preflight_upload", %{lv: lv} do
      avatar = file_input(lv, "form", :avatar, build_entries(1))
      assert {:ok, %{ref: _ref, config: %{chunk_size: _}}} = preflight_upload(avatar)
    end

    @tag allow: [max_entries: 3, accept: :any]
    test "starting an already in progress entry is denied", %{lv: lv} do
      avatar = file_input(lv, "form", :avatar, build_entries(1))
      assert render_upload(avatar, "myfile1.jpeg", 1) =~ "1%"
      assert %{"myfile1.jpeg" => channel_pid} = UploadClient.channel_pids(avatar)
      assert render(lv) =~ "channel:#{inspect_html_safe(channel_pid)}"
      Process.unlink(proxy_pid(lv))
      Process.unlink(avatar.pid)

      try do
        preflight_upload(avatar)
      catch
        :exit, {{%ArgumentError{message: msg}, _}, _} ->
          assert msg =~ "cannot overwrite entries for an active upload"
      end
    end

    @tag allow: [max_entries: 3, chunk_size: 20, accept: :any]
    test "render_upload uploads entire file by default", %{lv: lv} do
      avatar =
        file_input(lv, "form", :avatar, [%{name: "foo.jpeg", content: String.duplicate("0", 100)}])

      assert render_upload(avatar, "foo.jpeg") =~ "100%"
    end

    @tag allow: [max_entries: 3, chunk_size: 20, accept: :any]
    test "render_upload uploads specified chunk percentage", %{lv: lv} do
      avatar =
        file_input(lv, "form", :avatar, [%{name: "foo.jpeg", content: String.duplicate("0", 100)}])

      assert render_upload(avatar, "foo.jpeg", 20) =~ "foo.jpeg:20%"
      assert render_upload(avatar, "foo.jpeg", 25) =~ "foo.jpeg:45%"
    end

    @tag allow: [max_entries: 3, chunk_size: 20, accept: :any]
    test "render_upload with unknown entry", %{lv: lv} do
      avatar =
        file_input(lv, "form", :avatar, [%{name: "foo.jpeg", content: String.duplicate("0", 100)}])

      Process.unlink(proxy_pid(lv))
      Process.unlink(avatar.pid)

      try do
        render_upload(avatar, "unknown.jpeg")
      catch
        :exit, {{%RuntimeError{message: msg}, _}, _} ->
          assert msg =~ "no file input with name \"unknown.jpeg\""
      end
    end

    @tag allow: [max_entries: 1, chunk_size: 20, accept: :any, max_file_size: 1]
    test "render_change error with upload", %{lv: lv} do
      avatar = file_input(lv, "form", :avatar, [%{name: "foo.jpeg", content: "overmax"}])

      assert lv
             |> form("form", user: %{})
             |> render_change(avatar) =~ "error:too_large"

      assert {:error, [%{"reason" => "too_large"}]} = render_upload(avatar, "foo.jpeg")
    end

    @tag allow: [max_entries: 1, chunk_size: 20, accept: :any]
    test "render_change success with upload", %{lv: lv} do
      avatar = file_input(lv, "form", :avatar, [%{name: "foo.jpeg", content: "ok"}])

      refute lv
             |> form("form", user: %{})
             |> render_change(avatar) =~ "error"

      assert render_upload(avatar, "foo.jpeg") =~ "100%"
    end

    @tag allow: [max_entries: 1, chunk_size: 20, accept: :any]
    test "get_uploaded_entries", %{lv: lv} do
      avatar =
        file_input(lv, "form", :avatar, [%{name: "foo.jpeg", content: String.duplicate("0", 100)}])

      assert get_uploaded_entries(lv, :avatar) == {[], []}
      assert render_upload(avatar, "foo.jpeg", 1) =~ "1%"

      assert {[], [%Phoenix.LiveView.UploadEntry{progress: 1}]} =
               get_uploaded_entries(lv, :avatar)

      assert render_upload(avatar, "foo.jpeg", 99) =~ "100%"

      assert {[%Phoenix.LiveView.UploadEntry{progress: 100}], []} =
               get_uploaded_entries(lv, :avatar)
    end

    @tag allow: [max_entries: 1, chunk_size: 20, accept: :any]
    test "consume_uploaded_entries executes function, cleans up tmp file, and shuts down", %{lv: lv} do
      Process.flag(:trap_exit, true)
      parent = self()
      avatar = file_input(lv, "form", :avatar, [%{name: "foo.jpeg", content: "123"}])
      avatar_pid = avatar.pid
      assert render_upload(avatar, "foo.jpeg") =~ "100%"
      Process.monitor(avatar_pid)

      run(lv, fn socket ->
        Phoenix.LiveView.consume_uploaded_entries(socket, :avatar, fn path, entry ->
          send(parent, {:file, path, entry.client_name, File.read!(path)})
        end)
        {:reply, :ok, socket}
      end)

      assert_receive {:DOWN, _ref, :process, ^avatar_pid, {:shutdown, :closed}}
      assert_receive {:file, tmp_path, "foo.jpeg", "123"}
      assert render(lv) # synchronize with LV to ensure it has processed DOWN
      refute File.exists?(tmp_path)
    end

    @tag allow: [max_entries: 1, chunk_size: 20, accept: :any]
    test "consume_uploaded_entries raises when upload does exist", %{lv: lv} do
      Process.flag(:trap_exit, true)
      try do
        run(lv, fn socket ->
          Phoenix.LiveView.consume_uploaded_entries(socket, :avatar, fn _file, _entry -> :boom end)
        end)
      catch
        :exit, {{%ArgumentError{message: msg}, _}, _} ->
          assert msg =~ "cannot move uploaded files without active entries"
      end
    end

    @tag allow: [max_entries: 1, chunk_size: 20, accept: :any]
    test "consume_uploaded_entries raises when upload is still in progress", %{lv: lv} do
      Process.flag(:trap_exit, true)
      avatar =
        file_input(lv, "form", :avatar, [%{name: "foo.jpeg", content: String.duplicate("0", 100)}])

      assert render_upload(avatar, "foo.jpeg", 1) =~ "1%"

      try do
        run(lv, fn socket ->
          Phoenix.LiveView.consume_uploaded_entries(socket, :avatar, fn _file, _entry -> :boom end)
        end)
      catch
        :exit, {{%ArgumentError{message: msg}, _}, _} ->
          assert msg =~ "cannot move uploaded files when entries are still in progress"
      end
    end
  end
end
