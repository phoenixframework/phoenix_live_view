locals_without_parens = [
  attr: 2,
  attr: 3,
  live: 2,
  live: 3,
  live: 4,
  on_mount: 1,
  slot: 1,
  slot: 2,
  slot: 3
]

[
  locals_without_parens: locals_without_parens,
  import_deps: [:phoenix],
  inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"]
]
