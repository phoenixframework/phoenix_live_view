defmodule Phoenix.LiveView.UploadChannelTest do
  use ExUnit.Case, async: false
  require Phoenix.ChannelTest

  import Phoenix.LiveViewTest

  alias Phoenix.{Component, LiveView}
  alias Phoenix.LiveViewTest.UploadClient
  alias Phoenix.LiveViewTest.Support.{UploadLive, NestedUploadLive, UploadLiveWithComponent}

  @endpoint Phoenix.LiveViewTest.Support.Endpoint

  defmodule TestWriter do
    @behaviour Phoenix.LiveView.UploadWriter

    @impl true
    def init(test_name) do
      send(test_name, :init)
      {:ok, test_name}
    end

    @impl true
    def meta(test_name) do
      send(test_name, :meta)
      test_name
    end

    @impl true
    def write_chunk("error", test_name) do
      {:error, :custom_error, test_name}
    end

    def write_chunk(data, test_name) do
      send(test_name, {:write_chunk, data})
      {:ok, test_name}
    end

    @impl true
    def close(test_name, reason) do
      send(test_name, {:close, reason})
      {:ok, test_name}
    end
  end

  def build_writer(_name, %Phoenix.LiveView.UploadEntry{}, %Phoenix.LiveView.Socket{}) do
    {TestWriter, :test_writer}
  end

  def valid_token(lv_pid, ref) do
    LiveView.Static.sign_token(@endpoint, %{pid: lv_pid, ref: ref})
  end

  def mount_lv(setup) when is_function(setup, 1) do
    conn = Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), %{})
    {:ok, lv, _} = live_isolated(conn, UploadLive, session: %{})
    :ok = GenServer.call(lv.pid, {:setup, setup})
    {:ok, lv}
  end

  def mount_nested_lv(setup) when is_function(setup, 1) do
    conn = Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), %{})
    {:ok, lv, _} = live_isolated(conn, NestedUploadLive, session: %{})
    nested_lv = find_live_child(lv, "upload")
    :ok = GenServer.call(nested_lv.pid, {:setup, setup})
    {:ok, nested_lv}
  end

  def mount_lv_with_component(setup) when is_function(setup, 1) do
    conn = Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), %{})
    {:ok, lv, _} = live_isolated(conn, UploadLiveWithComponent, session: %{})
    :ok = GenServer.call(lv.pid, {:run, setup})
    {:ok, lv}
  end

  def get_uploaded_entries(lv, name) do
    UploadLive.run(lv, fn socket ->
      {:reply, Phoenix.LiveView.uploaded_entries(socket, name), socket}
    end)
  end

  def build_entries(count, opts \\ []) do
    content = String.duplicate("0", 100)
    size = byte_size(content)

    for i <- 1..count do
      Enum.into(opts, %{
        last_modified: 1_594_171_879_000,
        name: "myfile#{i}.jpeg",
        relative_path: "./myfile#{i}.jpeg",
        content: content,
        size: size,
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
    Process.unlink(UploadLive.proxy_pid(lv))
    Process.unlink(lv.pid)
    Process.unlink(channel_pid)
  end

  def consume(%LiveView.UploadEntry{} = entry, socket) do
    socket =
      cond do
        entry.client_name == "redirect.jpeg" ->
          Phoenix.LiveView.push_navigate(socket, to: "/redirected")

        entry.client_name == "consume-and-redirect.jpeg" and entry.done? ->
          _ =
            Phoenix.LiveView.consume_uploaded_entry(socket, entry, fn _ ->
              {:ok, entry.client_name}
            end)

          Phoenix.LiveView.push_navigate(socket, to: "/redirected")

        entry.done? ->
          name =
            Phoenix.LiveView.consume_uploaded_entry(socket, entry, fn _ ->
              {:ok, entry.client_name}
            end)

          Phoenix.Component.update(socket, :consumed, fn consumed -> [name] ++ consumed end)

        true ->
          socket
      end

    {:noreply, socket}
  end

  setup_all do
    start_supervised!(Phoenix.PubSub.child_spec(name: Phoenix.LiveView.PubSub))
    :ok
  end

  test "rejects invalid token" do
    {:ok, socket} = Phoenix.ChannelTest.connect(Phoenix.LiveView.Socket, %{})

    assert {:error, %{reason: :invalid_token}} =
             Phoenix.ChannelTest.subscribe_and_join(socket, "lvu:123", %{"token" => "bad"})
  end

  defp setup_lv(%{allow: opts}) do
    opts = opts_for_allow_upload(opts)
    {:ok, lv} = mount_lv(fn socket -> Phoenix.LiveView.allow_upload(socket, :avatar, opts) end)
    {:ok, lv: lv}
  end

  defp setup_nested_lv(%{allow: opts}) do
    opts = opts_for_allow_upload(opts)

    {:ok, lv} =
      mount_nested_lv(fn socket -> Phoenix.LiveView.allow_upload(socket, :avatar, opts) end)

    {:ok, lv: lv}
  end

  defp setup_component(%{allow: opts}) do
    opts = opts_for_allow_upload(opts)

    {:ok, lv} =
      mount_lv_with_component(fn component_socket ->
        new_socket = Phoenix.LiveView.allow_upload(component_socket, :avatar, opts)
        {:reply, :ok, new_socket}
      end)

    {:ok, lv: lv}
  end

  defp opts_for_allow_upload(opts) do
    case Keyword.fetch(opts, :progress) do
      {:ok, progress} ->
        Keyword.put(opts, :progress, fn _, entry, socket ->
          apply(__MODULE__, progress, [entry, socket])
        end)

      :error ->
        opts
    end
  end

  for context <- [:lv, :nested_lv, :component] do
    @context context

    describe "#{@context} with valid token" do
      setup :"setup_#{@context}"

      @tag allow: [accept: :any]
      test "upload channel exits when LiveView channel exits", %{lv: lv} do
        avatar = file_input(lv, "form", :avatar, build_entries(1))
        assert render_upload(avatar, "myfile1.jpeg", 1) =~ "#{@context}:myfile1.jpeg:1%"
        assert %{"myfile1.jpeg" => channel_pid} = UploadClient.channel_pids(avatar)

        unlink(channel_pid, lv, avatar)
        Process.monitor(channel_pid)
        Process.exit(lv.pid, :kill)
        assert_receive {:DOWN, _ref, :process, ^channel_pid, :killed}
      end

      @tag allow: [accept: :any]
      test "abnormal channel exit brings down LiveView", %{lv: lv} do
        avatar = file_input(lv, "form", :avatar, build_entries(1))
        assert render_upload(avatar, "myfile1.jpeg", 1) =~ "#{@context}:myfile1.jpeg:1%"
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
        assert render_upload(avatar, "myfile1.jpeg", 1) =~ "#{@context}:myfile1.jpeg:1%"
        assert %{"myfile1.jpeg" => channel_pid} = UploadClient.channel_pids(avatar)

        lv_pid = lv.pid
        unlink(channel_pid, lv)
        Process.monitor(lv_pid)

        assert render(lv) =~ "channel:#{UploadLive.inspect_html_safe(channel_pid)}"
        GenServer.stop(channel_pid, :normal)
        refute_receive {:DOWN, _ref, :process, ^lv_pid, _}
        refute render(lv) =~ "channel:"
      end

      @tag allow: [accept: :any, max_file_size: 100]
      test "upload channel exits when client sends more bytes than allowed", %{lv: lv} do
        avatar =
          file_input(lv, "form", :avatar, [
            %{name: "foo.jpeg", content: String.duplicate("0", 100)}
          ])

        assert render_upload(avatar, "foo.jpeg", 1) =~ "#{@context}:foo.jpeg:1%"
        assert %{"foo.jpeg" => channel_pid} = UploadClient.channel_pids(avatar)

        unlink(channel_pid, lv)
        Process.monitor(channel_pid)

        assert UploadClient.simulate_attacker_chunk(
                 avatar,
                 "foo.jpeg",
                 String.duplicate("0", 1000)
               ) ==
                 {:error, %{limit: 100, reason: :file_size_limit_exceeded}}

        assert_receive {:DOWN, _ref, :process, ^channel_pid, {:shutdown, :closed}}, 1000
      end

      @tag allow: [accept: :any, max_file_size: 100, chunk_timeout: 500]
      test "upload channel exits when client does not send chunk after timeout", %{lv: lv} do
        avatar =
          file_input(lv, "form", :avatar, [
            %{name: "foo.jpeg", content: String.duplicate("0", 100)}
          ])

        assert render_upload(avatar, "foo.jpeg", 1) =~ "#{@context}:foo.jpeg:1%"
        assert %{"foo.jpeg" => channel_pid} = UploadClient.channel_pids(avatar)

        unlink(channel_pid, lv)
        Process.monitor(channel_pid)

        assert_receive {:DOWN, _ref, :process, ^channel_pid, {:shutdown, :closed}}, 1000
      end

      @tag allow: [max_entries: 3, accept: :any]
      test "multiple entries under max", %{lv: lv} do
        avatar = file_input(lv, "form", :avatar, build_entries(2))
        assert render_upload(avatar, "myfile1.jpeg", 1) =~ "#{@context}:myfile1.jpeg:1%"
        assert render_upload(avatar, "myfile2.jpeg", 2) =~ "#{@context}:myfile2.jpeg:2%"

        assert %{"myfile1.jpeg" => chan1_pid, "myfile2.jpeg" => chan2_pid} =
                 UploadClient.channel_pids(avatar)

        assert render(lv) =~ "channel:#{UploadLive.inspect_html_safe(chan1_pid)}"
        assert render(lv) =~ "channel:#{UploadLive.inspect_html_safe(chan2_pid)}"
      end

      @tag allow: [max_entries: 1, accept: :any]
      test "too many entries over max", %{lv: lv} do
        avatar = file_input(lv, "form", :avatar, build_entries(2))

        assert lv
               |> form("form", user: %{})
               |> render_change(avatar) =~ "config_error::too_many_files"

        assert {:error, [[_ref, :too_many_files]]} = render_upload(avatar, "myfile1.jpeg", 1)
      end

      @tag allow: [accept: :any]
      test "registering returns too_many_files on back-to-back entries", %{lv: lv} do
        avatar = file_input(lv, "form", :avatar, build_entries(1))
        assert render_upload(avatar, "myfile1.jpeg", 1) =~ "#{@context}:myfile1.jpeg:1%"
        dup_avatar = file_input(lv, "form", :avatar, build_entries(1))
        assert {:error, [[_, :too_many_files]]} = preflight_upload(dup_avatar)
      end

      @tag allow: [max_entries: 3, accept: :any]
      test "preflight_upload", %{lv: lv} do
        avatar = file_input(lv, "form", :avatar, build_entries(1))
        assert {:ok, %{ref: _ref, config: %{chunk_size: _}}} = preflight_upload(avatar)
      end

      @tag allow: [max_entries: 3, accept: :any]
      test "preflighting an already in progress entry is ignored", %{lv: lv} do
        avatar = file_input(lv, "form", :avatar, build_entries(1))
        assert render_upload(avatar, "myfile1.jpeg", 1) =~ "1%"
        assert %{"myfile1.jpeg" => channel_pid} = UploadClient.channel_pids(avatar)
        assert render(lv) =~ "channel:#{UploadLive.inspect_html_safe(channel_pid)}"

        assert {:ok, _} = preflight_upload(avatar)
        assert %{"myfile1.jpeg" => ^channel_pid} = UploadClient.channel_pids(avatar)
      end

      @tag allow: [max_entries: 3, chunk_size: 20, accept: :any]
      test "render_upload uploads entire file by default", %{lv: lv} do
        avatar =
          file_input(lv, "form", :avatar, [
            %{name: "foo.jpeg", content: String.duplicate("0", 100)}
          ])

        assert render_upload(avatar, "foo.jpeg") =~ "100%"
      end

      @tag allow: [max_entries: 3, chunk_size: 20, accept: :any]
      test "render_upload uploads specified chunk percentage", %{lv: lv} do
        avatar =
          file_input(lv, "form", :avatar, [
            %{name: "foo.jpeg", content: String.duplicate("0", 100)}
          ])

        assert render_upload(avatar, "foo.jpeg", 20) =~ "#{@context}:foo.jpeg:20%"
        assert render_upload(avatar, "foo.jpeg", 25) =~ "#{@context}:foo.jpeg:45%"
      end

      @tag allow: [max_entries: 3, chunk_size: 20, accept: :any, progress: :consume]
      test "render_upload uploads with progress callback", %{lv: lv} do
        avatar =
          file_input(lv, "form", :avatar, [
            %{name: "foo.jpeg", content: String.duplicate("0", 100)}
          ])

        assert render_upload(avatar, "foo.jpeg") =~ "consumed:foo.jpeg"
      end

      @tag allow: [max_entries: 3, chunk_size: 20, accept: :any, progress: :consume]
      test "render_upload uploads with progress redirect", %{lv: lv} do
        avatar =
          file_input(lv, "form", :avatar, [
            %{name: "redirect.jpeg", content: String.duplicate("0", 100)}
          ])

        assert {:error, {:live_redirect, redir}} = render_upload(avatar, "redirect.jpeg")
        assert redir[:to] == "/redirected"
      end

      @tag allow: [max_entries: 3, chunk_size: 20, accept: :any, progress: :consume]
      test "render_upload uploads with progress consume + redirect", %{lv: lv} do
        # this is similar to https://github.com/phoenixframework/phoenix_live_view/issues/3662
        avatar =
          file_input(lv, "form", :avatar, [
            %{name: "consume-and-redirect.jpeg", content: String.duplicate("0", 100)}
          ])

        assert {:error, {:live_redirect, redir}} =
                 render_upload(avatar, "consume-and-redirect.jpeg")

        assert redir[:to] == "/redirected"
      end

      @tag allow: [max_entries: 3, chunk_size: 20, accept: :any]
      test "render_upload with unknown entry", %{lv: lv} do
        avatar =
          file_input(lv, "form", :avatar, [
            %{name: "foo.jpeg", content: String.duplicate("0", 100)}
          ])

        assert UploadLive.exits_with(lv, avatar, RuntimeError, fn ->
                 render_upload(avatar, "unknown.jpeg")
               end) =~ "no file input with name \"unknown.jpeg\""
      end

      @tag allow: [max_entries: 1, chunk_size: 20, accept: :any, max_file_size: 1]
      test "render_change error with upload", %{lv: lv} do
        avatar = file_input(lv, "form", :avatar, [%{name: "foo.jpeg", content: "overmax"}])

        assert lv
               |> form("form", user: %{})
               |> render_change(avatar) =~ "entry_error::too_large"

        assert {:error, [[_ref, :too_large]]} = render_upload(avatar, "foo.jpeg")
      end

      @tag allow: [max_entries: 1, chunk_size: 20, accept: :any, auto_upload: true]
      test "render_upload too many files with auto_upload", %{lv: lv} do
        avatar =
          file_input(lv, "form", :avatar, [
            %{name: "foo1.jpeg", content: "bytes"},
            %{name: "foo2.jpeg", content: "bytes"}
          ])

        html =
          lv
          |> form("form", user: %{})
          |> render_change(avatar)

        assert html =~ "config_error::too_many_files"
        assert html =~ "foo1.jpeg:0%"
        assert html =~ "foo2.jpeg:0%"

        assert render_upload(avatar, "foo1.jpeg") =~ "foo1.jpeg:100%"
        assert {:error, :not_allowed} = render_upload(avatar, "foo2.jpeg")
      end

      @tag allow: [
             max_entries: 1,
             chunk_size: 20,
             accept: :any,
             max_file_size: 1,
             auto_upload: true
           ]
      test "render_upload invalid with auto_upload", %{lv: lv} do
        avatar = file_input(lv, "form", :avatar, [%{name: "foo.jpeg", content: "overmax"}])

        html =
          lv
          |> form("form", user: %{})
          |> render_change(avatar)

        assert html =~ "entry_error::too_large"
        assert html =~ "foo.jpeg:0%"

        assert {:error, [[_ref, :too_large]]} = render_upload(avatar, "foo.jpeg")
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
          file_input(lv, "form", :avatar, [
            %{name: "foo.jpeg", content: String.duplicate("0", 100)}
          ])

        assert get_uploaded_entries(lv, :avatar) == {[], []}
        assert render_upload(avatar, "foo.jpeg", 1) =~ "1%"

        assert {[], [%Phoenix.LiveView.UploadEntry{progress: 1}]} =
                 get_uploaded_entries(lv, :avatar)

        assert render_upload(avatar, "foo.jpeg", 99) =~ "100%"

        assert {[%Phoenix.LiveView.UploadEntry{progress: 100}], []} =
                 get_uploaded_entries(lv, :avatar)
      end

      @tag allow: [max_entries: 1, chunk_size: 20, accept: :any]
      test "consume_uploaded_entries executes function against all entries and shuts down",
           %{lv: lv} do
        parent = self()
        avatar = file_input(lv, "form", :avatar, [%{name: "foo.jpeg", content: "123"}])
        avatar_pid = avatar.pid
        assert render_upload(avatar, "foo.jpeg") =~ "100%"
        assert %{"foo.jpeg" => channel_pid} = UploadClient.channel_pids(avatar)

        Process.monitor(avatar_pid)
        Process.monitor(channel_pid)

        UploadLive.run(lv, fn socket ->
          Phoenix.LiveView.consume_uploaded_entries(socket, :avatar, fn %{path: path}, entry ->
            {:ok, send(parent, {:file, path, entry.client_name, File.read!(path)})}
          end)

          {:reply, :ok, socket}
        end)

        # Wait for the UploadClient and UploadChannel to shutdown
        assert_receive {:DOWN, _ref, :process, ^avatar_pid, {:shutdown, :closed}}, 1000
        assert_receive {:DOWN, _ref, :process, ^channel_pid, {:shutdown, :closed}}, 1000
        assert_receive {:file, _tmp_path, "foo.jpeg", "123"}
      end

      @tag allow: [max_entries: 1, chunk_size: 20, accept: :any]
      test "consume_uploaded_entry executes function and shuts down", %{
        lv: lv
      } do
        parent = self()
        avatar = file_input(lv, "form", :avatar, [%{name: "foo.jpeg", content: "123"}])
        avatar_pid = avatar.pid
        assert render_upload(avatar, "foo.jpeg") =~ "100%"
        Process.monitor(avatar_pid)

        UploadLive.run(lv, fn socket ->
          {[entry], []} = Phoenix.LiveView.uploaded_entries(socket, :avatar)

          Phoenix.LiveView.consume_uploaded_entry(socket, entry, fn %{path: path} ->
            {:ok, send(parent, {:file, path, entry.client_name, File.read!(path)})}
          end)

          {:reply, :ok, socket}
        end)

        assert_receive {:DOWN, _ref, :process, ^avatar_pid, {:shutdown, :closed}}, 1000
        assert_receive {:file, _tmp_path, "foo.jpeg", "123"}
      end

      @tag allow: [max_entries: 1, chunk_size: 20, accept: :any]
      test "consume_uploaded_entries returns empty list when no uploads exist", %{lv: lv} do
        parent = self()

        UploadLive.run(lv, fn socket ->
          result =
            Phoenix.LiveView.consume_uploaded_entries(socket, :avatar, fn _file, _entry ->
              :boom
            end)

          send(parent, {:consumed, result})
          {:reply, :ok, socket}
        end)

        assert_receive {:consumed, []}
      end

      @tag allow: [max_entries: 1, chunk_size: 20, accept: :any]
      test "consume_uploaded_entries raises when upload is still in progress", %{lv: lv} do
        avatar =
          file_input(lv, "form", :avatar, [
            %{name: "foo.jpeg", content: String.duplicate("0", 100)}
          ])

        assert render_upload(avatar, "foo.jpeg", 1) =~ "1%"

        try do
          UploadLive.run(lv, fn socket ->
            Phoenix.LiveView.consume_uploaded_entries(socket, :avatar, fn _file, _entry ->
              :boom
            end)
          end)
        catch
          :exit, {{%ArgumentError{message: msg}, _}, _} ->
            assert msg =~ "cannot consume uploaded files when entries are still in progress"
        end
      end

      @tag allow: [max_entries: 1, chunk_size: 20, accept: :any]
      test "consume_uploaded_entry raises when upload is still in progress", %{lv: lv} do
        avatar =
          file_input(lv, "form", :avatar, [
            %{name: "foo.jpeg", content: String.duplicate("0", 100)}
          ])

        assert render_upload(avatar, "foo.jpeg", 1) =~ "1%"

        try do
          UploadLive.run(lv, fn socket ->
            {[], [in_progress_entry]} = Phoenix.LiveView.uploaded_entries(socket, :avatar)

            Phoenix.LiveView.consume_uploaded_entry(socket, in_progress_entry, fn _file ->
              :boom
            end)
          end)
        catch
          :exit, {{%ArgumentError{message: msg}, _}, _} ->
            assert msg =~ "cannot consume uploaded files when entries are still in progress"
        end
      end

      @tag allow: [max_entries: 1, chunk_size: 20, accept: :any]
      test "consume_uploaded_entries can postpone consumption",
           %{lv: lv} do
        parent = self()
        avatar = file_input(lv, "form", :avatar, [%{name: "foo.jpeg", content: "123"}])
        avatar_pid = avatar.pid
        assert render_upload(avatar, "foo.jpeg") =~ "100%"
        assert %{"foo.jpeg" => channel_pid} = UploadClient.channel_pids(avatar)

        Process.monitor(avatar_pid)
        Process.monitor(channel_pid)

        UploadLive.run(lv, fn socket ->
          results =
            Phoenix.LiveView.consume_uploaded_entries(socket, :avatar, fn %{path: path}, entry ->
              send(parent, {:file, path, entry.client_name, File.read!(path)})
              {:postpone, {:postponed, path}}
            end)

          send(parent, {:results, results})
          {:reply, :ok, socket}
        end)

        assert_receive {:results, [{:postponed, tmp_path}]}
        assert_receive {:file, ^tmp_path, "foo.jpeg", "123"}
        refute_receive {:DOWN, _ref, :process, ^avatar_pid, _}
        refute_receive {:DOWN, _ref, :process, ^channel_pid, _}
        assert File.exists?(tmp_path)

        UploadLive.run(lv, fn socket ->
          results =
            Phoenix.LiveView.consume_uploaded_entries(socket, :avatar, fn %{path: path}, entry ->
              send(parent, {:file, path, entry.client_name, File.read!(path)})
              {:ok, {:consumed, path}}
            end)

          send(parent, {:results, results})
          {:reply, :ok, socket}
        end)

        assert_receive {:results, [{:consumed, tmp_path}]}
        assert_receive {:file, ^tmp_path, "foo.jpeg", "123"}
        assert_receive {:DOWN, _ref, :process, ^avatar_pid, {:shutdown, :closed}}, 1000
        assert_receive {:DOWN, _ref, :process, ^channel_pid, {:shutdown, :closed}}, 1000
      end

      @tag allow: [max_entries: 1, chunk_size: 20, accept: :any]
      test "consume_uploaded_entry can postpone consumption",
           %{lv: lv} do
        parent = self()
        avatar = file_input(lv, "form", :avatar, [%{name: "foo.jpeg", content: "123"}])
        avatar_pid = avatar.pid
        assert render_upload(avatar, "foo.jpeg") =~ "100%"
        assert %{"foo.jpeg" => channel_pid} = UploadClient.channel_pids(avatar)

        Process.monitor(avatar_pid)
        Process.monitor(channel_pid)

        UploadLive.run(lv, fn socket ->
          {[entry], []} = Phoenix.LiveView.uploaded_entries(socket, :avatar)

          result =
            Phoenix.LiveView.consume_uploaded_entry(socket, entry, fn %{path: path} ->
              send(parent, {:file, path, entry.client_name, File.read!(path)})
              {:postpone, {:postponed, path}}
            end)

          send(parent, {:result, result})
          {:reply, :ok, socket}
        end)

        assert_receive {:result, {:postponed, tmp_path}}
        assert_receive {:file, ^tmp_path, "foo.jpeg", "123"}
        refute_receive {:DOWN, _ref, :process, ^avatar_pid, _}
        refute_receive {:DOWN, _ref, :process, ^channel_pid, _}
        assert File.exists?(tmp_path)

        UploadLive.run(lv, fn socket ->
          {[entry], []} = Phoenix.LiveView.uploaded_entries(socket, :avatar)

          result =
            Phoenix.LiveView.consume_uploaded_entry(socket, entry, fn %{path: path} ->
              send(parent, {:file, path, entry.client_name, File.read!(path)})
              {:ok, {:consumed, path}}
            end)

          send(parent, {:result, result})
          {:reply, :ok, socket}
        end)

        assert_receive {:result, {:consumed, tmp_path}}
        assert_receive {:file, ^tmp_path, "foo.jpeg", "123"}
        assert_receive {:DOWN, _ref, :process, ^avatar_pid, {:shutdown, :closed}}, 1000
        assert_receive {:DOWN, _ref, :process, ^channel_pid, {:shutdown, :closed}}, 1000
      end

      @tag allow: [max_entries: 1, accept: :any]
      test "cancel_upload with invalid ref", %{lv: lv} do
        avatar =
          file_input(lv, "form", :avatar, [
            %{name: "foo.jpeg", content: String.duplicate("0", 100)}
          ])

        assert UploadLive.exits_with(lv, avatar, ArgumentError, fn ->
                 UploadLive.run(lv, fn socket ->
                   {:reply, :ok, Phoenix.LiveView.cancel_upload(socket, :avatar, "bad_ref")}
                 end)
               end) =~ "no entry in upload \":avatar\" with ref \"bad_ref\""
      end

      @tag allow: [max_entries: 1, chunk_size: 20, accept: :any]
      test "cancel_upload in progress", %{lv: lv} do
        avatar =
          file_input(lv, "form", :avatar, [
            %{name: "foo.jpeg", content: String.duplicate("0", 100)}
          ])

        assert render_upload(avatar, "foo.jpeg", 1) =~ "1%"
        assert %{"foo.jpeg" => channel_pid} = UploadClient.channel_pids(avatar)

        unlink(channel_pid, lv, avatar)
        Process.monitor(channel_pid)

        UploadLive.run(lv, fn socket ->
          {[], [%{ref: ref}]} = Phoenix.LiveView.uploaded_entries(socket, :avatar)
          {:reply, :ok, Phoenix.LiveView.cancel_upload(socket, :avatar, ref)}
        end)

        assert_receive {:DOWN, _ref, :process, ^channel_pid, {:shutdown, :closed}}, 1000

        assert UploadLive.run(lv, fn socket ->
                 {:reply, Phoenix.LiveView.uploaded_entries(socket, :avatar), socket}
               end) == {[], []}
      end

      @tag allow: [max_entries: 1, chunk_size: 20, accept: :any]
      test "cancel_upload not yet in progress", %{lv: lv} do
        file_name = "foo.jpeg"
        avatar = file_input(lv, "form", :avatar, [%{name: file_name, content: "ok"}])

        assert lv
               |> form("form", user: %{})
               |> render_change(avatar) =~ file_name

        assert UploadClient.channel_pids(avatar) == %{}

        assert {[], [%{ref: ref}]} =
                 UploadLive.run(lv, fn socket ->
                   {:reply, Phoenix.LiveView.uploaded_entries(socket, :avatar), socket}
                 end)

        UploadLive.run(lv, fn socket ->
          {:reply, :ok, Phoenix.LiveView.cancel_upload(socket, :avatar, ref)}
        end)

        refute render(lv) =~ file_name
      end

      @tag allow: [max_entries: 1, chunk_size: 20, accept: :any]
      test "allow_upload with active entries", %{lv: lv} do
        avatar =
          file_input(lv, "form", :avatar, [
            %{name: "foo.jpeg", content: String.duplicate("0", 100)}
          ])

        assert render_upload(avatar, "foo.jpeg", 1) =~ "1%"

        assert UploadLive.exits_with(lv, avatar, ArgumentError, fn ->
                 UploadLive.run(lv, fn socket ->
                   {:reply, :ok, Phoenix.LiveView.allow_upload(socket, :avatar, accept: :any)}
                 end)
               end) =~ "cannot allow_upload on an existing upload with active entries"
      end

      @tag allow: [
             max_entries: 1,
             chunk_size: 50,
             accept: :any,
             writer: &__MODULE__.build_writer/3
           ]
      test "writer can be configured", %{lv: lv} do
        Process.register(self(), :test_writer)

        content = String.duplicate("0", 100)

        avatar =
          file_input(lv, "form", :avatar, [
            %{name: "foo.jpeg", content: content}
          ])

        assert render_upload(avatar, "foo.jpeg", 50) =~ "#{@context}:foo.jpeg:50%"
        assert render_upload(avatar, "foo.jpeg", 50) =~ "#{@context}:foo.jpeg:100%"

        metas =
          UploadLive.run(lv, fn socket ->
            results =
              Phoenix.LiveView.consume_uploaded_entries(socket, :avatar, fn meta, _entry ->
                {:ok, meta}
              end)

            {:reply, results, socket}
          end)

        assert metas == [:test_writer]
        assert_receive :init
        assert_receive :meta
        assert_receive {:write_chunk, chunk1}
        assert_receive {:write_chunk, chunk2}
        refute_receive {:write_chunk, _}
        assert chunk1 <> chunk2 == content
        assert_receive {:close, :done}
      end

      @tag allow: [
             max_entries: 1,
             chunk_size: 50,
             accept: :any,
             writer: &__MODULE__.build_writer/3
           ]
      test "writer with LiveView exit", %{lv: lv} do
        Process.register(self(), :test_writer)

        content = String.duplicate("0", 100)

        avatar =
          file_input(lv, "form", :avatar, [
            %{name: "foo.jpeg", content: content}
          ])

        assert render_upload(avatar, "foo.jpeg", 50) =~ "#{@context}:foo.jpeg:50%"

        assert %{"foo.jpeg" => channel_pid} = UploadClient.channel_pids(avatar)

        unlink(channel_pid, lv, avatar)
        Process.monitor(channel_pid)
        Process.exit(lv.pid, :kill)

        assert_receive {:write_chunk, _chunk1}
        refute_receive {:write_chunk, _}
        assert_receive {:close, :cancel}
      end

      @tag allow: [
             max_entries: 1,
             chunk_size: 50,
             accept: :any,
             writer: &__MODULE__.build_writer/3
           ]
      test "writer with error", %{lv: lv} do
        Process.register(self(), :test_writer)

        content = "error"

        avatar =
          file_input(lv, "form", :avatar, [
            %{name: "foo.jpeg", content: content}
          ])

        assert render_upload(avatar, "foo.jpeg") =~
                 ~s/entry_error:{:writer_failure, :custom_error}/

        assert_receive {:close, {:error, :custom_error}}
      end
    end
  end

  describe "component uploads" do
    setup :setup_component

    @tag allow: [accept: :any]
    test "liveview exits when duplicate name registered for another cid", %{lv: lv} do
      avatar = file_input(lv, "#upload0", :avatar, build_entries(1))
      assert render_upload(avatar, "myfile1.jpeg", 1) =~ "component:myfile1.jpeg:1%"

      GenServer.call(
        lv.pid,
        {:setup, fn socket -> Component.assign(socket, uploads_count: 2) end}
      )

      GenServer.call(
        lv.pid,
        {:setup,
         fn socket ->
           run = fn component_socket ->
             new_socket = LiveView.allow_upload(component_socket, :avatar, accept: :any)
             {:reply, :ok, new_socket}
           end

           LiveView.send_update(Phoenix.LiveViewTest.Support.UploadComponent,
             id: "upload1",
             run: {run, nil}
           )

           socket
         end}
      )

      dup_avatar = file_input(lv, "#upload1", :avatar, build_entries(1))

      assert UploadLive.exits_with(lv, dup_avatar, RuntimeError, fn ->
               render_upload(dup_avatar, "myfile1.jpeg", 1)
             end) =~ "existing upload for avatar already allowed in another component"

      refute Process.alive?(lv.pid)
    end

    @tag allow: [max_entries: 1, chunk_size: 20, accept: :any]
    test "cancel_upload in progress when component is removed", %{lv: lv} do
      avatar = file_input(lv, "#upload0", :avatar, build_entries(1))
      assert render_upload(avatar, "myfile1.jpeg", 1) =~ "component:myfile1.jpeg:1%"
      assert %{"myfile1.jpeg" => channel_pid} = UploadClient.channel_pids(avatar)

      unlink(channel_pid, lv, avatar)
      Process.monitor(channel_pid)

      assert render(lv) =~ "myfile1.jpeg"
      GenServer.call(lv.pid, {:uploads, 0})

      refute render(lv) =~ "myfile1.jpeg"

      assert_receive {:DOWN, _ref, :process, ^channel_pid, {:shutdown, :closed}}, 1000

      # retry with new component
      GenServer.call(lv.pid, {:uploads, 1})

      UploadLive.run(lv, fn component_socket ->
        new_socket = Phoenix.LiveView.allow_upload(component_socket, :avatar, accept: :any)
        {:reply, :ok, new_socket}
      end)

      avatar = file_input(lv, "#upload0", :avatar, build_entries(1))
      assert render_upload(avatar, "myfile1.jpeg", 100) =~ "component:myfile1.jpeg:100%"
    end

    @tag allow: [max_entries: 1, chunk_size: 20, accept: :any]
    test "cancel_upload not yet in progress when component is removed", %{lv: lv} do
      file_name = "myfile1.jpeg"
      avatar = file_input(lv, "#upload0", :avatar, [%{name: file_name, content: "ok"}])

      assert lv
             |> form("form", user: %{})
             |> render_change(avatar) =~ file_name

      assert UploadClient.channel_pids(avatar) == %{}

      assert render(lv) =~ file_name

      GenServer.call(lv.pid, {:uploads, 0})

      refute render(lv) =~ file_name

      # retry with new component
      GenServer.call(lv.pid, {:uploads, 1})

      UploadLive.run(lv, fn component_socket ->
        new_socket = Phoenix.LiveView.allow_upload(component_socket, :avatar, accept: :any)
        {:reply, :ok, new_socket}
      end)

      avatar = file_input(lv, "#upload0", :avatar, build_entries(1))
      assert render_upload(avatar, "myfile1.jpeg", 100) =~ "component:myfile1.jpeg:100%"
    end

    @tag allow: [accept: :any]
    test "get allowed uploads from the form's target cid", %{lv: lv} do
      GenServer.call(
        lv.pid,
        {:setup, fn socket -> Component.assign(socket, uploads_count: 2) end}
      )

      GenServer.call(
        lv.pid,
        {:setup,
         fn socket ->
           run = fn component_socket ->
             new_socket =
               component_socket
               |> Phoenix.LiveView.allow_upload(:avatar, accept: :any)
               |> Phoenix.LiveView.allow_upload(:background, accept: :any)

             {:reply, :ok, new_socket}
           end

           LiveView.send_update(Phoenix.LiveViewTest.Support.UploadComponent,
             id: "upload1",
             run: {run, nil}
           )

           socket
         end}
      )

      assert %Phoenix.LiveViewTest.Upload{} =
               file_input(lv, "#upload1", :background, build_entries(1))

      assert_raise RuntimeError, "no uploads allowed for background", fn ->
        file_input(lv, "#upload0", :background, build_entries(1))
      end
    end
  end
end
