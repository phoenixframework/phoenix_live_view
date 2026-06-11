defmodule Phoenix.Component.QuotedTemplate do
  @moduledoc false

  # The value produced by `Phoenix.Component.quoted/1` once its unquote
  # fragments have been filled in: a parsed HEEx tree plus everything needed
  # to compile it later, at the use site, via
  # `Phoenix.Component.__compile_quoted__/1`.
  #
  # The node format is private to LiveView. This is fine because the struct
  # never crosses a LiveView version boundary: it is built when the macro
  # holding the template is compiled and consumed when the macro's caller is
  # compiled, both within the same project compilation and therefore with the
  # same LiveView version.

  defstruct [:nodes, :source, :file, :line, :indentation]
end
