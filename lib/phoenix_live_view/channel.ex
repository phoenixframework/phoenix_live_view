defmodule Phoenix.LiveView.Channel do
  @moduledoc false
  use Phoenix.Channel

  alias Phoenix.LiveView

  def join("views:" <> id, %{"session" => session_token}, socket) do
    with {:ok, session} <- verify_session(socket, session_token),
         {:ok, pid, html} <- LiveView.Server.spawn_render(socket.endpoint, session) do

      new_socket =
        socket
        |> assign(:view_pid, pid)
        |> assign(:view_id, id)

      {:ok, %{html: encode_render(html)}, new_socket}
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

  def handle_info({:render, content}, socket) do
    push_render(socket, content)
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
      {:render, content} -> push_render(socket, content)
      :noop -> :noop
    end

    {:noreply, socket}
  end
  defp decode("form", url_encoded) do
    Plug.Conn.Query.decode(url_encoded)
  end
  defp decode(_, value), do: value

  defp push_render(socket, content) when is_list(content) do
    push(socket, "render", %{
      id: socket.assigns.view_id,
      html: encode_render(content)
    })
  end

  defp push_redirect(socket, opts) do
    push(socket, "redirect", %{
      to: Keyword.fetch!(opts, :to),
      flash: sign_token(socket, opts[:flash])
    })
  end

  defp sign_token(_socket, nil), do: nil
  defp sign_token(socket, %{} = flash) do
    LiveView.Flash.sign_token(socket.endpoint, salt(socket), flash)
  end

  defp salt(%Phoenix.Socket{endpoint: endpoint}) do
    Phoenix.LiveView.Socket.configured_signing_salt!(endpoint)
  end

  # TODO optimize encoding. Avoid IOdata => binary => json.
  # Ideally send iodta down pipe w/ channel info
  defp encode_render(content) when is_list(content) do
    IO.iodata_to_binary(content)
  end
  defp encode_render(content) when is_binary(content), do: content
end
