defmodule Phoenix.LiveView.DirectoryTest do
  use ExUnit.Case, async: false

  @endpoint Phoenix.LiveViewTest.Endpoint

  import Phoenix.LiveViewTest

  alias Phoenix.LiveViewTest.UploadLive

  def mount_lv(setup) when is_function(setup, 1) do
    conn = Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), %{})
    {:ok, lv, _} = live_isolated(conn, UploadLive, session: %{})
    :ok = GenServer.call(lv.pid, {:setup, setup})
    {:ok, lv}
  end

  test "can set relative path from file_input/4 helper" do
    {:ok, lv} =
      mount_lv(fn socket ->
        Phoenix.LiveView.allow_upload(socket, :avatar,
          max_entries: 2,
          chunk_size: 20,
          accept: :any,
          external: fn _entry, socket ->
            {:ok, %{uploader: "S3"}, socket}
          end
        )
      end)

    avatar =
      file_input(lv, "form", :avatar, [
        %{
          name: "foo1.jpeg",
          content: String.duplicate("ok", 100),
          relative_path: "some/path/to/foo1.jpeg"
        }
      ])

    assert render_upload(avatar, "foo1.jpeg", 1) =~ "relative path:some/path/to/foo1.jpeg"
  end
end
