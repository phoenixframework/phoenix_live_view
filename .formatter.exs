# Used by "mix format"
locals_without_parens = [
  # Phoenix.Router
  live: 2,
  live: 3
]

[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: locals_without_parens,
  export: [locals_without_parens: locals_without_parens]
]
