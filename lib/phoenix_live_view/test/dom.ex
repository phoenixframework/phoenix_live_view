defmodule Phoenix.LiveViewTest.DOM do
  @moduledoc false

  @phx_component "data-phx-component"

  alias Phoenix.LiveViewTest.TreeDOM, as: Tree
  alias Plug.Conn.Query

  defguardp is_lazy(html) when is_struct(html, LazyHTML)

  def ensure_loaded! do
    if not Code.ensure_loaded?(LazyHTML) do
      raise """
      Phoenix LiveView requires lazy_html as a test dependency.
      Please add to your mix.exs:

      {:lazy_html, ">= 0.1.0", only: :test}
      """
    end
  end

  @spec parse_document(binary) :: {LazyHTML.t(), LazyHTML.Tree.t()}
  def parse_document(html, error_reporter \\ nil) do
    lazydoc = LazyHTML.from_document(html)
    tree = LazyHTML.to_tree(lazydoc)

    if is_function(error_reporter, 1) do
      detect_duplicate_ids(lazydoc, error_reporter)
    end

    {lazydoc, tree}
  end

  @spec parse_fragment(binary) :: {LazyHTML.t(), LazyHTML.Tree.t()}
  def parse_fragment(html, error_reporter \\ nil) do
    lazydoc = LazyHTML.from_fragment(html)
    tree = LazyHTML.to_tree(lazydoc)

    if is_function(error_reporter, 1) do
      detect_duplicate_ids(lazydoc, error_reporter)
    end

    {lazydoc, tree}
  end

  defp detect_duplicate_ids(lazydoc, error_reporter) do
    lazydoc
    |> LazyHTML.query("[id]")
    |> LazyHTML.attribute("id")
    |> Enum.frequencies()
    |> Enum.each(fn {id, count} ->
      if count > 1 do
        error_reporter.("""
        Duplicate id found while testing LiveView: #{id}

        #{lazydoc |> by_id!(id) |> to_tree() |> Tree.inspect_html()}

        LiveView requires that all elements have unique ids, duplicate IDs will cause
        undefined behavior at runtime, as DOM patching will not be able to target the correct
        elements.
        """)
      end
    end)
  end

  def all(lazy, selector) do
    LazyHTML.query(lazy, selector)
  end

  def maybe_one(lazy, selector, type \\ :selector) do
    result = all(lazy, selector)
    count = Enum.count(result)

    case count do
      1 ->
        {:ok, result}

      0 ->
        {:error, :none,
         "expected #{type} #{inspect(selector)} to return a single element, but got none " <>
           "within: \n\n" <> to_html(lazy)}

      _ ->
        {:error, :many,
         "expected #{type} #{inspect(selector)} to return a single element, " <>
           "but got #{count}: \n\n" <> to_html(result)}
    end
  end

  def targets_from_node(lazy, node) do
    case node && Tree.all_attributes(node, "phx-target") do
      nil -> [nil]
      [] -> [nil]
      [selector] -> targets_from_selector(lazy, selector)
    end
  end

  def targets_from_selector(lazy, selector)

  def targets_from_selector(_lazy, nil), do: [nil]

  def targets_from_selector(_lazy, cid) when is_integer(cid), do: [cid]

  def targets_from_selector(lazy, selector) when is_binary(selector) do
    case Integer.parse(selector) do
      {cid, ""} ->
        [cid]

      _ ->
        result =
          for element <- all(lazy, selector) do
            if cid = component_id(element) do
              String.to_integer(cid)
            end
          end

        if result == [] do
          [nil]
        else
          result
        end
    end
  end

  defp component_id(tree) do
    LazyHTML.attribute(tree, @phx_component)
    |> List.first()
  end

  def tag(node) do
    case LazyHTML.tag(node) do
      [tag | _] -> tag
      _ -> nil
    end
  end

  def attribute(node, key) do
    case LazyHTML.attribute(node, key) do
      [value | _] -> value
      _ -> nil
    end
  end

  def to_html(lazy) when is_lazy(lazy) do
    LazyHTML.to_html(lazy, skip_whitespace_nodes: true)
  end

  def to_text(node) do
    LazyHTML.text(node)
    |> String.replace(~r/[\s]+/, " ")
    |> String.trim()
  end

  def child_nodes(lazy) when is_lazy(lazy) do
    LazyHTML.child_nodes(lazy)
  end

  def by_id!(lazy, id) do
    LazyHTML.query_by_id(lazy, id)
  end

  @doc """
  Turns a lazy into a tree.
  """
  def to_tree(lazy, opts \\ []) when is_struct(lazy, LazyHTML), do: LazyHTML.to_tree(lazy, opts)

  @doc """
  Turns a tree into a lazy.
  """
  def to_lazy(tree), do: LazyHTML.from_tree(tree)

  @doc """
  Escapes a string for use as a CSS identifier.

  ## Examples

      iex> css_escape("hello world")
      "hello\\\\ world"

      iex> css_escape("-123")
      "-\\\\31 23"

  """
  @spec css_escape(String.t()) :: String.t()
  def css_escape(value) when is_binary(value) do
    # This is a direct translation of
    # https://github.com/mathiasbynens/CSS.escape/blob/master/css.escape.js
    # into Elixir.
    value
    |> String.to_charlist()
    |> escape_css_chars()
    |> IO.iodata_to_binary()
  end

  defp escape_css_chars(chars) do
    case chars do
      # If the character is the first character and is a `-` (U+002D), and
      # there is no second character, […]
      [?- | []] -> ["\\-"]
      _ -> escape_css_chars(chars, 0, [])
    end
  end

  defp escape_css_chars([], _, acc), do: Enum.reverse(acc)

  defp escape_css_chars([char | rest], index, acc) do
    escaped =
      cond do
        # If the character is NULL (U+0000), then the REPLACEMENT CHARACTER
        # (U+FFFD).
        char == 0 ->
          <<0xFFFD::utf8>>

        # If the character is in the range [\1-\1F] (U+0001 to U+001F) or is
        # U+007F,
        # if the character is the first character and is in the range [0-9]
        # (U+0030 to U+0039),
        # if the character is the second character and is in the range [0-9]
        # (U+0030 to U+0039) and the first character is a `-` (U+002D),
        char in 0x0001..0x001F or char == 0x007F or
          (index == 0 and char in ?0..?9) or
            (index == 1 and char in ?0..?9 and hd(acc) == "-") ->
          # https://drafts.csswg.org/cssom/#escape-a-character-as-code-point
          ["\\", Integer.to_string(char, 16), " "]

        # If the character is not handled by one of the above rules and is
        # greater than or equal to U+0080, is `-` (U+002D) or `_` (U+005F), or
        # is in one of the ranges [0-9] (U+0030 to U+0039), [A-Z] (U+0041 to
        # U+005A), or [a-z] (U+0061 to U+007A), […]
        char >= 0x0080 or char in [?-, ?_] or char in ?0..?9 or char in ?A..?Z or char in ?a..?z ->
          # the character itself
          <<char::utf8>>

        true ->
          # Otherwise, the escaped character.
          # https://drafts.csswg.org/cssom/#escape-a-character
          ["\\", <<char::utf8>>]
      end

    escape_css_chars(rest, index + 1, [escaped | acc])
  end

  ## Functions specific for LiveView

  @doc """
  Find static information in the given HTML tree.
  """
  def find_static_views(lazy) do
    all(lazy, "[data-phx-static]")
    |> Enum.into(%{}, fn node ->
      {attribute(node, "id"), attribute(node, "data-phx-static")}
    end)
  end

  ## Forms

  def all_value_inputs({"form", attrs, _} = form, root) do
    form_inputs = filtered_inputs(form)

    case Enum.into(attrs, %{}) do
      %{"id" => id} ->
        by_form_id = all(root, ~s<[form="#{id}"]>) |> to_tree()
        named_inputs = filtered_inputs(by_form_id)

        # All inputs including buttons
        # Remove the named inputs first to remove any possible
        # duplicates if the child inputs also had a form attribite.
        (form_inputs -- named_inputs) ++ named_inputs

      _ ->
        form_inputs
    end
  end

  def collect_form_values(form, root, done \\ &Query.decode_done/1) do
    form
    |> all_value_inputs(root)
    |> Enum.reduce(Query.decode_init(), &form_defaults/2)
    |> then(done)
  end

  def collect_input_values(node) do
    form_defaults(node, Query.decode_init()) |> Query.decode_done()
  end

  defp form_defaults(node, acc) do
    tag = Tree.tag(node)

    if name = Tree.attribute(node, "name") do
      form_defaults(tag, node, name, acc)
    else
      acc
    end
  end

  # Selectedness algorithm as outlined in
  # https://html.spec.whatwg.org/multipage/form-elements.html#the-select-element
  defp form_defaults("select", node, name, acc) do
    options = Tree.filter(node, &(Tree.tag(&1) == "option"))

    multiple_display_size =
      case valid_display_size(node) do
        int when is_integer(int) and int > 1 -> true
        _ -> false
      end

    all_selected =
      if Tree.attribute(node, "multiple") || multiple_display_size do
        Enum.filter(options, &Tree.attribute(&1, "selected"))
      else
        List.wrap(
          Enum.find(Enum.reverse(options), &Tree.attribute(&1, "selected")) ||
            Enum.find(options, &(!Tree.attribute(&1, "disabled")))
        )
      end

    Enum.reduce(all_selected, acc, fn selected, acc ->
      Plug.Conn.Query.decode_each({name, Tree.attribute(selected, "value")}, acc)
    end)
  end

  defp form_defaults("textarea", node, name, acc) do
    value = Tree.to_text(node, false)

    if value == "" do
      Plug.Conn.Query.decode_each({name, ""}, acc)
    else
      Plug.Conn.Query.decode_each({name, String.replace_prefix(value, "\n", "")}, acc)
    end
  end

  defp form_defaults("input", node, name, acc) do
    type = Tree.attribute(node, "type") || "text"
    value = Tree.attribute(node, "value") || default_value(type)

    cond do
      type in ["radio", "checkbox"] ->
        if Tree.attribute(node, "checked") do
          Plug.Conn.Query.decode_each({name, value}, acc)
        else
          acc
        end

      type in ["image", "submit"] ->
        acc

      true ->
        Plug.Conn.Query.decode_each({name, value}, acc)
    end
  end

  def default_value("checkbox"), do: "on"
  def default_value(_type), do: ""

  defp valid_display_size(node) do
    with size when not is_nil(size) <- Tree.attribute(node, "size"),
         {int, ""} when int > 0 <- Integer.parse(size) do
      int
    else
      _ -> nil
    end
  end

  defp filtered_inputs(nodes) do
    Tree.filter(nodes, fn node ->
      Tree.tag(node) in ~w(input textarea select) and
        is_nil(Tree.attribute(node, "disabled"))
    end)
  end
end
