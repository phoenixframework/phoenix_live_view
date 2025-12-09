defmodule Phoenix.ComponentUnitTest do
  use ExUnit.Case, async: true

  alias Phoenix.LiveView.{Socket, Utils}
  import Phoenix.Component

  @socket Utils.configure_socket(
            %Socket{
              endpoint: Endpoint,
              router: Phoenix.LiveViewTest.Support.Router,
              view: Phoenix.LiveViewTest.Support.ParamCounterLive
            },
            %{
              connect_params: %{},
              connect_info: %{},
              root_view: Phoenix.LiveViewTest.Support.ParamCounterLive,
              __changed__: %{}
            },
            nil,
            %{},
            URI.parse("https://www.example.com")
          )

  @assigns_changes %{key: "value", map: %{foo: :bar}, __changed__: %{}}
  @assigns_nil_changes %{key: "value", map: %{foo: :bar}, __changed__: nil}

  describe "assign with socket" do
    test "tracks changes" do
      socket = assign(@socket, existing: "foo")
      assert changed?(socket, :existing)

      socket = Utils.clear_changed(socket)
      socket = assign(socket, existing: "foo")
      refute changed?(socket, :existing)
    end

    test "keeps whole maps in changes" do
      socket = assign(@socket, existing: %{foo: :bar})
      socket = Utils.clear_changed(socket)

      socket = assign(socket, existing: %{foo: :baz})
      assert socket.assigns.existing == %{foo: :baz}
      assert socket.assigns.__changed__.existing == %{foo: :bar}

      socket = assign(socket, existing: %{foo: :bat})
      assert socket.assigns.existing == %{foo: :bat}
      assert socket.assigns.__changed__.existing == %{foo: :bar}

      socket = assign(socket, %{existing: %{foo: :bam}})
      assert socket.assigns.existing == %{foo: :bam}
      assert socket.assigns.__changed__.existing == %{foo: :bar}
    end

    test "keeps whole lists in changes" do
      socket = assign(@socket, existing: [:foo, :bar])
      socket = Utils.clear_changed(socket)

      socket = assign(socket, existing: [:foo, :baz])
      assert socket.assigns.existing == [:foo, :baz]
      assert socket.assigns.__changed__.existing == [:foo, :bar]

      socket = assign(socket, existing: [:foo, :bat])
      assert socket.assigns.existing == [:foo, :bat]
      assert socket.assigns.__changed__.existing == [:foo, :bar]

      socket = assign(socket, %{existing: [:foo, :bam]})
      assert socket.assigns.existing == [:foo, :bam]
      assert socket.assigns.__changed__.existing == [:foo, :bar]
    end

    test "allows functions" do
      socket = assign(@socket, fn _ -> [existing: [:foo, :bar]] end)
      socket = Utils.clear_changed(socket)

      socket = assign(socket, fn %{existing: [:foo, :bar]} -> %{existing: [:foo, :baz]} end)
      assert socket.assigns.existing == [:foo, :baz]
      assert socket.assigns.__changed__.existing == [:foo, :bar]
    end
  end

  describe "assign with assigns" do
    test "tracks changes" do
      assigns = assign(@assigns_changes, key: "value")
      assert assigns.key == "value"
      refute changed?(assigns, :key)

      assigns = assign(@assigns_changes, key: "changed")
      assert assigns.key == "changed"
      assert changed?(assigns, :key)

      assigns = assign(@assigns_nil_changes, key: "changed")
      assert assigns.key == "changed"
      assert assigns.__changed__ == nil
      assert changed?(assigns, :key)
    end

    test "track changes on unknown vars" do
      assigns = assign(@assigns_changes, unknown: nil)
      assert assigns.unknown == nil
      assert changed?(assigns, :unknown)

      assigns = assign(@assigns_changes, unknown: "changed")
      assert assigns.unknown == "changed"
      assert changed?(assigns, :unknown)
    end

    test "keeps whole maps in changes" do
      assigns = assign(@assigns_changes, map: %{foo: :baz})
      assert assigns.map == %{foo: :baz}
      assert assigns.__changed__[:map] == %{foo: :bar}

      assigns = assign(@assigns_nil_changes, map: %{foo: :baz})
      assert assigns.map == %{foo: :baz}
      assert assigns.__changed__ == nil
    end

    test "allows functions" do
      assigns = assign(@assigns_changes, fn _ -> %{map: %{foo: :baz}} end)
      assert assigns.map == %{foo: :baz}
      assert assigns.__changed__[:map] == %{foo: :bar}

      assigns = assign(@assigns_nil_changes, fn _ -> [map: %{foo: :baz}] end)
      assert assigns.map == %{foo: :baz}
      assert assigns.__changed__ == nil
    end
  end

  describe "assign_new with socket" do
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
               flash: %{},
               __changed__: %{existing: true, notexisting: true}
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
               flash: %{},
               __changed__: %{existing: true, notexisting: true, existing2: true}
             }
    end

    test "has access to assigns" do
      socket =
        put_in(@socket.private[:assign_new], {%{existing: "existing-parent"}, []})
        |> assign(existing2: "existing2")
        |> assign_new(:existing, fn _ -> "new-existing" end)
        |> assign_new(:existing2, fn _ -> "new-existing2" end)
        |> assign_new(:notexisting, fn %{existing: existing} -> existing end)
        |> assign_new(:notexisting2, fn %{existing2: existing2} -> existing2 end)
        |> assign_new(:notexisting3, fn %{notexisting: notexisting} -> notexisting end)

      assert socket.assigns == %{
               existing: "existing-parent",
               existing2: "existing2",
               notexisting: "existing-parent",
               notexisting2: "existing2",
               notexisting3: "existing-parent",
               live_action: nil,
               flash: %{},
               __changed__: %{
                 existing: true,
                 existing2: true,
                 notexisting: true,
                 notexisting2: true,
                 notexisting3: true
               }
             }
    end
  end

  describe "assign_new with assigns" do
    test "tracks changes" do
      assigns = assign_new(@assigns_changes, :key, fn -> raise "won't be invoked" end)
      assert assigns.key == "value"
      refute changed?(assigns, :key)
      refute assigns.__changed__[:key]

      assigns = assign_new(@assigns_changes, :another, fn -> "changed" end)
      assert assigns.another == "changed"
      assert changed?(assigns, :another)

      assigns = assign_new(@assigns_nil_changes, :another, fn -> "changed" end)
      assert assigns.another == "changed"
      assert changed?(assigns, :another)
      assert assigns.__changed__ == nil
    end

    test "has access to new assigns" do
      assigns =
        assign_new(@assigns_changes, :another, fn -> "changed" end)
        |> assign_new(:and_another, fn %{another: another} -> another end)

      assert assigns.and_another == "changed"
      assert changed?(assigns, :another)
      assert changed?(assigns, :and_another)
    end
  end

  describe "update with socket" do
    test "tracks changes" do
      socket = @socket |> assign(key: "value") |> Utils.clear_changed()

      socket = update(socket, :key, fn "value" -> "value" end)
      assert socket.assigns.key == "value"
      refute changed?(socket, :key)

      socket = update(socket, :key, fn "value" -> "changed" end)
      assert socket.assigns.key == "changed"
      assert changed?(socket, :key)
    end
  end

  describe "update with assigns" do
    test "tracks changes" do
      assigns = update(@assigns_changes, :key, fn "value" -> "value" end)
      assert assigns.key == "value"
      refute changed?(assigns, :key)

      assigns = update(@assigns_changes, :key, fn "value" -> "changed" end)
      assert assigns.key == "changed"
      assert changed?(assigns, :key)

      assigns = update(@assigns_nil_changes, :key, fn "value" -> "changed" end)
      assert assigns.key == "changed"
      assert changed?(assigns, :key)
      assert assigns.__changed__ == nil
    end
  end

  describe "update with arity 2 function" do
    test "passes socket assigns to update function" do
      socket = @socket |> assign(key: "value", key2: "another") |> Utils.clear_changed()

      socket = update(socket, :key2, fn key2, %{key: key} -> key2 <> " " <> key end)
      assert socket.assigns.key2 == "another value"
      assert changed?(socket, :key2)
    end

    test "passes assigns to update function" do
      assigns = update(@assigns_changes, :key, fn _, %{map: %{foo: bar}} -> bar end)
      assert assigns.key == :bar
      assert changed?(assigns, :key)
    end
  end

  test "assigns_to_attributes/2" do
    assert assigns_to_attributes(%{}) == []
    assert assigns_to_attributes(%{}, [:non_exists]) == []
    assert assigns_to_attributes(%{one: 1, two: 2}) == [one: 1, two: 2]
    assert assigns_to_attributes(%{one: 1, two: 2}, [:one]) == [two: 2]
    assert assigns_to_attributes(%{__changed__: %{}, one: 1, two: 2}, [:one]) == [two: 2]
    assert assigns_to_attributes(%{__changed__: %{}, inner_block: fn -> :ok end, a: 1}) == [a: 1]
    assert assigns_to_attributes(%{__slot__: :foo, inner_block: fn -> :ok end, a: 1}) == [a: 1]
  end

  describe "to_form/2" do
    test "with a map" do
      form = to_form(%{})
      assert form.name == nil
      assert form.id == nil

      form = to_form(%{}, as: :foo)
      assert form.name == "foo"
      assert form.id == "foo"

      form = to_form(%{}, as: :foo, id: "bar")
      assert form.name == "foo"
      assert form.id == "bar"

      form = to_form(%{}, custom: "attr")
      assert form.options == [custom: "attr"]

      form = to_form(%{}, errors: [name: "can't be blank"])
      assert form.errors == [name: "can't be blank"]
    end

    test "with a form" do
      base = to_form(%{}, as: "name", id: "id")
      assert to_form(base, []) == base

      form = to_form(base, as: :foo)
      assert form.name == "foo"
      assert form.id == "foo"

      form = to_form(base, id: "bar")
      assert form.name == "name"
      assert form.id == "bar"

      form = to_form(base, as: :foo, id: "bar")
      assert form.name == "foo"
      assert form.id == "bar"

      form = to_form(base, as: nil, id: nil)
      assert form.name == nil
      assert form.id == nil

      form = to_form(base, custom: "attr")
      assert form.options[:custom] == "attr"

      form = to_form(base, errors: [name: "can't be blank"])
      assert form.errors == [name: "can't be blank"]

      form = to_form(base, action: :validate)
      assert form.action == :validate

      form = to_form(%{base | action: :validate})
      assert form.action == :validate
    end
  end

  test "used_input?/1" do
    params = %{}
    form = to_form(params, as: "profile", action: :validate)
    refute used_input?(form[:username])
    refute used_input?(form[:email])

    params = %{"username" => "", "email" => ""}
    form = to_form(params, as: "profile", action: :validate)
    assert used_input?(form[:username])
    assert used_input?(form[:email])

    params = %{"username" => "", "email" => "", "_unused_username" => ""}
    form = to_form(params, as: "profile", action: :validate)
    refute used_input?(form[:username])
    assert used_input?(form[:email])

    params = %{"username" => "", "email" => "", "_unused_username" => "", "_unused_email" => ""}
    form = to_form(params, as: "profile", action: :validate)
    refute used_input?(form[:username])
    refute used_input?(form[:email])

    params = %{
      "bday" => %{"day" => "", "month" => "", "year" => ""},
      "published_at" => %{"date" => "", "time" => "", "_unused_date" => "", "_unused_time" => ""},
      "deleted_at" => %{},
      "inserted_at" => %{"date" => "", "time" => "", "_unused_time" => ""},
      "date" => DateTime.utc_now()
    }

    form = to_form(params, as: "profile", action: :validate)
    assert used_input?(form[:bday])
    refute used_input?(form[:published_at])
    refute used_input?(form[:deleted_at])
    assert used_input?(form[:inserted_at])
    assert used_input?(form[:date])
  end
end
