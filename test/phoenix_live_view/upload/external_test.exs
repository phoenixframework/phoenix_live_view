defmodule Phoenix.LiveView.UploadExternalTest do
  use ExUnit.Case, async: true

  @endpoint Phoenix.LiveViewTest.Endpoint

  import Phoenix.LiveViewTest

  alias Phoenix.LiveView
  alias Phoenix.LiveViewTest.UploadLive

  def inspect_html_safe(term) do
    term
    |> inspect()
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end

  def run(lv, func) do
    GenServer.call(lv.pid, {:run, func})
  end

  def mount_lv(setup) when is_function(setup, 1) do
    conn = Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), %{})
    {:ok, lv, _} = live_isolated(conn, UploadLive, session: %{})
    :ok = GenServer.call(lv.pid, {:setup, setup})
    {:ok, lv}
  end

  setup %{allow: opts} do
    external = Keyword.fetch!(opts, :external)

    opts =
      Keyword.put(opts, :external, fn entry, socket ->
        apply(__MODULE__, external, [entry, socket])
      end)

    opts =
      case Keyword.fetch(opts, :progress) do
        {:ok, progress} ->
          Keyword.put(opts, :progress, fn _, entry, socket ->
            apply(__MODULE__, progress, [entry, socket])
          end)

        :error ->
          opts
      end

    {:ok, lv} = mount_lv(fn socket -> Phoenix.LiveView.allow_upload(socket, :avatar, opts) end)

    {:ok, lv: lv}
  end

  def preflight(%LiveView.UploadEntry{} = entry, socket) do
    new_socket =
      Phoenix.LiveView.update(socket, :preflights, fn preflights ->
        [entry.client_name | preflights]
      end)

    {:ok, %{uploader: "S3"}, new_socket}
  end

  def consume(%LiveView.UploadEntry{} = entry, socket) do
    if entry.done? do
      Phoenix.LiveView.consume_uploaded_entry(socket, entry, fn _ -> :ok end)
    end

    {:noreply, socket}
  end

  @tag allow: [max_entries: 2, chunk_size: 20, accept: :any, external: :preflight]
  test "external upload invokes preflight per entry", %{lv: lv} do
    avatar =
      file_input(lv, "form", :avatar, [
        %{name: "foo1.jpeg", content: String.duplicate("ok", 100)},
        %{name: "foo2.jpeg", content: String.duplicate("ok", 100)}
      ])

    assert lv
           |> form("form", user: %{})
           |> render_change(avatar) =~ "foo1.jpeg:0%"

    assert render_upload(avatar, "foo1.jpeg", 1) =~ "foo1.jpeg:1%"
    assert render(lv) =~ "preflight:#{UploadLive.inspect_html_safe("foo1.jpeg")}"
    assert render(lv) =~ "preflight:#{UploadLive.inspect_html_safe("foo2.jpeg")}"
  end

  def bad_preflight(%LiveView.UploadEntry{} = _entry, socket), do: {:ok, %{}, socket}

  @tag allow: [max_entries: 1, chunk_size: 20, accept: :any, external: :bad_preflight]
  test "external preflight raises when missing required :uploader key", %{lv: lv} do
    avatar =
      file_input(lv, "form", :avatar, [%{name: "foo.jpeg", content: String.duplicate("ok", 100)}])

    assert UploadLive.exits_with(lv, avatar, ArgumentError, fn ->
      render_upload(avatar, "foo.jpeg", 1) =~ "foo.jpeg:1%"
    end) =~ "external uploader metadata requires an :uploader key."
  end

  def error_preflight(%LiveView.UploadEntry{} = entry, socket) do
    if entry.client_name == "bad.jpeg" do
      {:error, %{reason: "bad name"}, socket}
    else
      {:ok, %{uploader: "S3"}, socket}
    end
  end

  @tag allow: [max_entries: 2, chunk_size: 20, accept: :any, external: :error_preflight]
  test "preflight with error return", %{lv: lv} do
    avatar =
      file_input(lv, "form", :avatar, [
        %{name: "foo.jpeg", content: String.duplicate("ok", 100)},
        %{name: "bad.jpeg", content: String.duplicate("ok", 100)}
      ])

    assert {:error, [[ref, %{reason: "bad name"}]]} = render_upload(avatar, "bad.jpeg", 1)
    assert {:error, [[^ref, %{reason: "bad name"}]]} = render_upload(avatar, "foo.jpeg", 1)
    assert render(lv) =~ "bad name"
  end

  @tag allow: [max_entries: 2, chunk_size: 20, accept: :any, external: :preflight]
  test "consume_uploaded_entries", %{lv: lv} do
    upload_complete = "foo.jpeg:100%"
    parent = self()
    avatar =
      file_input(lv, "form", :avatar, [%{name: "foo.jpeg", content: String.duplicate("ok", 100)}])

    assert render_upload(avatar, "foo.jpeg", 100) =~ upload_complete

    run(lv, fn socket ->
      Phoenix.LiveView.consume_uploaded_entries(socket, :avatar, fn meta, entry ->
        send(parent, {:consume, meta, entry.client_name})
      end)
      {:reply, :ok, socket}
    end)

    assert_receive {:consume, %{uploader: "S3"}, "foo.jpeg"}
    refute render(lv) =~ upload_complete
  end

  @tag allow: [max_entries: 2, chunk_size: 20, accept: :any, external: :preflight]
  test "consume_uploaded_entry", %{lv: lv} do
    upload_complete = "foo.jpeg:100%"
    parent = self()
    avatar =
      file_input(lv, "form", :avatar, [%{name: "foo.jpeg", content: String.duplicate("ok", 100)}])

    assert render_upload(avatar, "foo.jpeg", 100) =~ upload_complete

    run(lv, fn socket ->
      {[entry], []} = Phoenix.LiveView.uploaded_entries(socket, :avatar)
      Phoenix.LiveView.consume_uploaded_entry(socket, entry, fn meta ->
        send(parent, {:individual_consume, meta, entry.client_name})
      end)
      {:reply, :ok, socket}
    end)

    assert_receive {:individual_consume, %{uploader: "S3"}, "foo.jpeg"}
    refute render(lv) =~ upload_complete
  end

  @tag allow: [max_entries: 5, chunk_size: 20, accept: :any, external: :preflight, progress: :consume]
  test "consume_uploaded_entry/3 maintains entries state after drop", %{lv: lv} do
    parent = self()

    # Note we are building a unique `%Upload{}` for each file.
    # This is to avoid the upload progress calls serializing in a
    # single UploadClient.
    files_inputs =
      for i <- 1..5,
          file = %{name: "#{i}.png", content: String.duplicate("ok", 100)},
          input = file_input(lv, "form", :avatar, [file]) do
        render_upload(input, file.name, 99)
        {file, input}
      end

    tasks =
      for {file, input} <- files_inputs do
        Task.async(fn -> render_upload(input, file.name, 1) end)
      end

    [_ | _] = Task.yield_many(tasks, 5000)

    run(lv, fn socket ->
      entries = Phoenix.LiveView.uploaded_entries(socket, :avatar)
      send(parent, {:consistent_consume, :avatar, entries})
      {:reply, :ok, socket}
    end)

    assert_receive {:consistent_consume, :avatar, entries}
    assert entries == {[], []}
  end
end
