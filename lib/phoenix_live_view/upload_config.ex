defmodule Phoenix.LiveView.UploadConfig do
  alias Phoenix.LiveView.UploadConfig
  @moduledoc """
  TODO
  """

  defstruct name: nil,
            pid_to_refs: %{},
            client_key: nil,
            entries: [],
            allowed_extensions: [],
            external: nil,
            allowed?: false

  @type t :: %__MODULE__{
    name: atom(),
    pid_to_refs: map,
    client_key: String.t(),
    entries: list(),
    allowed_extensions: list() | :any,
    external: (Socket.t() -> Socket.t()) | nil,
    allowed?: boolean
  }

  @doc false
  def build(name, [_|_] = opts) when is_atom(name) do
    exts =
      case Keyword.fetch(opts, :extensions) do
        {:ok, [_|_]} = non_empty_list -> non_empty_list
        {:ok, :any} -> :any
        {:ok, other} ->
          raise ArgumentError, """
          invalid extensions provided to allow_upload.

          Only a list of extension strings or the atom :any are supported. Got:

          #{inspect(other)}
          """

        :error ->
          raise ArgumentError, """
          the :extensions option is required when allowing uploads

          Provide a list of extension strings or the atom :any to allow any kind of file extension.
          """
      end

    external =
      case Keyword.fetch(opts, :extensions) do
        {:ok, func} when is_function(func, 1) -> func
        {:ok, func} when is_function(func) ->
        {:ok, other} ->
          raise ArgumentError, """
          invalid :external value provided to allow_upload.

          Only an anymous function receiving the socket as an argument is supported. Got:

          #{inspect(other)}
          """

        :error ->
          nil
      end


    %UploadConfig{
      name: name,
      allowed_extensions: exts,
      external: external,
      allowed?: true
    }
  end

  @doc false
  def disallow(%UploadConfig{} = conf), do: %UploadConfig{conf | allowed?: false}

  @doc false
  def uploaded_entries(%UploadConfig{} = conf) do
    Enum.filter(conf.entries, fn %UploadEntry{} = entry -> entry.progress == 100 end)
  end
end

defmodule Phoenix.LiveView.UploadEntry do
  @moduledoc """
  TODO
  """

  defstruct progess: 0,
            name: nil,
            ref: nil
end
