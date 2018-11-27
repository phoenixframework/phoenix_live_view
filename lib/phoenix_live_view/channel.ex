defmodule Phoenix.LiveView.Channel do
  @moduledoc false
  use Phoenix.Channel

  alias Phoenix.LiveView
  alias Phoenix.LiveView.Diff

  def join("views:" <> id, %{"session" => session_token}, socket) do
    with {:ok, session} <- verify_session(socket, session_token),
         {:ok, pid, rendered} <- LiveView.Server.spawn_render(socket.endpoint, session) do

      {new_socket, rendered_diff} =
        socket
        |> assign(:view_pid, pid)
        |> assign(:view_id, id)
        |> assign(:fingerprints, nil)
        |> render_diff(rendered)

      {:ok, %{rendered: rendered_diff}, new_socket}
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
    {:noreply, push_render(socket, rendered)}
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
      {:redirect, opts} -> {:noreply, push_redirect(socket, opts)}
      {:render, rendered} -> {:noreply, push_render(socket, rendered)}
      :noop -> {:noreply, socket}
    end
  end
  defp decode("form", url_encoded) do
    Plug.Conn.Query.decode(url_encoded)
  end
  defp decode(_, value), do: value

  defp push_render(socket, %LiveView.Rendered{} = rendered) do
    {new_socket, diff} = render_diff(socket, rendered)
    push(new_socket, "render", diff)
    new_socket
  end

  defp push_redirect(socket, opts) do
    push(socket, "redirect", %{
      to: Keyword.fetch!(opts, :to),
      flash: sign_flash(socket, opts[:flash])
    })
    socket
  end

  defp sign_flash(_socket, nil), do: nil
  defp sign_flash(socket, %{} = flash) do
    LiveView.Flash.sign_token(socket.endpoint, salt(socket), flash)
  end

  defp salt(%Phoenix.Socket{endpoint: endpoint}) do
    Phoenix.LiveView.Socket.configured_signing_salt!(endpoint)
  end

  defp render_diff(%Phoenix.Socket{} = socket, %LiveView.Rendered{} = rendered) do
    {diff, new_prints} = Diff.render(rendered, socket.assigns.fingerprints)
    {assign(socket, :fingerprints, new_prints), diff}
  end
end
