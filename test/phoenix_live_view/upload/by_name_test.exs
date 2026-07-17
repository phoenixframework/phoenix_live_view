defmodule Phoenix.LiveView.UploadByNameTest do
  use ExUnit.Case, async: true

  alias Phoenix.LiveView
  alias Phoenix.LiveView.{Upload, UploadConfig}

  defp build_socket() do
    %LiveView.Socket{}
  end

  describe "get_upload_by_name!/2" do
    test "resolves an upload by its client-sent name" do
      socket = LiveView.allow_upload(build_socket(), :octet, accept: :any)

      assert %UploadConfig{name: :octet} = Upload.get_upload_by_name!(socket, "octet")
    end

    test "raises for unknown upload names" do
      socket = LiveView.allow_upload(build_socket(), :octet, accept: :any)

      assert_raise ArgumentError, ~r/no upload allowed under name/, fn ->
        Upload.get_upload_by_name!(socket, "unknown")
      end
    end

    test "raises when no uploads were allowed at all" do
      assert_raise ArgumentError, ~r/no uploads have been allowed/, fn ->
        Upload.get_upload_by_name!(build_socket(), "octet")
      end
    end
  end
end
