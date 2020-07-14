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
            acceptable_extensions: [],
            acceptable_types: [],
            external: nil,
            allowed?: false,
            ref: nil

  @type t :: %__MODULE__{
          name: atom(),
          pid_to_refs: map,
          client_key: String.t(),
          max_entries: pos_integer(),
          entries: list(),
          acceptable_extensions: list() | :any,
          acceptable_types: list() | :any,
          external: (Socket.t() -> Socket.t()) | nil,
          allowed?: boolean
        }

  @doc false
  # we require a random_ref in order to ensure unique calls to `allow_upload`
  # invalidate old uploads on the client and expire old tokens for the same
  # upload name
  def build(name, random_ref, [_ | _] = opts) when is_atom(name) do
    {exts, mimes} =
      case Keyword.fetch(opts, :accept) do
        {:ok, [_ | _] = filters} ->
          validate_split_acceptable(filters)

        {:ok, :any} ->
          {:any, :any}

        {:ok, other} ->
          raise ArgumentError, """
          invalid accept filter provided to allow_upload.

          A list of the following file type specifiers are supported:

            * A valid case-insensitive filename extension, starting with a period (".") character.
              For example: .jpg, .pdf, or .doc.

            * A valid MIME type string, with no extensions.

          Alternately, you can provide the atom :any to allow any kind of file. Got:

          #{inspect(other)}
          """

        :error ->
          raise ArgumentError, """
          the :accept option is required when allowing uploads.

          Provide a list of unique file type specifiers or the atom :any to allow any kind of file.
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
      acceptable_extensions: exts,
      acceptable_types: mimes,
      external: external,
      allowed?: true
    }
  end

  defp validate_split_acceptable(filters) do
    Enum.reduce(filters, {[], []}, fn filter, {exts, mimes} ->
      case validate_accept_filter(filter) do
        {:ext, ext} -> {exts ++ [ext], mimes}
        {:mime, mime} -> {exts, mimes ++ [mime]}
      end
    end)
  end

  defp validate_accept_filter(<<"." <> _>> = ext), do: {:ext, ext}

  defp validate_accept_filter(filter) when is_binary(filter) do
    if String.contains?(filter, "/") do
      {:mime, filter}
    else
      raise ArgumentError, """
      invalid accept filter provided to allow_upload.

      The following file type specifiers are supported:

        * A valid case-insensitive filename extension, starting with a period (".") character.
          For example: .jpg, .pdf, or .doc.

        * A valid MIME type string, with no extensions.

      Got:

      #{inspect(filter)}
      """
    end
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

  def put_entries(%UploadConfig{} = conf, entries) do
    entries
    |> Enum.reduce_while({:ok, conf}, fn client_entry, {:ok, acc} ->
      case cast_and_validate_entry(acc, client_entry) do
        {:ok, new_conf} -> {:cont, {:ok, new_conf}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, new_conf} -> {:ok, new_conf}
      {:error, reason} -> {:error, reason}
    end
  end

  # TODO validate against config constraints
  defp cast_and_validate_entry(%UploadConfig{entries: entries, max_entries: max}, _)
       when length(entries) >= max do
    {:error, :too_many_files}
  end

  defp cast_and_validate_entry(%UploadConfig{} = conf, %{"ref" => ref} = client_entry) do
    entry = %UploadEntry{
      ref: ref,
      client_name: Map.fetch!(client_entry, "name"),
      client_size: Map.fetch!(client_entry, "size"),
      client_type: Map.fetch!(client_entry, "type"),
      client_last_modified: Map.fetch!(client_entry, "last_modified")
    }

    {:ok, %UploadConfig{conf | entries: conf.entries ++ [entry]}}
  end
end
