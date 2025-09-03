defmodule Phoenix.LiveViewTest.Utils do
  @moduledoc false

  alias Phoenix.LiveViewTest.Upload

  def stringify(%Upload{}, _fun), do: %{}

  def stringify(%{__struct__: _} = struct, fun),
    do: stringify_value(struct, fun)

  def stringify(%{} = params, fun),
    do: Enum.into(params, %{}, &stringify_kv(&1, fun))

  def stringify([{_, _} | _] = params, fun),
    do: Enum.into(params, %{}, &stringify_kv(&1, fun))

  def stringify(params, fun) when is_list(params),
    do: Enum.map(params, &stringify(&1, fun))

  def stringify(other, fun),
    do: stringify_value(other, fun)

  def stringify_value(other, fun), do: fun.(other)
  def stringify_kv({k, v}, fun), do: {to_string(k), stringify(v, fun)}
end
