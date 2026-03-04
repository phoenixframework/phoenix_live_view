# Changelog for v1.2

## v1.2.0-rc.0 (Unreleased)

### Enhancements

* Add `phx-no-unused-field` to prevent sending `_unused` parameters to the server ([#3577](https://github.com/phoenixframework/phoenix_live_view/issues/3577))
* Add `Phoenix.LiveView.JS.to_encodable/1` pushing JS commands via events ([#4060](https://github.com/phoenixframework/phoenix_live_view/pull/4060))
  * `%JS{}` now also implements the `JSON.Encoder` and `Jason.Encoder` protocols
* HTMLFormatter: Better preserve whitespace around tags and inside inline elements ([#3718](https://github.com/phoenixframework/phoenix_live_view/issues/3718))
* HEEx: Allow to opt out of debug annotations for a module ([#4119](https://github.com/phoenixframework/phoenix_live_view/pull/4119))
* HEEx: warn when missing a space between attributes ([#3999](https://github.com/phoenixframework/phoenix_live_view/issues/3999))
* HTMLFormatter: Add `TagFormatter` behaviour for formatting `<style>` and `<script>` tags ([#4140](https://github.com/phoenixframework/phoenix_live_view/pull/4140))

## v1.1

The CHANGELOG for v1.1 releases can be found [in the v1.1 branch](https://github.com/phoenixframework/phoenix_live_view/blob/v1.1/CHANGELOG.md).
