locals_without_parens = [
  attr: 2,
  attr: 3,
  slot: 1,
  slot: 2,
  slot: 3
]

[
  import_deps: [:phoenix],
  inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"],
  # TODO remove these for 0.18 release since phoenix provides them already
  locals_without_parens: locals_without_parens,
  export: [locals_without_parens: locals_without_parens]
]
