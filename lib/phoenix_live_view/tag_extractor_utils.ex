defmodule Phoenix.LiveView.TagExtractorUtils do
  @moduledoc """
  Useful functions for implementors of `Phoenix.LiveView.TagExtractor`.
  """

  @opaque tokens :: list(token())
  @opaque token ::
            {any(), binary(), list(attribute()), map()}
            | {:close, any(), binary(), map()}
            | {:text, binary(), map()}
  @opaque attribute :: {binary(), {atom(), any(), map()}, map()}

  defguardp is_tag_or_component(node)
            when is_tuple(node) and elem(node, 0) in [:tag, :local_component, :remote_component]

  @doc """
  Maps over the tokens and invokes the given function for each token.
  """
  @spec map_tokens(tokens(), (token() -> token())) :: tokens()
  def map_tokens(tokens, fun) when is_function(fun, 1) do
    Enum.flat_map(tokens, fn token ->
      case fun.(token) do
        :drop -> []
        token -> [token]
      end
    end)
  end

  @doc """
  Returns a map of attributes from a node.

  ## Examples

      iex> attributes(node)
      %{"class" => {:string, "foo"}, "id" => {:expr, ...}}

  """
  @spec attributes(token()) :: map()
  def attributes(token) when is_tag_or_component(token) do
    {_, _, attrs, _} = token

    for {name, {type, value, _}, _} <- attrs,
        into: %{},
        do: {name, {type, value}}
  end

  def attributes(_token, _key), do: nil

  @doc """
  Removes an attribute from a node.
  """
  def drop_attribute(token, key) when is_tag_or_component(token) do
    {type, name, attrs, meta} = token
    {type, name, Enum.reject(attrs, fn {k, _, _} -> k == key end), meta}
  end

  def drop_attribute(_token, _key), do: nil

  @doc """
  Replaces an attribute with a new value, if it is set.
  """
  def replace_attribute(token, key, value) when is_binary(value) and is_tag_or_component(token) do
    {type, name, attrs, meta} = token

    {type, name,
     Enum.map(attrs, fn
       {^key, {_t, _v, m1}, m2} -> {key, {:string, value, m1}, m2}
       attr -> attr
     end), meta}
  end

  def replace_attribute(_token, _key, value) when not is_binary(value) do
    raise ArgumentError, "value must be a binary, got: #{inspect(value)}"
  end

  def replace_attribute(token, _key, _value), do: token

  @doc """
  Replaces an attribute with a new value, if it is set.
  """
  def replace_attribute(token, key, existing_string_value, new_string_value)
      when is_binary(existing_string_value) and is_binary(new_string_value) and
             is_tag_or_component(token) do
    {type, name, attrs, meta} = token

    {type, name,
     Enum.map(attrs, fn
       {^key, {:string, ^existing_string_value, m1}, m2} ->
         {key, {:string, new_string_value, m1}, m2}

       attr ->
         attr
     end), meta}
  end

  def replace_attribute(token, _key, _existing_value, _new_value)
      when is_tag_or_component(token) do
    raise ArgumentError, "existing and new values must be a binaries"
  end

  def replace_attribute(token, _key, _existing_value, _new_value), do: token

  @doc """
  Sets an attribute on a node. Only supports string values.

  If an existing attribute is set, it will be removed first.
  """
  def set_attribute(token, key, value) when is_binary(value) and is_tag_or_component(token) do
    {type, name, attrs, meta} = drop_attribute(token, key)

    {type, name,
     [
       {key, {:string, value, %{delimiter: ?", line: 0, column: 0}}, %{line: 0, column: 0}}
       | attrs
     ], meta}
  end

  def set_attribute(token, _key, _value), do: token
end
