# Telemetry

LiveView currently exposes the following [`telemetry`](https://hexdocs.pm/telemetry) events:

  * `[:phoenix, :live_view, :mount, :start]` - Dispatched by a `Phoenix.LiveView` immediately before `c:mount/3` is invoked.

    * Measurement:

          %{system_time: System.monotonic_time}

    * Metadata:

          %{
            socket: Phoenix.LiveView.Socket.t,
            params: unsigned_params | :not_mounted_at_router,
            session: map
          }


  * `[:phoenix, :live_view, :mount, :stop]` - Dispatched by a `Phoenix.LiveView` when the `c:mount/3` callback completes successfully.

    * Measurement:

          %{duration: native_time}

    * Metadata:

          %{
            socket: Phoenix.LiveView.Socket.t,
            params: unsigned_params | :not_mounted_at_router,
            session: map
          }


  * `[:phoenix, :live_view, :mount, :exception]` - Dispatched by a `Phoenix.LiveView` when an exception is raised in the `c:mount/3` callback.

    * Measurement: `%{duration: native_time}`

    * Metadata:

          %{
            socket: Phoenix.LiveView.Socket.t,
            kind: atom,
            reason: term,
            params: unsigned_params | :not_mounted_at_router,
            session: map
          }

  * `[:phoenix, :live_view, :handle_params, :start]` - Dispatched by a `Phoenix.LiveView` immediately before `c:handle_params/3` is invoked.

    * Measurement:

          %{system_time: System.monotonic_time}

    * Metadata:

          %{
            socket: Phoenix.LiveView.Socket.t,
            params: unsigned_params,
            uri: String.t()
          }


  * `[:phoenix, :live_view, :handle_params, :stop]` - Dispatched by a `Phoenix.LiveView` when the `c:handle_params/3` callback completes successfully.

    * Measurement:

          %{duration: native_time}

    * Metadata:

          %{
            socket: Phoenix.LiveView.Socket.t,
            params: unsigned_params,
            uri: String.t()
          }

  * `[:phoenix, :live_view, :handle_params, :exception]` - Dispatched by a `Phoenix.LiveView` when the when an exception is raised in the `c:handle_params/3` callback.

    * Measurement:

          %{duration: native_time}

    * Metadata:

          %{
            socket: Phoenix.LiveView.Socket.t,
            kind: atom,
            reason: term,
            params: unsigned_params,
            uri: String.t()
          }

  * `[:phoenix, :live_view, :handle_event, :start]` - Dispatched by a `Phoenix.LiveView` immediately before `c:handle_event/3` is invoked.

    * Measurement:

          %{system_time: System.monotonic_time}

    * Metadata:

          %{
            socket: Phoenix.LiveView.Socket.t,
            event: String.t(),
            params: unsigned_params
          }


  * `[:phoenix, :live_view, :handle_event, :stop]` - Dispatched by a `Phoenix.LiveView` when the `c:handle_event/3` callback completes successfully.

    * Measurement:

          %{duration: native_time}

    * Metadata:

          %{
            socket: Phoenix.LiveView.Socket.t,
            event: String.t(),
            params: unsigned_params
          }

  * `[:phoenix, :live_view, :handle_event, :exception]` - Dispatched by a `Phoenix.LiveView` when an exception is raised in the `c:handle_event/3` callback.

    * Measurement:

          %{duration: native_time}

    * Metadata:

          %{
            socket: Phoenix.LiveView.Socket.t,
            kind: atom,
            reason: term,
            event: String.t(),
            params: unsigned_params
          }

  * `[:phoenix, :live_component, :handle_event, :start]` - Dispatched by a `Phoenix.LiveComponent` immediately before `c:handle_event/3` is invoked.

    * Measurement:

          %{system_time: System.monotonic_time}

    * Metadata:

          %{
            socket: Phoenix.LiveView.Socket.t,
            component: atom,
            event: String.t(),
            params: unsigned_params
          }


  * `[:phoenix, :live_component, :handle_event, :stop]` - Dispatched by a `Phoenix.LiveComponent` when the `c:handle_event/3` callback completes successfully.

    * Measurement:

          %{duration: native_time}

    * Metadata:

          %{
            socket: Phoenix.LiveView.Socket.t,
            component: atom,
            event: String.t(),
            params: unsigned_params
          }

  * `[:phoenix, :live_component, :handle_event, :exception]` - Dispatched by a `Phoenix.LiveComponent` when an exception is raised in the `c:handle_event/3` callback.

    * Measurement:

          %{duration: native_time}

    * Metadata:

          %{
            socket: Phoenix.LiveView.Socket.t,
            kind: atom,
            reason: term,
            component: atom,
            event: String.t(),
            params: unsigned_params
          }
