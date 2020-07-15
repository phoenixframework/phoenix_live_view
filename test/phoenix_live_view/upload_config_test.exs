defmodule Phoenix.LiveView.UploadConfigTest do
  use ExUnit.Case, async: true

  alias Phoenix.LiveView
  alias Phoenix.LiveView.{UploadConfig, UploadEntry}

  defp build_socket() do
    %LiveView.Socket{}
  end

  describe "allow_upload/3" do
    test "raises when no or invalid :accept provided" do
      assert_raise ArgumentError, ~r/the :accept option is required/, fn ->
        LiveView.allow_upload(build_socket(), :avatar, max_entries: 5)
      end

      assert_raise ArgumentError, ~r/invalid accept filter provided/, fn ->
        LiveView.allow_upload(build_socket(), :avatar, accept: [])
      end

      assert_raise ArgumentError, ~r/invalid accept filter provided/, fn ->
        LiveView.allow_upload(build_socket(), :avatar, accept: :bad)
      end

      assert_raise ArgumentError, ~r/invalid accept filter provided/, fn ->
        LiveView.allow_upload(build_socket(), :avatar, accept: "bad")
      end

      assert_raise ArgumentError, ~r/invalid accept filter provided/, fn ->
        LiveView.allow_upload(build_socket(), :avatar, accept: ["bad"])
      end

      assert_raise ArgumentError, ~r/invalid accept filter provided/, fn ->
        LiveView.allow_upload(build_socket(), :avatar, accept: ~w(.foobarbaz))
      end

      assert_raise ArgumentError, ~r/invalid accept filter provided/, fn ->
        LiveView.allow_upload(build_socket(), :avatar, accept: ~w(.jpg image/jpeg bad))
      end

      assert_raise ArgumentError, ~r/invalid accept filter provided/, fn ->
        LiveView.allow_upload(build_socket(), :avatar, accept: ~w(foo/*))
      end
    end

    test ":accept supports list of extensions and mime types" do
      socket = LiveView.allow_upload(build_socket(), :avatar, accept: ~w(.jpg .jpeg))
      assert %UploadConfig{name: :avatar, accept: accept} = socket.assigns.uploads.avatar
      assert accept == %{"image/jpeg" => ~w(.jpg .jpeg)}

      socket = LiveView.allow_upload(build_socket(), :avatar, accept: ~w(image/png image/jpeg))
      assert %UploadConfig{name: :avatar, accept: accept} = socket.assigns.uploads.avatar
      assert accept == %{"image/png" => ["image/png"], "image/jpeg" => ["image/jpeg"]}

      socket =
        LiveView.allow_upload(build_socket(), :avatar,
          accept:
            ~w(.doc .docx .xml application/msword application/vnd.openxmlformats-officedocument.wordprocessingml.document)
        )

      assert %UploadConfig{
               name: :avatar,
               accept: %{
                 "application/msword" => ~w(.doc application/msword),
                 "application/vnd.openxmlformats-officedocument.wordprocessingml.document" =>
                   ~w(.docx application/vnd.openxmlformats-officedocument.wordprocessingml.document),
                 "text/xml" => ~w(.xml)
               }
             } = socket.assigns.uploads.avatar
    end

    test ":accept supports :any file" do
      socket = LiveView.allow_upload(build_socket(), :avatar, accept: :any)
      assert %UploadConfig{name: :avatar, accept: :any} = socket.assigns.uploads.avatar
    end

    test ":accept supports wildcard types" do
      socket = LiveView.allow_upload(build_socket(), :avatar, accept: ~w(image/*))
      assert %UploadConfig{name: :avatar, accept: accept} = socket.assigns.uploads.avatar
      assert accept == %{"image/*" => ["image/*"]}

      socket = LiveView.allow_upload(build_socket(), :avatar, accept: ~w(audio/*))
      assert %UploadConfig{name: :avatar, accept: accept} = socket.assigns.uploads.avatar
      assert accept == %{"audio/*" => ["audio/*"]}

      socket = LiveView.allow_upload(build_socket(), :avatar, accept: ~w(video/*))
      assert %UploadConfig{name: :avatar, accept: accept} = socket.assigns.uploads.avatar
      assert accept == %{"video/*" => ["video/*"]}

      socket = LiveView.allow_upload(build_socket(), :avatar, accept: ~w(video/* .gif))
      assert %UploadConfig{name: :avatar, accept: accept} = socket.assigns.uploads.avatar
      assert accept == %{"image/gif" => ~w(.gif), "video/*" => ["video/*"]}
    end
  end

  describe "put_entries/2" do
    test "returns error when greater than max_entries are provided" do
      socket = LiveView.allow_upload(build_socket(), :avatar, accept: :any)

      assert UploadConfig.put_entries(socket.assigns.uploads.avatar, [
               build_client_entry(:avatar),
               build_client_entry(:avatar)
             ]) == {:error, :too_many_files}

      socket = LiveView.allow_upload(build_socket(), :avatar, accept: :any, max_entries: 2)
      config = socket.assigns.uploads.avatar

      assert {:ok, config} = UploadConfig.put_entries(config, [build_client_entry(:avatar)])
      assert {:ok, config} = UploadConfig.put_entries(config, [build_client_entry(:avatar)])

      assert UploadConfig.put_entries(config, [build_client_entry(:avatar)]) ==
               {:error, :too_many_files}
    end

    test "returns error when file not accepted" do
      socket =
        LiveView.allow_upload(build_socket(), :avatar,
          accept: ~w(.jpg .jpeg image/jpeg .png image/png)
        )

      config = socket.assigns.uploads.avatar

      assert UploadConfig.put_entries(config, [
               build_client_entry(:avatar, %{"name" => "file.gif", "type" => "image/gif"})
             ]) == {:error, :not_accepted}

      assert UploadConfig.put_entries(config, [
               build_client_entry(:avatar, %{"name" => "file", "type" => "image/gif"})
             ]) == {:error, :not_accepted}
    end

    test "puts list of acceptable entries" do
      socket =
        LiveView.allow_upload(build_socket(), :avatar,
          accept: ~w(.jpg .jpeg image/jpeg .png image/png),
          max_entries: 10
        )

      assert {:ok, config} =
               UploadConfig.put_entries(socket.assigns.uploads.avatar, [
                 build_client_entry(:avatar, %{"name" => "photo", "type" => "image/jpeg"}),
                 build_client_entry(:avatar, %{"name" => "photo", "type" => "image/png"}),
                 build_client_entry(:avatar, %{"name" => "photo.jpg", "type" => "image/jpeg"}),
                 build_client_entry(:avatar, %{"name" => "photo.jpeg", "type" => "image/jpeg"}),
                 build_client_entry(:avatar, %{"name" => "photo.png", "type" => "image/png"}),
                 build_client_entry(:avatar, %{"name" => "photo.JPG", "type" => "image/jpeg"}),
                 build_client_entry(:avatar, %{"name" => "photo.JPEG", "type" => "image/jpeg"}),
                 build_client_entry(:avatar, %{"name" => "photo.PNG", "type" => "image/png"})
               ])

      assert [%UploadEntry{} | _] = config.entries
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
