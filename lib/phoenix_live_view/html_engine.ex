defmodule Phoenix.LiveView.HTMLEngine do
  @moduledoc """
  The HTMLEngine that powers `.heex` templates and the `~H` sigil.

  It works by adding a HTML parsing and validation layer on top
  of `Phoenix.HTML.TagEngine`.
  """

  @behaviour Phoenix.Template.Engine

  @impl true
  def compile(path, _name) do
    # We need access for the caller, so we return a call to a macro.
    quote do
      require Phoenix.LiveView.HTMLEngine
      Phoenix.LiveView.HTMLEngine.compile(unquote(path))
    end
  end

  @doc false
  defmacro compile(path) do
    trim = Application.get_env(:phoenix, :trim_on_html_eex_engine, true)
    source = File.read!(path)

    EEx.compile_string(source,
      engine: Phoenix.LiveView.TagEngine,
      line: 1,
      file: path,
      trim: trim,
      caller: __CALLER__,
      source: source,
      tag_handler: __MODULE__
    )
  end

  @behaviour Phoenix.LiveView.TagEngine

  @impl true
  def classify_type(":" <> name), do: {:slot, String.to_atom(name)}
  def classify_type(":inner_block"), do: {:error, "the slot name :inner_block is reserved"}

  def classify_type(<<first, _::binary>> = name) when first in ?A..?Z,
    do: {:remote_component, String.to_atom(name)}

  def classify_type("." <> name),
    do: {:local_component, String.to_atom(name)}

  def classify_type(name), do: {:tag, name}

  @impl true
  for void <- ~w(area base br col hr img input link meta param command keygen source) do
    def void?(unquote(void)), do: true
  end

  def void?(_), do: false
end
