defmodule Phoenix.LiveView.TagEngine.ParseResult do
  @moduledoc false

  defstruct [:nodes, :directives]

  @type t :: %__MODULE__{
          nodes: list(tag_node()),
          directives: keyword()
        }

  @type tag_node() :: text() | comment() | block() | self_close() | expression()
  @type text() :: {:text, binary(), meta()}
  @type comment() :: {:eex_comment, binary(), meta()}
  @type block() :: {:block, atom(), binary(), list(attr()), list(tag_node()), meta(), meta()}
  @type self_close() :: {:self_close, atom(), binary(), list(attr()), meta()}
  @type expression() ::
          {:body_expr, binary(), meta()}
          | {:eex, binary(), meta()}
          | {:eex_block, binary(), list(eex_clause()), meta()}
  @type eex_clause() :: {list(tag_node()), binary(), meta()}
  @type attr :: {:root | binary(), attr_value(), meta()}
  @type attr_value :: {:expr, binary(), meta()} | {:string, binary(), meta()}
  @type meta() :: map()
end
