defmodule Phoenix.LiveView.UploadTmpFileWriter do
  @moduledoc false

  @behaviour Phoenix.LiveView.UploadWriter

  @impl true
  def init(_opts) do
    with {:ok, path} <- Plug.Upload.random_file("live_view_upload"),
         {:ok, file} <- File.open(path, [:binary, :write]) do
      {:ok, %{path: path, file: file}}
    end
  end

  @impl true
  def meta(state) do
    %{path: state.path}
  end

  @impl true
  def write_chunk(data, state) do
    case IO.binwrite(state.file, data) do
      :ok -> {:ok, state}
      {:error, reason} -> {:error, reason, state}
    end
  end

  @impl true
  def close(state, _reason) do
    case File.close(state.file) do
      :ok -> {:ok, state}
      {:error, reason} -> {:error, reason}
    end
  end
end
