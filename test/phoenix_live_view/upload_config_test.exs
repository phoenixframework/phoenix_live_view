defmodule Phoenix.LiveView.UploadConfigTest do
  use ExUnit.Case, async: true

  alias Phoenix.LiveView
  alias Phoenix.LiveView.UploadConfig

  defp build_socket() do
    %LiveView.Socket{}
  end

  describe "allow_upload/3" do
    test "raises when no or invalid :extensions are provided" do
      assert_raise ArgumentError, ~r/the :extensions option is required/, fn ->
        LiveView.allow_upload(build_socket(), :avatar, max_files: 5)
      end

      assert_raise ArgumentError, ~r/invalid extensions provided/, fn ->
        LiveView.allow_upload(build_socket(), :avatar, extensions: [])
      end

      assert_raise ArgumentError, ~r/invalid extensions provided/, fn ->
        LiveView.allow_upload(build_socket(), :avatar, extensions: :bad)
      end
    end

    test "supports list of extensions" do
      socket = LiveView.allow_upload(build_socket(), :avatar, extensions: ~w(jpg jpeg))
      assert %UploadConfig{name: :avatar} = socket.assigns.uploads.avatar
    end

    test "supports :any extensions" do
      socket = LiveView.allow_upload(build_socket(), :avatar, extensions: :any)
      assert %UploadConfig{name: :avatar} = socket.assigns.uploads.avatar
    end
  end
end
