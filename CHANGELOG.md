# Changelog for v1.3

## Enhancements

* Do not execute `phx-disconnected` commands while the page is hidden. When the page becomes visible again, wait for the new `disconnectedResumeTimeout` LiveSocket option (2000ms by default) so the immediate reconnect can finish before showing disconnected UI.

## Bug fixes

* Use `phx-client-error` instead of `phx-server-error` when joining a LiveView times out or fails in the transport, as the server could not be reached.

## v1.2

The CHANGELOG for v1.2 releases can be found [in the v1.2 branch](https://github.com/phoenixframework/phoenix_live_view/blob/v1.2/CHANGELOG.md).
