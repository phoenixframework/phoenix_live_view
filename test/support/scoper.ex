defmodule Phoenix.LiveViewTest.Support.CSSScoper do
  @behaviour Phoenix.LiveView.ColocatedCSS.Scoper

  @impl true
  def scope("style", attrs, css, meta) do
    validate_opts!(attrs)

    {scope, css} = do_scope(css, attrs, meta)

    {:ok, css, [root_tag_attribute: {"phx-css-#{scope}", true}]}
  end

  defp validate_opts!(opts) do
    Enum.each(opts, fn {key, val} -> validate_opt!({key, val}, Map.delete(opts, key)) end)
  end

  defp validate_opt!({"lower-bound", val}, _other_opts) when val in ["inclusive", "exclusive"] do
    :ok
  end

  defp validate_opt!({"lower-bound", val}, _other_opts) do
    raise ArgumentError,
          ~s|expected "inclusive" or "exclusive" for the `lower-bound` attribute of colocated css, got: #{inspect(val)}|
  end

  defp validate_opt!(_opt, _other_opts), do: :ok

  defp do_scope(css, opts, meta) do
    scope = hash("#{meta.module}_#{meta.line}: #{css}")

    root_tag_attribute = root_tag_attribute()

    upper_bound_selector = ~s|[phx-css-#{scope}]|
    lower_bound_selector = ~s|[#{root_tag_attribute}]|

    lower_bound_selector =
      case opts do
        %{"lower-bound" => "inclusive"} -> lower_bound_selector <> " > *"
        _ -> lower_bound_selector
      end

    css = "@scope (#{upper_bound_selector}) to (#{lower_bound_selector}) { #{css} }"

    {scope, css}
  end

  defp hash(string) do
    # It is important that we do not pad
    # the Base32 encoded value as we use it in
    # an HTML attribute name and = (the padding character)
    # is not valid.
    string
    |> then(&:crypto.hash(:md5, &1))
    |> Base.encode32(case: :lower, padding: false)
  end

  defp root_tag_attribute() do
    case Application.get_env(:phoenix_live_view, :root_tag_attribute) do
      configured_attribute when is_binary(configured_attribute) ->
        configured_attribute

      configured_attribute ->
        message = """
        a global :root_tag_attribute must be configured to use scoped css

        Expected global :root_tag_attribute to be a string, got: #{inspect(configured_attribute)}

        The global :root_tag_attribute is usually configured to `"phx-r"`, but it needs to be explicitly enabled in your configuration:

            config :phoenix_live_view, root_tag_attribute: "phx-r"

        You can also use a different value than `"phx-r"`.
        """

        raise ArgumentError, message
    end
  end
end
