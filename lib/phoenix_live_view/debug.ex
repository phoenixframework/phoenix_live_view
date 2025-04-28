defmodule Phoenix.LiveView.Debug do
  @moduledoc """
  Functions for runtime introspection and debugging of LiveViews.

  TODO
  """

  @doc """
  Returns a list of all currently connected LiveView processes (on the curret node).

  ## Examples

      iex> list_liveview_processes()
      [#PID<0.123.0>]

  """
  def list_liveview_processes do
    for pid <- Process.list(), liveview_process?(pid) do
      pid
    end
  end

  @doc """
  Returns true if the given pid is a LiveView process.

  ## Examples

      iex> list_liveview_processes() |> Enum.at(0) |> liveview_process?()
      true

      iex> liveview_process?(pid(0,456,0))
      false

  """
  def liveview_process?(pid) do
    # LiveViews set the "$process_label" to {Phoenix.LiveView, view, topic}
    with info when is_list(info) <- Process.info(pid, [:dictionary]),
         {:dictionary, dictionary} <- List.keyfind(info, :dictionary, 0),
         {:"$process_label", label} <- List.keyfind(dictionary, :"$process_label", 0),
         true <-
           match?({Phoenix.LiveView, view, topic} when is_atom(view) and is_binary(topic), label) do
      true
    else
      _ -> false
    end
  end

  @doc """
  Returns the socket of the LiveView process.

  ## Examples

      iex> list_liveview_processes() |> Enum.at(0) |> socket()
      {:ok, %Phoenix.LiveView.Socket{...}}

      iex> socket(pid(0,123,0))
      {:error, :not_a_liveview}

  """
  def socket(liveview_pid) do
    case :sys.get_state(liveview_pid, 5000) do
      %{socket: %Phoenix.LiveView.Socket{} = socket} -> {:ok, socket}
      _ -> {:error, :not_a_liveview}
    end
  end

  @doc """
  Returns a list with information about all LiveComponents rendered in the LiveView.

  ## Examples

      iex> live_components(pid)
      {:ok,
       [
         %{
           id: "component-1",
           module: MyAppWeb.PostLive.Index.Component1,
           cid: 1,
           assigns: %{
             id: "component-1",
             __changed__: %{},
             flash: %{},
             myself: %Phoenix.LiveComponent.CID{cid: 1},
             ...
           }
         }
       ]}

  """
  def live_components(liveview_pid) do
    case :sys.get_state(liveview_pid, 5000) do
      %{socket: %Phoenix.LiveView.Socket{}, components: components} ->
        {:ok, extract_components(components)}

      _ ->
        {:error, :not_a_liveview}
    end
  end

  defp extract_components({components, _, _}) when components == %{}, do: []

  defp extract_components({components, _, _}) do
    # components is a map of cid => {module, id, assigns, private, fingerprints}
    Enum.map(components, fn {cid, {mod, id, assigns, _private, _prints}} ->
      %{id: id, cid: cid, module: mod, assigns: assigns}
    end)
  end
end
