defmodule Phoenix.LiveView.UploadEntry do
  @moduledoc """
  TODO
  """

  alias Phoenix.LiveView.UploadEntry

  defstruct progress: 0,
            ref: nil,
            done?: false,
            client_name: nil,
            client_size: nil,
            client_type: nil,
            client_last_modified: nil

  @doc false
  def put_progress(%UploadEntry{} = entry, 100) do
    %UploadEntry{entry | progress: 100, done?: true}
  end
  def put_progress(%UploadEntry{} = entry, progress) do
    %UploadEntry{entry | progress: progress}
  end
end

defmodule Phoenix.LiveView.UploadConfig do
  @moduledoc """
  TODO
  """

  alias Phoenix.LiveView.UploadConfig
  alias Phoenix.LiveView.UploadEntry

  defstruct name: nil,
            pid_to_refs: %{},
            client_key: nil,
            max_entries: 1,
            entries: [],
            allowed_extensions: [],
            external: nil,
            allowed?: false,
            ref: nil

  @type t :: %__MODULE__{
          name: atom(),
          pid_to_refs: map,
          client_key: String.t(),
          max_entries: pos_integer(),
          entries: list(),
          allowed_extensions: list() | :any,
          external: (Socket.t() -> Socket.t()) | nil,
          allowed?: boolean
        }

  @doc false
  # we require a random_ref in order to ensure unique calls to `allow_upload`
  # invalidate old uploads on the client and expire old tokens for the same
  # upload name
  def build(name, random_ref, [_ | _] = opts) when is_atom(name) do
    exts =
      case Keyword.fetch(opts, :extensions) do
        {:ok, [_ | _]} = non_empty_list ->
          non_empty_list

        {:ok, :any} ->
          :any

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
      case Keyword.fetch(opts, :external) do
        {:ok, func} when is_function(func, 1) ->
          func

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
      ref: random_ref,
      name: name,
      max_entries: opts[:max_entries] || 1,
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

  @doc false
  def update_progress(%UploadConfig{} = conf, entry_ref, progress)
      when is_integer(progress) and progress >= 0 and progress <= 100 do
    new_entries =
      Enum.map(conf.entries, fn
        %UploadEntry{ref: ^entry_ref} = entry -> UploadEntry.put_progress(entry, progress)
        %UploadEntry{ref: _ef} = entry -> entry
      end)

    %UploadConfig{conf | entries: new_entries}
  end

  # TODO validate against config constraints during reduce
  def put_entries(%UploadConfig{} = conf, entries) do
    entries
    |> Enum.reduce_while({:ok, []}, fn %{"ref" => ref} = client_entry, {:ok, acc} ->
      entry = %UploadEntry{
        ref: ref,
        client_name: Map.fetch!(client_entry, "name"),
        client_size: Map.fetch!(client_entry, "size"),
        client_type: Map.fetch!(client_entry, "type"),
        client_last_modified: Map.fetch!(client_entry, "last_modified"),
      }
      {:cont, {:ok, [entry | acc]}}
    end)
    |> case do
      {:ok, new_entries} -> {:ok, %UploadConfig{conf | entries: Enum.reverse(new_entries)}}
      {:error, reason} -> {:error, reason}
    end
  end
end
