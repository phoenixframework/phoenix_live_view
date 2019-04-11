if Code.ensure_loaded?(Phoenix.HTML) do
  defimpl Phoenix.HTML.FormData, for: Phoenix.LiveView.Socket do
    def to_form(socket, opts) do
      params = Keyword.get(opts, :params, %{})
      name = Keyword.fetch!(opts, :name)|| raise "name expected when using a socket form"
      opts = Keyword.drop(opts, [:params, :name])
      {errors, opts} = Keyword.pop(opts, :errors, [])

      %Phoenix.HTML.Form{
        source: socket,
        impl: __MODULE__,
        id: name,
        name: name,
        params: params,
        data: %{},
        errors: errors,
        options: opts
      }
    end

    def to_form(socket, form, field, opts) when is_atom(field) or is_binary(field) do
      {default, opts} = Keyword.pop(opts, :default, %{})
      {prepend, opts} = Keyword.pop(opts, :prepend, [])
      {append, opts} = Keyword.pop(opts, :append, [])
      {name, opts} = Keyword.pop(opts, :as)
      {id, opts} = Keyword.pop(opts, :id)

      id = to_string(id || form.id <> "_#{field}")
      name = to_string(name || form.name <> "[#{field}]")
      params = Map.get(form.params, field_to_string(field))

      cond do
        # cardinality: one
        is_map(default) ->
          [
            %Phoenix.HTML.Form{
              source: socket,
              impl: __MODULE__,
              id: id,
              name: name,
              data: default,
              params: params || %{},
              options: opts
            }
          ]

          # cardinality: many
        is_list(default) ->
          entries =
          if params do
            params
            |> Enum.sort_by(&elem(&1, 0))
            |> Enum.map(&{nil, elem(&1, 1)})
          else
            Enum.map(prepend ++ default ++ append, &{&1, %{}})
          end

          for {{data, params}, index} <- Enum.with_index(entries) do
            index_string = Integer.to_string(index)

            %Phoenix.HTML.Form{
              source: socket,
              impl: __MODULE__,
              index: index,
              id: id <> "_" <> index_string,
              name: name <> "[" <> index_string <> "]",
              data: data,
              params: params,
              options: opts
            }
          end
      end
    end

    def input_value(_socket, %{data: data, params: params}, field)
    when is_atom(field) or is_binary(field) do
      case Map.fetch(params, field_to_string(field)) do
        {:ok, value} ->
          value

        :error ->
          Map.get(data, field)
      end
    end

    def input_type(_socket, _form, _field), do: :text_input
    def input_validations(_socket, _form, _field), do: []

    # Normalize field name to string version
    defp field_to_string(field) when is_atom(field), do: Atom.to_string(field)
    defp field_to_string(field) when is_binary(field), do: field
  end
end
