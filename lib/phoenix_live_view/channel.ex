defmodule Phoenix.LiveView.Channel do
  @moduledoc false
  use Phoenix.Channel

  alias Phoenix.LiveView

  def join(_, %{"view" => token}, socket) do
    with {:ok, pid} <- LiveView.Server.verify_token(socket, token, max_age: 1209600),
         _ref = Process.monitor(pid),
         :ok <- LiveView.Server.attach(pid) do

      new_socket =
        socket
        |> assign(:view_pid, pid)
        |> assign(:view_id, token)

      {:ok, new_socket}
    else
      {:error, {:noproc, _}} -> {:error, %{reason: "noproc"}}
      {:error, _reason} -> {:error, %{reason: :bad_view}}
    end
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

  # TODO optimize encoding. Avoid IOdata => binary => json.
  # Ideally send iodta down pipe w/ channel info
  defp push_render(socket, content) when is_list(content) do
    push(socket, "render", %{
      id: socket.assigns.view_id,
      html: IO.iodata_to_binary(content)
    })
  end
  defp push_render(socket, content) when is_binary(content) do
    push(socket, "render", %{id: socket.assigns.view_id, html: content})
  end

  defp push_redirect(socket, opts) do
    push(socket, "redirect", %{
      to: Keyword.fetch!(opts, :to),
      flash: sign_token(socket, opts[:flash])
    })
  end
  defp sign_token(_socket, nil), do: nil
  defp sign_token(socket, %{} = flash), do: LiveView.Flash.sign_token(socket.endpoint, flash)
end
