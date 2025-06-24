defmodule Phoenix.LiveView.Debug do
  @moduledoc """
  Functions for runtime introspection and debugging of LiveViews.

  This module provides utilities for inspecting and debugging LiveView processes
  at runtime. It allows you to:

    * List all currently connected LiveViews
    * Check if a process is a LiveView
    * Get the socket of a LiveView process
    * Inspect LiveComponents rendered in a LiveView

  ## Examples

      # List all LiveViews
      iex> Phoenix.LiveView.Debug.list_liveviews()
      [%{pid: #PID<0.123.0>, view: MyAppWeb.PostLive.Index, topic: "lv:12345678", transport_pid: #PID<0.122.0>}]

      # Check if a process is a LiveView
      iex> Phoenix.LiveView.Debug.liveview_process?(pid(0,123,0))
      true

      # Get the socket of a LiveView process
      iex> Phoenix.LiveView.Debug.socket(pid(0,123,0))
      {:ok, %Phoenix.LiveView.Socket{...}}

      # Get information about LiveComponents
      iex> Phoenix.LiveView.Debug.live_components(pid(0,123,0))
      {:ok, [%{id: "component-1", module: MyAppWeb.PostLive.Index.Component1, ...}]}

  """

  @doc """
  Returns a list of all currently connected LiveView processes (on the current node).

  Each entry is a map with the following keys:

    - `pid`: The PID of the LiveView process.
    - `view`: The module of the LiveView.
    - `topic`: The topic of the LiveView's channel.
    - `transport_pid`: The PID of the transport process.

  The `transport_pid` can be used to group LiveViews on the same page.

  ## Examples

      iex> list_liveviews()
      [%{pid: #PID<0.123.0>, view: MyAppWeb.PostLive.Index, topic: "lv:12345678", transport_pid: #PID<0.122.0>}]

  """
  def list_liveviews do
    for pid <- Process.list(), dict = lv_process_dict(pid), not is_nil(dict) do
      {Phoenix.LiveView, view, topic} = keyfind(dict, :"$process_label")
      %{pid: pid, view: view, topic: topic, transport_pid: keyfind(dict, :"$phx_transport_pid")}
    end
  end

  defp keyfind(list, key) do
    case List.keyfind(list, key, 0) do
      {^key, value} -> value
      _ -> nil
    end
  end

  defp lv_process_dict(pid) do
    # LiveViews set the "$process_label" to {Phoenix.LiveView, view, topic}
    with info when is_list(info) <- Process.info(pid, [:dictionary]),
         dictionary when not is_nil(dictionary) <- keyfind(info, :dictionary),
         label when not is_nil(label) <- keyfind(dictionary, :"$process_label"),
         {Phoenix.LiveView, view, topic} when is_atom(view) and is_binary(topic) <- label do
      dictionary
    else
      _ -> nil
    end
  end

  @doc """
  Checks if the given pid is a LiveView process.

  ## Examples

      iex> list_liveviews() |> Enum.at(0) |> Map.fetch!(:pid) |> liveview_process?()
      true

      iex> liveview_process?(pid(0,456,0))
      false

  """
  def liveview_process?(pid) do
    not is_nil(lv_process_dict(pid))
  end

  @doc """
  Returns the socket of the LiveView process.

  ## Examples

      iex> list_liveviews() |> Enum.at(0) |> Map.fetch!(:pid) |> socket()
      {:ok, %Phoenix.LiveView.Socket{...}}

      iex> socket(pid(0,123,0))
      {:error, :not_alive_or_not_a_liveview}

  """
  def socket(liveview_pid) do
    GenServer.call(liveview_pid, {:phoenix, :debug_get_socket})
  catch
    :exit, _ -> {:error, :not_alive_or_not_a_liveview}
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
    GenServer.call(liveview_pid, {:phoenix, :debug_live_components})
  catch
    :exit, _ -> {:error, :not_alive_or_not_a_liveview}
  end
end
