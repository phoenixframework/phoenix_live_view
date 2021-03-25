defmodule Phoenix.LiveView.UploadConfigTest do
  use ExUnit.Case, async: true

  alias Phoenix.LiveView
  alias Phoenix.LiveView.{UploadConfig, UploadEntry}

  defp build_socket() do
    %LiveView.Socket{}
  end

  defp drop_entry(%UploadConfig{} = conf, ref) do
    entry = UploadConfig.get_entry_by_ref(conf, ref)
    UploadConfig.drop_entry(conf, entry)
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
      assert %UploadConfig{name: :avatar} = conf = socket.assigns.uploads.avatar
      assert conf.accept == ".jpg,.jpeg"
      assert conf.acceptable_types == MapSet.new(["image/jpeg"])

      socket = LiveView.allow_upload(build_socket(), :avatar, accept: ~w(image/png .jpeg))
      assert %UploadConfig{name: :avatar} = conf = socket.assigns.uploads.avatar
      assert conf.accept == "image/png,.jpeg"
      assert conf.acceptable_types == MapSet.new(["image/jpeg", "image/png"])
      assert conf.acceptable_exts == MapSet.new([".jpeg"])

      doc =
        ~w(.doc .docx .xml application/msword application/vnd.openxmlformats-officedocument.wordprocessingml.document)

      html_doc = Enum.join(doc, ",")

      socket = LiveView.allow_upload(build_socket(), :avatar, accept: doc)

      assert %UploadConfig{
               name: :avatar,
               accept: ^html_doc
             } = conf = socket.assigns.uploads.avatar

      assert conf.acceptable_types ==
               MapSet.new([
                 "application/msword",
                 "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                 "text/xml"
               ])

      assert conf.acceptable_exts == MapSet.new(~w(.doc .docx .xml))
    end

    test ":accept supports :any file" do
      socket = LiveView.allow_upload(build_socket(), :avatar, accept: :any)
      assert %UploadConfig{name: :avatar, accept: :any} = socket.assigns.uploads.avatar
    end

    test ":accept supports wildcard types" do
      socket = LiveView.allow_upload(build_socket(), :avatar, accept: ~w(image/*))
      assert %UploadConfig{name: :avatar} = conf = socket.assigns.uploads.avatar
      assert conf.accept == "image/*"
      assert conf.acceptable_types == MapSet.new(["image/*"])
      assert conf.acceptable_exts == MapSet.new([])

      socket = LiveView.allow_upload(build_socket(), :avatar, accept: ~w(audio/*))
      assert %UploadConfig{name: :avatar} = conf = socket.assigns.uploads.avatar
      assert conf.accept == "audio/*"
      assert conf.acceptable_types == MapSet.new(["audio/*"])
      assert conf.acceptable_exts == MapSet.new([])

      socket = LiveView.allow_upload(build_socket(), :avatar, accept: ~w(video/*))
      assert %UploadConfig{name: :avatar} = conf = socket.assigns.uploads.avatar
      assert conf.accept == "video/*"
      assert conf.acceptable_types == MapSet.new(["video/*"])
      assert conf.acceptable_exts == MapSet.new([])

      socket = LiveView.allow_upload(build_socket(), :avatar, accept: ~w(video/* .gif))
      assert %UploadConfig{name: :avatar} = conf = socket.assigns.uploads.avatar
      assert conf.accept == "video/*,.gif"
      assert conf.acceptable_types == MapSet.new(["image/gif", "video/*"])
      assert conf.acceptable_exts == MapSet.new([".gif"])
    end

    test "raises when invalid :max_entries provided" do
      assert_raise ArgumentError, ~r/invalid :max_entries value provided/, fn ->
        LiveView.allow_upload(build_socket(), :avatar, accept: :any, max_entries: -1)
      end

      assert_raise ArgumentError, ~r/invalid :max_entries value provided/, fn ->
        LiveView.allow_upload(build_socket(), :avatar, accept: :any, max_entries: 0)
      end

      assert_raise ArgumentError, ~r/invalid :max_entries value provided/, fn ->
        LiveView.allow_upload(build_socket(), :avatar, accept: :any, max_entries: "bad")
      end
    end

    test "raises when invalid :max_file_size provided" do
      assert_raise ArgumentError, ~r/invalid :max_file_size value provided/, fn ->
        LiveView.allow_upload(build_socket(), :avatar, accept: :any, max_file_size: -1)
      end

      assert_raise ArgumentError, ~r/invalid :max_file_size value provided/, fn ->
        LiveView.allow_upload(build_socket(), :avatar, accept: :any, max_file_size: 0)
      end

      assert_raise ArgumentError, ~r/invalid :max_file_size value provided/, fn ->
        LiveView.allow_upload(build_socket(), :avatar, accept: :any, max_file_size: "bad")
      end
    end

    test "supports optional :max_file_size" do
      socket = LiveView.allow_upload(build_socket(), :avatar, accept: :any)
      assert %UploadConfig{max_file_size: 8_000_000} = socket.assigns.uploads.avatar

      socket =
        LiveView.allow_upload(build_socket(), :avatar,
          accept: :any,
          max_file_size: 10_000_000
        )

      assert %UploadConfig{max_file_size: 10_000_000} = socket.assigns.uploads.avatar
    end
  end

  describe "disallow_upload/2" do
    test "disallows upload" do
      socket = LiveView.allow_upload(build_socket(), :avatar, accept: :any)
      assert socket.assigns.uploads.avatar.allowed?
      socket = LiveView.disallow_upload(socket, :avatar)
      refute socket.assigns.uploads.avatar.allowed?
    end

    test "raises when upload has active entries" do
      socket = LiveView.allow_upload(build_socket(), :avatar, accept: :any)

      {:ok, socket} =
        LiveView.Upload.put_entries(socket, socket.assigns.uploads.avatar, [
          build_client_entry(:avatar, %{"size" => 1024})
        ], nil)

      assert_raise RuntimeError, ~r/unable to disallow_upload/, fn ->
        LiveView.disallow_upload(socket, :avatar)
      end
    end
  end

  describe "put_entries/2" do
    test "does not overwrite existing refs" do
      socket = LiveView.allow_upload(build_socket(), :avatar, accept: :any, max_entries: 1)

      %{
        "name" => name,
        "size" => size,
        "ref" => ref,
        "type" => type
      } = entry = build_client_entry(:avatar)

      assert {:ok, avatar} = UploadConfig.put_entries(socket.assigns.uploads.avatar, [entry])
      entries_before = avatar.entries

      assert [
               %Phoenix.LiveView.UploadEntry{
                 client_name: ^name,
                 client_size: ^size,
                 client_type: ^type,
                 ref: ^ref
               }
             ] = entries_before

      modified_entry = Map.update!(entry, "size", fn _ -> 5009 end)
      assert {:ok, avatar} = UploadConfig.put_entries(avatar, [modified_entry])
      assert entries_before == avatar.entries
    end

    test "replaces sole entry for max_entries of 1" do
      socket = LiveView.allow_upload(build_socket(), :avatar, accept: :any, max_entries: 1)

      %{
        "name" => name,
        "size" => size,
        "ref" => ref,
        "type" => type
      } = entry = build_client_entry(:avatar)

      assert {:ok, avatar} = UploadConfig.put_entries(socket.assigns.uploads.avatar, [entry])
      entries_before = avatar.entries

      assert [
               %Phoenix.LiveView.UploadEntry{
                 client_name: ^name,
                 client_size: ^size,
                 client_type: ^type,
                 ref: ^ref
               }
             ] = entries_before

      modified_entry = Map.update!(entry, "ref", fn _ -> "1234" end)
      assert {:ok, avatar} = UploadConfig.put_entries(avatar, [modified_entry])
      assert entries_before != avatar.entries
      assert length(avatar.entries) == 1
    end

    test "returns error when greater than max_entries are provided" do
      socket = LiveView.allow_upload(build_socket(), :avatar, accept: :any)

      entry = build_client_entry(:avatar)

      assert {:error, avatar} =
               UploadConfig.put_entries(socket.assigns.uploads.avatar, [
                 build_client_entry(:avatar),
                 entry
               ])

      assert avatar.errors == [{avatar.ref, :too_many_files}]
    end

    test "returns error when entry with greater than max_file_size provided" do
      socket = LiveView.allow_upload(build_socket(), :avatar, accept: :any)
      entry = build_client_entry(:avatar, %{"size" => 8_000_001})
      assert {:error, avatar} = UploadConfig.put_entries(socket.assigns.uploads.avatar, [entry])
      assert avatar.errors == [{entry["ref"], :too_large}]

      socket = LiveView.allow_upload(build_socket(), :avatar, accept: :any, max_file_size: 1024)
      entry = build_client_entry(:avatar, %{"size" => 2048})
      assert {:error, avatar} = UploadConfig.put_entries(socket.assigns.uploads.avatar, [entry])
      assert avatar.errors == [{entry["ref"], :too_large}]
    end

    test "validates client size less than :max_file_size and generates uuid when valid" do
      socket = LiveView.allow_upload(build_socket(), :avatar, accept: :any)

      {:ok, config} =
        UploadConfig.put_entries(socket.assigns.uploads.avatar, [
          build_client_entry(:avatar, %{"size" => 1024})
        ])

      assert [%UploadEntry{client_size: 1024, uuid: uuid}] = config.entries
      assert uuid
    end

    test "validates entries accepted by extension" do
      socket =
        build_socket()
        |> LiveView.allow_upload(:avatar, accept: ~w(.jpg .jpeg), max_entries: 5)
        |> LiveView.allow_upload(:hero, accept: ~w(.jpg .jpeg), max_entries: 5)

      assert {:ok, config} =
               UploadConfig.put_entries(socket.assigns.uploads.avatar, [
                 build_client_entry(:avatar, %{"name" => "photo.jpg", "type" => "image/jpeg"}),
                 build_client_entry(:avatar, %{"name" => "photo.JPG", "type" => "image/jpeg"}),
                 build_client_entry(:avatar, %{"name" => "photo.jpeg", "type" => "image/jpeg"}),
                 build_client_entry(:avatar, %{"name" => "photo.JPEG", "type" => "image/jpeg"})
               ])

      assert [
               %UploadEntry{client_name: "photo.jpg"},
               %UploadEntry{client_name: "photo.JPG"},
               %UploadEntry{client_name: "photo.jpeg"},
               %UploadEntry{client_name: "photo.JPEG"}
             ] = config.entries

      hero_config = socket.assigns.uploads.hero
      entry = build_client_entry(:avatar, %{"name" => "file.gif"})

      assert {:error, %UploadConfig{} = hero_config} =
               UploadConfig.put_entries(hero_config, [entry])

      assert hero_config.errors == [{entry["ref"], :not_accepted}]

      hero_config = drop_entry(hero_config, entry["ref"])
      entry = build_client_entry(:avatar, %{"name" => "file.gif", "type" => "image/png"})

      assert {:error, %UploadConfig{} = hero_config} =
               UploadConfig.put_entries(hero_config, [entry])

      assert hero_config.errors == [{entry["ref"], :not_accepted}]

      hero_config = drop_entry(hero_config, entry["ref"])
      entry = build_client_entry(:avatar, %{"name" => "file", "type" => "image/png"})

      assert {:error, %UploadConfig{} = hero_config} =
               UploadConfig.put_entries(hero_config, [entry])

      assert hero_config.errors == [{entry["ref"], :not_accepted}]
    end

    test "validates entries accepted by type" do
      socket =
        build_socket()
        |> LiveView.allow_upload(:avatar, accept: ~w(image/png image/jpeg), max_entries: 4)
        |> LiveView.allow_upload(:hero, accept: ~w(image/png image/jpeg), max_entries: 4)

      assert {:ok, config} =
               UploadConfig.put_entries(socket.assigns.uploads.avatar, [
                 build_client_entry(:avatar, %{"name" => "photo", "type" => "image/png"}),
                 build_client_entry(:avatar, %{"name" => "photo", "type" => "image/jpeg"})
               ])

      assert [
               %UploadEntry{client_name: "photo", client_type: "image/png"},
               %UploadEntry{client_name: "photo", client_type: "image/jpeg"}
             ] = config.entries

      hero_config = socket.assigns.uploads.hero
      entry = build_client_entry(:avatar, %{"name" => "photo", "type" => "image/gif"})
      assert {:error, hero_config} = UploadConfig.put_entries(hero_config, [entry])
      assert hero_config.errors == [{entry["ref"], :not_accepted}]

      hero_config = drop_entry(hero_config, entry["ref"])

      entry =
        build_client_entry(:avatar, %{"name" => "photo.jpg", "type" => "application/x-httpd-php"})

      assert {:error, hero_config} = UploadConfig.put_entries(hero_config, [entry])
      assert hero_config.errors == [{entry["ref"], :not_accepted}]
    end

    test "puts list of entries accepted by extension OR type" do
      socket =
        LiveView.allow_upload(build_socket(), :avatar,
          accept: ~w(image/* .pdf audio/mpeg),
          max_entries: 8
        )

      assert {:ok, config} =
               UploadConfig.put_entries(socket.assigns.uploads.avatar, [
                 build_client_entry(:avatar, %{"name" => "photo", "type" => "image/jpeg"}),
                 build_client_entry(:avatar, %{"name" => "photo", "type" => "image/png"}),
                 build_client_entry(:avatar, %{"name" => "photo", "type" => "image/gif"}),
                 build_client_entry(:avatar, %{"name" => "photo", "type" => "image/webp"}),
                 build_client_entry(:avatar, %{"name" => "photo.pdf"}),
                 build_client_entry(:avatar, %{"name" => "photo.pdf", "type" => "application/pdf"}),
                 build_client_entry(:avatar, %{"name" => "photo.mp4", "type" => "audio/mpeg"})
               ])

      assert length(config.entries) == 7
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
