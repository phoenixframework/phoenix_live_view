defmodule Phoenix.LiveView.TemplateTransformer do
  @moduledoc """
  Behaviour for compile-time HEEx template transformations.

  Transformers receive the parsed HEEx AST (`Phoenix.LiveView.TagEngine.Parser`)
  before LiveView compiles it into static/dynamic render chunks. This allows
  full-template rewrites (tags, attributes, text nodes, component calls, etc).

  Configure transformers globally:

      config :phoenix_live_view, :template_transformers, [
        MyAppWeb.TemplateTransformers.Foo,
        MyAppWeb.TemplateTransformers.Bar
      ]

  Transformers are executed in order. A transformer may return:

    * `{:ok, parser}` - transformed parser
    * `:noop` - no changes
    * `{:error, reason}` - abort compilation with a compile error (`reason` can be any term)

  The `context` map includes:

    * `:caller` - `Macro.Env` of the template caller
    * `:file` - template file path
    * `:line` - compile start line
    * `:source` - template source string
    * `:tag_handler` - tag engine handler module
  """

  @type context :: %{
          required(:caller) => Macro.Env.t(),
          required(:file) => String.t(),
          required(:line) => non_neg_integer(),
          required(:source) => String.t(),
          required(:tag_handler) => module()
        }

  @callback transform(Phoenix.LiveView.TagEngine.Parser.t(), context()) ::
              {:ok, Phoenix.LiveView.TagEngine.Parser.t()} | :noop | {:error, term()}
end
