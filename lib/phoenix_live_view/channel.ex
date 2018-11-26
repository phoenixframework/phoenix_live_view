defmodule Phoenix.LiveView.Channel do
  @moduledoc false
  use Phoenix.Channel

  alias Phoenix.LiveView

  def join("views:" <> id, %{"session" => session_token}, socket) do
    with {:ok, session} <- verify_session(socket, session_token),
         {:ok, pid, rendered} <- LiveView.Server.spawn_render(socket.endpoint, session) do

      new_socket =
        socket
        |> assign(:view_pid, pid)
        |> assign(:view_id, id)

      {:ok, %{rendered: serialize(rendered)}, new_socket}
    else
      {:error, {:noproc, _}} -> {:error, %{reason: "noproc"}}
      {:error, _reason} -> {:error, %{reason: :bad_token}}
    end
  end

  defp verify_session(socket, session_token) do
    LiveView.Server.verify_token(socket, salt(socket), session_token, max_age: 1209600)
  end

  def handle_info({:DOWN, _, :process, pid, _}, %{assigns: %{view_pid: pid}} = socket) do
    {:stop, :normal, socket}
  end

  def handle_info({:render, rendered}, socket) do
    push_render(socket, rendered)
    {:noreply, socket}
  end

  def handle_info({:redirect, opts}, socket) do
    push_redirect(socket, opts)
    {:noreply, socket}
  end

  def handle_info({:push_session, token}, socket) do
    push(socket, "session", %{token: token})
    {:noreply, socket}
  end

  def handle_in("event", params, socket) do
    %{"id" => id, "value" => raw_val, "event" => event, "type" => type} = params
    val = decode(type, raw_val)

    case GenServer.call(socket.assigns.view_pid, {:channel_event, event, id, val}) do
      {:redirect, opts} -> push_redirect(socket, opts)
      {:render, rendered} -> push_render(socket, rendered)
      :noop -> :noop
    end

    {:noreply, socket}
  end
  defp decode("form", url_encoded) do
    Plug.Conn.Query.decode(url_encoded)
  end
  defp decode(_, value), do: value

  defp push_render(socket, %Phoenix.LiveView.Rendered{} = rendered) do
    push(socket, "render", serialize_dynamic(rendered))
  end

  defp push_redirect(socket, opts) do
    push(socket, "redirect", %{
      to: Keyword.fetch!(opts, :to),
      flash: sign_flash(socket, opts[:flash])
    })
  end

  defp sign_flash(_socket, nil), do: nil
  defp sign_flash(socket, %{} = flash) do
    LiveView.Flash.sign_token(socket.endpoint, salt(socket), flash)
  end

  defp salt(%Phoenix.Socket{endpoint: endpoint}) do
    Phoenix.LiveView.Socket.configured_signing_salt!(endpoint)
  end

  # TODO move to serializer
  defp serialize(%LiveView.Rendered{static: static, dynamic: dynamic}) do
    %{
      static: static,
      dynamic: to_map(dynamic, &serialize(&1))
    }
  end
  defp serialize(nil), do: nil
  defp serialize(iodata) do
    IO.iodata_to_binary(iodata)
  end

  defp serialize_dynamic(%LiveView.Rendered{dynamic: dynamic}) do
    to_map(dynamic, &serialize_dynamic(&1))
  end
  defp serialize_dynamic(nil), do: nil
  defp serialize_dynamic(iodata) do
    IO.iodata_to_binary(iodata)
  end

  defp to_map(dynamic, serializer_func) do
    {_, map} =
      Enum.reduce(dynamic, {0, %{}}, fn segment, {index, acc} ->
        if value = serializer_func.(segment) do
          {index + 1, Map.put(acc, index, value)}
        else
          {index + 1, acc}
        end
      end)

    map
  end
end
