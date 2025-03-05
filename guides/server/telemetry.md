# Telemetry

LiveView currently exposes the following [`telemetry`](https://hexdocs.pm/telemetry) events:

  * `[:phoenix, :live_view, :mount, :start]` - Dispatched by a `Phoenix.LiveView`
    immediately before [`mount/3`](`c:Phoenix.LiveView.mount/3`) is invoked.

    * Measurement:

          %{system_time: System.monotonic_time}

    * Metadata:

          %{
            socket: Phoenix.LiveView.Socket.t,
            params: unsigned_params | :not_mounted_at_router,
            session: map,
            uri: String.t() | nil
          }

  * `[:phoenix, :live_view, :mount, :stop]` - Dispatched by a `Phoenix.LiveView`
    when the [`mount/3`](`c:Phoenix.LiveView.mount/3`) callback completes successfully.

    * Measurement:

          %{duration: native_time}

    * Metadata:

          %{
            socket: Phoenix.LiveView.Socket.t,
            params: unsigned_params | :not_mounted_at_router,
            session: map,
            uri: String.t() | nil
          }

  * `[:phoenix, :live_view, :mount, :exception]` - Dispatched by a `Phoenix.LiveView`
    when an exception is raised in the [`mount/3`](`c:Phoenix.LiveView.mount/3`) callback.

    * Measurement: `%{duration: native_time}`

    * Metadata:

          %{
            socket: Phoenix.LiveView.Socket.t,
            kind: atom,
            reason: term,
            params: unsigned_params | :not_mounted_at_router,
            session: map,
            uri: String.t() | nil
          }

  * `[:phoenix, :live_view, :handle_params, :start]` - Dispatched by a `Phoenix.LiveView`
    immediately before [`handle_params/3`](`c:Phoenix.LiveView.handle_params/3`) is invoked.

    * Measurement:

          %{system_time: System.monotonic_time}

    * Metadata:

          %{
            socket: Phoenix.LiveView.Socket.t,
            params: unsigned_params,
            uri: String.t()
          }

  * `[:phoenix, :live_view, :handle_params, :stop]` - Dispatched by a `Phoenix.LiveView`
    when the [`handle_params/3`](`c:Phoenix.LiveView.handle_params/3`) callback completes successfully.

    * Measurement:

          %{duration: native_time}

    * Metadata:

          %{
            socket: Phoenix.LiveView.Socket.t,
            params: unsigned_params,
            uri: String.t()
          }

  * `[:phoenix, :live_view, :handle_params, :exception]` - Dispatched by a `Phoenix.LiveView`
    when an exception is raised in the [`handle_params/3`](`c:Phoenix.LiveView.handle_params/3`) callback.

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

  * `[:phoenix, :live_view, :handle_event, :start]` - Dispatched by a `Phoenix.LiveView`
    immediately before [`handle_event/3`](`c:Phoenix.LiveView.handle_event/3`) is invoked.

    * Measurement:

          %{system_time: System.monotonic_time}

    * Metadata:

          %{
            socket: Phoenix.LiveView.Socket.t,
            event: String.t(),
            params: unsigned_params
          }

  * `[:phoenix, :live_view, :handle_event, :stop]` - Dispatched by a `Phoenix.LiveView`
    when the [`handle_event/3`](`c:Phoenix.LiveView.handle_event/3`) callback completes successfully.

    * Measurement:

          %{duration: native_time}

    * Metadata:

          %{
            socket: Phoenix.LiveView.Socket.t,
            event: String.t(),
            params: unsigned_params
          }

  * `[:phoenix, :live_view, :handle_event, :exception]` - Dispatched by a `Phoenix.LiveView`
    when an exception is raised in the [`handle_event/3`](`c:Phoenix.LiveView.handle_event/3`) callback.

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

  * `[:phoenix, :live_view, :render, :start]` - Dispatched by a `Phoenix.LiveView`
    immediately before [`render/1`](`c:Phoenix.LiveComponent.render/1`) is invoked.

    * Measurement:

          %{system_time: System.monotonic_time}

    * Metadata:

          %{
            socket: Phoenix.LiveView.Socket.t,
            force?: boolean,
            changed?: boolean
          }

  * `[:phoenix, :live_view, :render, :stop]` - Dispatched by a `Phoenix.LiveView`
    when the [`render/1`](`c:Phoenix.LiveView.render/1`) callback completes successfully.

    * Measurement:

          %{duration: native_time}

    * Metadata:

          %{
            socket: Phoenix.LiveView.Socket.t,
            force?: boolean,
            changed?: boolean
          }

  * `[:phoenix, :live_view, :render, :exception]` - Dispatched by a `Phoenix.LiveView`
    when an exception is raised in the [`render/1`](`c:Phoenix.LiveView.render/1`) callback.

    * Measurement:

          %{duration: native_time}

    * Metadata:

          %{
            socket: Phoenix.LiveView.Socket.t,
            kind: atom,
            reason: term,
            force?: boolean,
            changed?: boolean
          }

  * `[:phoenix, :live_component, :update, :start]` - Dispatched by a `Phoenix.LiveComponent`
    immediately before [`update/2`](`c:Phoenix.LiveComponent.update/2`) or a
    [`update_many/1`](`c:Phoenix.LiveComponent.update_many/1`) is invoked.

    In the case of[`update/2`](`c:Phoenix.LiveComponent.update/2`) it might dispatch one event
    for multiple calls.

    * Measurement:

          %{system_time: System.monotonic_time}

    * Metadata:

          %{
            socket: Phoenix.LiveView.Socket.t,
            component: atom,
            assigns_sockets: [{map(), Phoenix.LiveView.Socket.t}]
          }

  * `[:phoenix, :live_component, :update, :stop]` - Dispatched by a `Phoenix.LiveComponent`
    when the [`update/2`](`c:Phoenix.LiveComponent.update/2`) or a
    [`update_many/1`](`c:Phoenix.LiveComponent.update_many/1`) callback completes successfully.

    In the case of[`update/2`](`c:Phoenix.LiveComponent.update/2`) it might dispatch one event
    for multiple calls. The `sockets` metadata contain the updated sockets.

    * Measurement:

          %{duration: native_time}

    * Metadata:

          %{
            socket: Phoenix.LiveView.Socket.t,
            component: atom,
            assigns_sockets: [{map(), Phoenix.LiveView.Socket.t}],
            sockets: [Phoenix.LiveView.Socket.t]
          }

  * `[:phoenix, :live_component, :update, :exception]` - Dispatched by a `Phoenix.LiveComponent`
    when an exception is raised in the [`update/2`](`c:Phoenix.LiveComponent.update/2`) or a
    [`update_many/1`](`c:Phoenix.LiveComponent.update_many/1`) callback.

    In the case of[`update/2`](`c:Phoenix.LiveComponent.update/2`) it might dispatch one event
    for multiple calls.

    * Measurement:

          %{duration: native_time}

    * Metadata:

          %{
            socket: Phoenix.LiveView.Socket.t,
            kind: atom,
            reason: term,
            component: atom,
            assigns_sockets: [{map(), Phoenix.LiveView.Socket.t}]
          }

  * `[:phoenix, :live_component, :handle_event, :start]` - Dispatched by a `Phoenix.LiveComponent`
    immediately before [`handle_event/3`](`c:Phoenix.LiveComponent.handle_event/3`) is invoked.

    * Measurement:

          %{system_time: System.monotonic_time}

    * Metadata:

          %{
            socket: Phoenix.LiveView.Socket.t,
            component: atom,
            event: String.t(),
            params: unsigned_params
          }

  * `[:phoenix, :live_component, :handle_event, :stop]` - Dispatched by a `Phoenix.LiveComponent`
    when the [`handle_event/3`](`c:Phoenix.LiveComponent.handle_event/3`) callback completes successfully.

    * Measurement:

          %{duration: native_time}

    * Metadata:

          %{
            socket: Phoenix.LiveView.Socket.t,
            component: atom,
            event: String.t(),
            params: unsigned_params
          }

  * `[:phoenix, :live_component, :handle_event, :exception]` - Dispatched by a `Phoenix.LiveComponent`
    when an exception is raised in the [`handle_event/3`](`c:Phoenix.LiveComponent.handle_event/3`) callback.

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
