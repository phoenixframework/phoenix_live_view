defmodule Phoenix.LiveViewUnitTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveView

  alias Phoenix.LiveView.{Utils, Socket}
  alias Phoenix.LiveViewTest.Endpoint

  @socket Utils.configure_socket(
            %Socket{
              endpoint: Endpoint,
              router: Phoenix.LiveViewTest.Router,
              view: Phoenix.LiveViewTest.ParamCounterLive
            },
            %{
              connect_params: %{},
              connect_info: %{},
              changed: %{},
              root_view: Phoenix.LiveViewTest.ParamCounterLive
            },
            nil,
            %{},
            URI.parse("https://www.example.com")
          )

  describe "flash" do
    test "get and put" do
      assert put_flash(@socket, :hello, "world").assigns.flash == %{"hello" => "world"}
      assert put_flash(@socket, :hello, :world).assigns.flash == %{"hello" => :world}
    end

    test "clear" do
      socket = put_flash(@socket, :hello, "world")
      assert clear_flash(socket).assigns.flash == %{}
      assert clear_flash(socket, :hello).assigns.flash == %{}
      assert clear_flash(socket, "hello").assigns.flash == %{}
      assert clear_flash(socket, "other").assigns.flash == %{"hello" => "world"}
    end
  end

  describe "get_connect_params" do
    test "raises when not in mounting state and connected" do
      socket = Utils.post_mount_prune(%{@socket | transport_pid: self()})

      assert_raise RuntimeError, ~r/attempted to read connect_params/, fn ->
        get_connect_params(socket)
      end
    end

    test "raises when not in mounting state and disconnected" do
      socket = Utils.post_mount_prune(%{@socket | transport_pid: nil})

      assert_raise RuntimeError, ~r/attempted to read connect_params/, fn ->
        get_connect_params(socket)
      end
    end

    test "returns nil when disconnected" do
      socket = %{@socket | transport_pid: nil}
      assert get_connect_params(socket) == nil
    end

    test "returns params connected and mounting" do
      socket = %{@socket | transport_pid: self()}
      assert get_connect_params(socket) == %{}
    end
  end

  describe "get_connect_info" do
    test "raises when not in mounting state and connected" do
      socket = Utils.post_mount_prune(%{@socket | transport_pid: self()})

      assert_raise RuntimeError, ~r/attempted to read connect_info/, fn ->
        get_connect_info(socket)
      end
    end

    test "raises when not in mounting state and disconnected" do
      socket = Utils.post_mount_prune(%{@socket | transport_pid: nil})

      assert_raise RuntimeError, ~r/attempted to read connect_info/, fn ->
        get_connect_info(socket)
      end
    end

    test "returns nil when disconnected" do
      socket = %{@socket | transport_pid: nil}
      assert get_connect_info(socket) == nil
    end

    test "returns params connected and mounting" do
      socket = %{@socket | transport_pid: self()}
      assert get_connect_info(socket) == %{}
    end
  end

  describe "static_changed?" do
    test "raises when not in mounting state and connected" do
      socket = Utils.post_mount_prune(%{@socket | transport_pid: self()})

      assert_raise RuntimeError, ~r/attempted to read static_changed?/, fn ->
        static_changed?(socket)
      end
    end

    test "raises when not in mounting state and disconnected" do
      socket = Utils.post_mount_prune(%{@socket | transport_pid: nil})

      assert_raise RuntimeError, ~r/attempted to read static_changed?/, fn ->
        static_changed?(socket)
      end
    end

    test "returns false when disconnected" do
      socket = %{@socket | transport_pid: nil}
      assert static_changed?(socket) == false
    end

    test "returns true when connected and static do not match" do
      refute static_changed?([], %{})
      refute static_changed?(["foo/bar.css"], nil)

      assert static_changed?(["foo/bar.css"], %{})
      refute static_changed?(["foo/bar.css"], %{"foo/bar.css" => "foo/bar-123456.css"})

      refute static_changed?(
               ["domain.com/foo/bar.css"],
               %{"foo/bar.css" => "foo/bar-123456.css"}
             )

      refute static_changed?(
               ["//domain.com/foo/bar.css"],
               %{"foo/bar.css" => "foo/bar-123456.css"}
             )

      refute static_changed?(
               ["//domain.com/foo/bar.css?vsn=d"],
               %{"foo/bar.css" => "foo/bar-123456.css"}
             )

      refute static_changed?(
               ["//domain.com/foo/bar-123456.css"],
               %{"foo/bar.css" => "foo/bar-123456.css"}
             )

      refute static_changed?(
               ["//domain.com/foo/bar-123456.css?vsn=d"],
               %{"foo/bar.css" => "foo/bar-123456.css"}
             )

      assert static_changed?(
               ["//domain.com/foo/bar-654321.css"],
               %{"foo/bar.css" => "foo/bar-123456.css"}
             )

      assert static_changed?(
               ["foo/bar.css", "baz/bat.js"],
               %{"foo/bar.css" => "foo/bar-123456.css"}
             )

      assert static_changed?(
               ["foo/bar.css", "baz/bat.js"],
               %{"foo/bar.css" => "foo/bar-123456.css", "p/baz/bat.js" => "p/baz/bat-123456.js"}
             )

      refute static_changed?(
               ["foo/bar.css", "baz/bat.js"],
               %{"foo/bar.css" => "foo/bar-123456.css", "baz/bat.js" => "baz/bat-123456.js"}
             )
    end

    defp static_changed?(client, latest) do
      socket = %{@socket | transport_pid: self()}
      Process.put(:cache_static_manifest_latest, latest)
      socket = put_in(socket.private.connect_params["_track_static"], client)
      static_changed?(socket)
    end
  end

  describe "assign" do
    test "tracks changes" do
      socket = assign(@socket, existing: "foo")
      assert socket.changed.existing == true

      socket = Utils.clear_changed(socket)
      assert assign(socket, existing: "foo").changed == %{}
    end

    test "keeps whole maps in changes" do
      socket = assign(@socket, existing: %{foo: :bar})
      socket = Utils.clear_changed(socket)

      socket = assign(socket, existing: %{foo: :baz})
      assert socket.assigns.existing == %{foo: :baz}
      assert socket.changed.existing == %{foo: :bar}

      socket = assign(socket, existing: %{foo: :bat})
      assert socket.assigns.existing == %{foo: :bat}
      assert socket.changed.existing == %{foo: :bar}

      socket = assign(socket, %{existing: %{foo: :bam}})
      assert socket.assigns.existing == %{foo: :bam}
      assert socket.changed.existing == %{foo: :bar}
    end
  end

  describe "assign_new" do
    test "uses socket assigns if no parent assigns are present" do
      socket =
        @socket
        |> assign(existing: "existing")
        |> assign_new(:existing, fn -> "new-existing" end)
        |> assign_new(:notexisting, fn -> "new-notexisting" end)

      assert socket.assigns == %{
               existing: "existing",
               notexisting: "new-notexisting",
               live_action: nil,
               flash: %{}
             }
    end

    test "uses parent assigns when present and falls back to socket assigns" do
      socket =
        put_in(@socket.private[:assign_new], {%{existing: "existing-parent"}, []})
        |> assign(existing2: "existing2")
        |> assign_new(:existing, fn -> "new-existing" end)
        |> assign_new(:existing2, fn -> "new-existing2" end)
        |> assign_new(:notexisting, fn -> "new-notexisting" end)

      assert socket.assigns == %{
               existing: "existing-parent",
               existing2: "existing2",
               notexisting: "new-notexisting",
               live_action: nil,
               flash: %{}
             }
    end
  end

  describe "redirect/2" do
    test "requires local path on to" do
      assert_raise ArgumentError, ~r"the :to option in redirect/2 expects a path", fn ->
        redirect(@socket, to: "http://foo.com")
      end

      assert_raise ArgumentError, ~r"the :to option in redirect/2 expects a path", fn ->
        redirect(@socket, to: "//foo.com")
      end

      assert redirect(@socket, to: "/foo").redirected == {:redirect, %{to: "/foo"}}
    end

    test "allows external paths" do
      assert redirect(@socket, external: "http://foo.com/bar").redirected ==
               {:redirect, %{external: "http://foo.com/bar"}}
    end
  end

  describe "push_redirect/2" do
    test "requires local path on to" do
      assert_raise ArgumentError, ~r"the :to option in push_redirect/2 expects a path", fn ->
        push_redirect(@socket, to: "http://foo.com")
      end

      assert_raise ArgumentError, ~r"the :to option in push_redirect/2 expects a path", fn ->
        push_redirect(@socket, to: "//foo.com")
      end

      assert push_redirect(@socket, to: "/counter/123").redirected ==
               {:live, :redirect, %{kind: :push, to: "/counter/123"}}
    end
  end

  describe "push_patch/2" do
    test "requires local path on to pointing to the same LiveView" do
      assert_raise ArgumentError, ~r"the :to option in push_patch/2 expects a path", fn ->
        push_patch(@socket, to: "http://foo.com")
      end

      assert_raise ArgumentError, ~r"the :to option in push_patch/2 expects a path", fn ->
        push_patch(@socket, to: "//foo.com")
      end

      assert_raise ArgumentError,
                   ~r"cannot push_patch/2 to \"/counter/123\" because the given path does not point to the current root view",
                   fn ->
                     push_patch(put_in(@socket.private.root_view, __MODULE__), to: "/counter/123")
                   end

      socket = %{@socket | view: Phoenix.LiveViewTest.ParamCounterLive}

      assert push_patch(socket, to: "/counter/123").redirected ==
               {:live, {%{"id" => "123"}, nil}, %{kind: :push, to: "/counter/123"}}
    end
  end
end
