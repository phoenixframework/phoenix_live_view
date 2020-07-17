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

  @default_max_file_size 8_000_000

  # TODO add option for :chunk_size
  defstruct name: nil,
            pid_to_refs: %{},
            client_key: nil,
            max_entries: 1,
            max_file_size: @default_max_file_size,
            entries: [],
            accept: %{},
            external: nil,
            allowed?: false,
            ref: nil,
            errors: []

  @type t :: %__MODULE__{
          name: atom(),
          pid_to_refs: map,
          client_key: String.t(),
          max_entries: pos_integer(),
          max_file_size: pos_integer(),
          entries: list(),
          accept: map() | :any,
          external: (Socket.t() -> Socket.t()) | nil,
          allowed?: boolean,
          errors: list()
        }

  @doc false
  # we require a random_ref in order to ensure unique calls to `allow_upload`
  # invalidate old uploads on the client and expire old tokens for the same
  # upload name
  def build(name, random_ref, [_ | _] = opts) when is_atom(name) do
    accept =
      case Keyword.fetch(opts, :accept) do
        {:ok, [_ | _] = accept} ->
          validate_accept_option(accept)

        {:ok, :any} ->
          :any

        {:ok, other} ->
          raise ArgumentError, """
          invalid accept filter provided to allow_upload.

          A list of the following unique file type specifiers are supported:

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

    max_file_size =
      case Keyword.fetch(opts, :max_file_size) do
        {:ok, pos_integer} when is_integer(pos_integer) and pos_integer > 0 ->
          pos_integer

        {:ok, other} ->
          raise ArgumentError, """
          invalid :max_file_size value provided to allow_upload.

          Only a positive integer is supported (Defaults to #{@default_max_file_size} bytes). Got:

          #{inspect(other)}
          """

        :error ->
          @default_max_file_size
      end

    %UploadConfig{
      ref: random_ref,
      name: name,
      max_entries: opts[:max_entries] || 1,
      max_file_size: max_file_size,
      accept: accept,
      external: external,
      allowed?: true
    }
  end

  # specifics on the `accept` attribute are illuminated in the spec:
  # https://html.spec.whatwg.org/multipage/input.html#attr-input-accept
  @accept_wildcards ~w(audio/* image/* video/*)

  defp validate_accept_option(accept) do
    accept
    |> Enum.map(&accept_option!/1)
    |> Enum.group_by(fn {key, _} -> key end, fn {_, value} -> value end)
    |> Enum.into(%{}, fn {key, value} -> {key, Enum.flat_map(value, & &1)} end)
  end

  # wildcards for media files
  defp accept_option!(key) when key in @accept_wildcards, do: {key, [key]}

  defp accept_option!(<<"." <> extname::binary>> = ext) do
    if MIME.has_type?(extname) do
      {MIME.type(extname), [ext]}
    else
      raise ArgumentError, """
        invalid accept filter provided to allow_upload.

        Expected a file extension with a known MIME type.

        MIME types can be extended in your application configuration as follows:

        config :mime, :types, %{
          "application/vnd.api+json" => ["json-api"]
        }

        Got:

        #{inspect(extname)}
      """
    end
  end

  defp accept_option!(filter) when is_binary(filter) do
    if MIME.valid?(filter) do
      {filter, [filter]}
    else
      raise ArgumentError, """
        invalid accept filter provided to allow_upload.

        Expected a known MIME type without parameters.

        MIME types can be extended in your application configuration as follows:

        config :mime, :types, %{
          "application/vnd.api+json" => ["json-api"]
        }

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
        {:error, ref, reason} -> {:halt, {:error, ref, reason}}
      end
    end)
    |> case do
      {:ok, new_conf} -> {:ok, new_conf}
      {:error, ref, reason} -> {:error, ref, reason}
    end
  end

  # TODO validate against config constraints
  defp cast_and_validate_entry(%UploadConfig{entries: entries, max_entries: max}, %{"ref" => ref})
       when length(entries) >= max do
    {:error, ref, :too_many_files}
  end

  defp cast_and_validate_entry(%UploadConfig{} = conf, %{"ref" => ref} = client_entry) do
    entry = %UploadEntry{
      ref: ref,
      client_name: Map.fetch!(client_entry, "name"),
      client_size: Map.fetch!(client_entry, "size"),
      client_type: Map.fetch!(client_entry, "type"),
      client_last_modified: Map.fetch!(client_entry, "last_modified")
    }

    {:ok, entry}
    |> validate_max_file_size(conf)
    |> validate_accepted(conf)
    |> case do
      {:ok, entry} -> {:ok, %UploadConfig{conf | entries: conf.entries ++ [entry]}}
      {:error, reason} -> {:error, ref, reason}
    end
  end

  defp validate_max_file_size({:ok, %UploadEntry{client_size: size}}, %UploadConfig{max_file_size: max})
       when size > max,
       do: {:error, :too_large}

  defp validate_max_file_size(entry, _conf), do: entry

  defp validate_accepted({:ok, %UploadEntry{} = entry}, conf) do
    if accepted?(conf, entry) do
      {:ok, entry}
    else
      {:error, :not_accepted}
    end
  end

  defp validate_accepted({:error, _} = error, _conf), do: error

  defp accepted?(%UploadConfig{accept: :any}, _entry), do: true
  defp accepted?(%UploadConfig{accept: %{"image/*" => _}}, %UploadEntry{client_type: <<"image/" <> _>>}), do: true
  defp accepted?(%UploadConfig{accept: %{"audio/*" => _}}, %UploadEntry{client_type: <<"audio/" <> _>>}), do: true
  defp accepted?(%UploadConfig{accept: %{"video/*" => _}}, %UploadEntry{client_type: <<"video/" <> _>>}), do: true

  defp accepted?(%UploadConfig{accept: accept}, %UploadEntry{} = entry) do
    cond do
      Map.has_key?(accept, entry.client_type) -> true
      Path.extname(entry.client_name) in (accept |> Map.values() |> Enum.concat()) -> true
      true -> false
    end
  end

  @doc """
  TODO
  """
  def put_error(%UploadConfig{} = conf, _entry_ref, :too_many_files = reason) do
    %UploadConfig{conf | errors: conf.errors ++ [reason]}
  end

  def put_error(%UploadConfig{} = conf, entry_ref, reason) do
    %UploadConfig{conf | errors: conf.errors ++ [{entry_ref, reason}]}
  end
end
