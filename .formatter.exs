locals_without_parens = [
  attr: 2,
  attr: 3,
  embed_templates: 1,
  embed_templates: 2,
  slot: 1,
  slot: 2,
  slot: 3
]

[
  import_deps: [:phoenix],
  inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"],
  # TODO: Remove these on Phoenix v1.7 since Phoenix provides them already
  locals_without_parens: locals_without_parens,
  export: [locals_without_parens: locals_without_parens]
]
