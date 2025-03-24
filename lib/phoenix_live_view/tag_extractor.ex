defprotocol Phoenix.LiveView.TagExtractor do
  @moduledoc """
  A protocol for extracting content from tags at compile time.

  Used for implementing colocated hooks.

  Any data structure can implement this protocol and then be used
  in the HEEx `:extract` attribute. It is passed as first argument
  to the protocol callbacks.
  """

  @doc """
  The function for extracting the content of a tag.

  Called with the data passed to `:extract`, the attributes and text
  content of the tag on which `:extract` is used, as well as a meta
  map with keys `[:file, :line, :column, :module]`.

  The extract can return:

    * `{:keep, new_attributes, new_text_content, state}` to keep the tag in the DOM
       with optional new attributes and text content.

    * `{:drop, state}` to drop the tag from the DOM.

  The state value returned by `extract` is passed to `postprocess_tokens/3` and `prune/2`.
  """
  def extract(data, attributes, text_content, meta)

  @doc """
  Custom postprocessing of all tokens of the current component.

  Useful to inject or modify attributes.
  Must return the same or updated list of tokens.
  """
  def postprocess_tokens(data, state, tokens)

  @doc """
  Called when a specific extraction was removed to perform
  optional cleanup.
  """
  def prune(data, state)
end
