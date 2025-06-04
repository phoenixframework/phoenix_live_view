# This test simulates the error condition from issue #3812
defmodule TestEmbedTemplateError do
  use Phoenix.Component

  # Simulating embed_templates which creates a function first
  def app(assigns), do: ~H"<div>embedded template</div>"

  # Then trying to define attributes after - this should trigger our improved error
  attr :test_attr, :string
end

# Try to compile this module to see our error message
try do
  Code.compile_quoted(
    quote do
      defmodule TestEmbedTemplateError2 do
        use Phoenix.Component

        # Simulating embed_templates which creates a function first
        def app(assigns), do: ~H"<div>embedded template</div>"

        # Then trying to define attributes after - this should trigger our improved error
        attr :test_attr, :string
      end
    end
  )
rescue
  e -> IO.puts("Error caught: #{Exception.message(e)}")
end
