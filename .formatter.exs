[
  import_deps: [:phoenix],
  plugins: [Phoenix.LiveView.HTMLFormatter],
  inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: [
    assert_patch: :*,
    assert_patched: :*,
    assert_push_event: :*,
    assert_redirect: :*,
    assert_redirected: :*,
    assert_reply: :*
  ]
]
