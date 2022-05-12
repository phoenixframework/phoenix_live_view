locals_without_parens = [
  attr: 2,
  attr: 3,
  form: 1,
  link: 2,
  live_file_input: 1,
  live_file_input: 2,
  live_img_preview: 1,
  live_img_preview: 2,
  live_patch: 2,
  live_redirect: 2,
  live_render: 2,
  live_render: 3,
  live_title_tag: 1,
  live_title_tag: 2
]

[
  import_deps: [:phoenix],
  inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"],
  # TODO remove these for 0.18 release since phoenix provides them already
  locals_without_parens: locals_without_parens,
  export: [locals_without_parens: locals_without_parens]
]
