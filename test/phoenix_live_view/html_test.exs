defmodule Phoenix.LiveView.HTMLTest do
  use ExUnit.Case, async: true

  import Phoenix.HTML
  import Phoenix.HTML.Form

  defp safe_form_for(socket, opts \\ [name: "user"], function) do
    safe_to_string(form_for(socket, "#", opts, function))
  end

  defp new_socket() do
    %Phoenix.LiveView.Socket{}
  end

  describe "form_for/4" do
    test "with new socket" do
      socket = new_socket()

      form =
      safe_form_for(socket, fn f ->
        assert f.id == "user"
        assert f.name == "user"
        assert f.impl == Phoenix.HTML.FormData.Phoenix.LiveView.Socket
        assert f.source == socket
        assert f.params == %{}
        assert f.hidden == []
        "FROM FORM"
      end)

      assert form =~ ~s(<form accept-charset="UTF-8" action="#" method="post">)
      assert form =~ "FROM FORM"
    end

    test "with inputs" do
      socket = new_socket()
      params = %{"name" => "CM"}
      form =
      safe_form_for(socket, [name: "user", params: params], fn f ->
        [text_input(f, :name), text_input(f, :other)]
      end)

      assert form =~ ~s(<input id="user_name" name="user[name]" type="text" value="CM">)
      assert form =~ ~s(<input id="user_other" name="user[other]" type="text">)
    end


    test "with errors" do
      socket = new_socket()
      errors = [name: {"should be at least %{count} character(s)", count: 3}]
      form =
      safe_form_for(socket, [name: "user", errors: errors], fn f ->
        assert f.errors == errors
        "FROM FORM"
      end)

      assert form =~ "FROM FORM"
    end
  end
end
