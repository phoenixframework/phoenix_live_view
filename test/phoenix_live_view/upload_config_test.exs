defmodule Phoenix.LiveView.UploadConfigTest do
  use ExUnit.Case, async: true

  alias Phoenix.LiveView
  alias Phoenix.LiveView.{UploadConfig, UploadEntry}

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

  describe "put_entries/2" do
    test "returns error when greater than max_entries are provided" do
      socket = LiveView.allow_upload(build_socket(), :avatar, extensions: :any)
      assert UploadConfig.put_entries(socket.assigns.uploads.avatar, [
        build_client_entry(:avatar),
        build_client_entry(:avatar)
      ]) == {:error, :too_many_files}

      socket = LiveView.allow_upload(build_socket(), :avatar, extensions: :any, max_entries: 2)
      config = socket.assigns.uploads.avatar

      assert {:ok, config} = UploadConfig.put_entries(config, [build_client_entry(:avatar)])
      assert {:ok, config} = UploadConfig.put_entries(config, [build_client_entry(:avatar)])
      assert UploadConfig.put_entries(config, [build_client_entry(:avatar)]) == {:error, :too_many_files}
    end

    test "puts list of valid entries" do
      socket = LiveView.allow_upload(build_socket(), :avatar, extensions: :any)
      config = socket.assigns.uploads.avatar
      %{"name" => client_name} = client_entry = build_client_entry(:avatar)

      {:ok, config} = UploadConfig.put_entries(config, [client_entry])
      assert [%UploadEntry{client_name: ^client_name}] = config.entries
    end
  end

  defp build_client_entry(name, attrs \\ %{}) do
    attrs
    |> Enum.into(%{
      "name" => "#{name}_#{System.unique_integer([:positive, :monotonic])}",
      "last_modified" => DateTime.utc_now() |> DateTime.to_unix(),
      "size" => 1024,
      "type" => "application/octet-stream"
    })
    |> Map.put_new_lazy("ref", &Phoenix.LiveView.Utils.random_id/0)
  end
end
