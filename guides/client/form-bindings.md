# Form bindings

## Form events

To handle form changes and submissions, use the `phx-change` and `phx-submit`
events. In general, it is preferred to handle input changes at the form level,
where all form fields are passed to the LiveView's callback given any
single input change. For example, to handle real-time form validation and
saving, your form would use both `phx-change` and `phx-submit` bindings.
Let's get started with an example:

```heex
<.form for={@form} id="my-form" phx-change="validate" phx-submit="save">
  <.input type="text" field={@form[:username]} />
  <.input type="email" field={@form[:email]} />
  <button>Save</button>
</.form>
```

`.form` is the function component defined in `Phoenix.Component.form/1`,
we recommend reading its documentation for more details on how it works
and all supported options. `.form` expects a `@form` assign, which can
be created from a changeset or user parameters via `Phoenix.Component.to_form/1`.

`input/1` is a function component for rendering inputs, most often
defined in your own application, often encapsulating labelling,
error handling, and more. Here is a simple version to get started with:

    attr :field, Phoenix.HTML.FormField
    attr :rest, :global, include: ~w(type)
    def input(assigns) do
      ~H"""
      <input id={@field.id} name={@field.name} value={@field.value} {@rest} />
      """
    end

> ### The `CoreComponents` module {: .info}
>
> If your application was generated with Phoenix v1.7, then `mix phx.new`
> automatically imports many ready-to-use function components, such as
> `.input` component with built-in features and styles.

With the form rendered, your LiveView picks up the events in `handle_event`
callbacks, to validate and attempt to save the parameter accordingly:

    def render(assigns) ...

    def mount(_params, _session, socket) do
      {:ok, assign(socket, form: to_form(Accounts.change_user(%User{})))}
    end

    def handle_event("validate", %{"user" => params}, socket) do
      form =
        %User{}
        |> Accounts.change_user(params)
        |> to_form(action: :validate)

      {:noreply, assign(socket, form: form)}
    end

    def handle_event("save", %{"user" => user_params}, socket) do
      case Accounts.create_user(user_params) do
        {:ok, user} ->
          {:noreply,
           socket
           |> put_flash(:info, "user created")
           |> redirect(to: ~p"/users/#{user}")}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, form: to_form(changeset))}
      end
    end

The validate callback simply updates the changeset based on all form input
values, then convert the changeset to a form and assign it to the socket.
If the form changes, such as generating new errors, [`render/1`](`c:Phoenix.LiveView.render/1`)
is invoked and the form is re-rendered.

Likewise for `phx-submit` bindings, the same callback is invoked and
persistence is attempted. On success, a `:noreply` tuple is returned and the
socket is annotated for redirect with `Phoenix.LiveView.redirect/2` to
the new user page, otherwise the socket assigns are updated with the errored
changeset to be re-rendered for the client.

You may wish for an individual input to use its own change event or to target
a different component. This can be accomplished by annotating the input itself
with `phx-change`, for example:

```heex
<.form for={@form} id="my-form" phx-change="validate" phx-submit="save">
  ...
  <.input field={@form[:email]} phx-change="email_changed" phx-target={@myself} />
</.form>
```

Then your LiveView or LiveComponent would handle the event:

```elixir
def handle_event("email_changed", %{"user" => %{"email" => email}}, socket) do
  ...
end
```

> #### Note {: .warning}
> 1. Only the individual input is sent as params for an input marked with `phx-change`.
> 2. While it is possible to use `phx-change` on individual inputs, those inputs
>    must still be within a form.

## Error feedback

For proper error feedback on form updates, LiveView sends special parameters on form events
starting with `_unused_` to indicate that the input for the specific field has not been interacted with yet.

When creating a form from these parameters through `Phoenix.Component.to_form/2` or `Phoenix.Component.form/1`,
`Phoenix.Component.used_input?/1` can be used to filter error messages.

For example, your `MyAppWeb.CoreComponents` may use this function:

```elixir
def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
  errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

  assigns
  |> assign(field: nil, id: assigns.id || field.id)
  |> assign(:errors, Enum.map(errors, &translate_error(&1)))
```

Now only errors for fields that were interacted with are shown.

To disable sending of `_unused` parameters, you can annotate individual inputs or the whole form with
`phx-no-usage-tracking`.

## Number inputs

Number inputs are a special case in LiveView forms. On programmatic updates,
some browsers will clear invalid inputs. So LiveView will not send change events
from the client when an input is invalid, instead allowing the browser's native
validation UI to drive user interaction. Once the input becomes valid, change and
submit events will be sent normally.

```heex
<input type="number">
```

This is known to have a plethora of problems including accessibility, large numbers
are converted to exponential notation, and scrolling can accidentally increase or
decrease the number.

One alternative is the `inputmode` attribute, which may serve your application's needs
and users much better. According to [Can I Use?](https://caniuse.com/#search=inputmode),
the following is supported by 94% of the global market (as of Nov 2024):

```heex
<input type="text" inputmode="numeric" pattern="[0-9]*">
```

## Password inputs

Password inputs are also special cased in `Phoenix.HTML`. For security reasons,
password field values are not reused when rendering a password input tag. This
requires explicitly setting the `:value` in your markup, for example:

```heex
<.input field={f[:password]} value={input_value(f[:password].value)} />
<.input field={f[:password_confirmation]} value={input_value(f[:password_confirmation].value)} />
```

## Nested inputs

Nested inputs are handled using `.inputs_for` function component. By default
it will add the necessary hidden input fields for tracking ids of Ecto associations.

```heex
<.inputs_for :let={fp} field={f[:friends]}>
  <.input field={fp[:name]} type="text" />
</.inputs_for>
```

## File inputs

LiveView forms support [reactive file inputs](uploads.md),
including drag and drop support via the `phx-drop-target`
attribute:

```heex
<div class="container" phx-drop-target={@uploads.avatar.ref}>
  ...
  <.live_file_input upload={@uploads.avatar} />
</div>
```

See `Phoenix.Component.live_file_input/1` for more.

## Submitting the form action over HTTP

The `phx-trigger-action` attribute can be added to a form to trigger a standard
form submit on DOM patch to the URL specified in the form's standard `action`
attribute. This is useful to perform pre-final validation of a LiveView form
submit before posting to a controller route for operations that require
Plug session mutation. For example, in your LiveView template you can
annotate the `phx-trigger-action` with a boolean assign:

```heex
<.form :let={f} for={@changeset}
  action={~p"/users/reset_password"}
  phx-submit="save"
  phx-trigger-action={@trigger_submit}>
```

Then in your LiveView, you can toggle the assign to trigger the form with the current
fields on next render:

    def handle_event("save", params, socket) do
      case validate_change_password(socket.assigns.user, params) do
        {:ok, changeset} ->
          {:noreply, assign(socket, changeset: changeset, trigger_submit: true)}

        {:error, changeset} ->
          {:noreply, assign(socket, changeset: changeset)}
      end
    end

Once `phx-trigger-action` is true, LiveView disconnects and then submits the form.

## Recovery following crashes or disconnects

By default, all forms marked with `phx-change` and having `id`
attribute will recover input values automatically after the user has
reconnected or the LiveView has remounted after a crash. This is
achieved by the client triggering the same `phx-change` to the server
as soon as the mount has been completed.

**Note:** if you want to see form recovery working in development, please
make sure to disable live reloading in development by commenting out the
LiveReload plug in your `endpoint.ex` file or by setting `code_reloader: false`
in your `config/dev.exs`. Otherwise live reloading may cause the current page
to be reloaded whenever you restart the server, which will discard all form
state.

For most use cases, this is all you need and form recovery will happen
without consideration. In some cases, where forms are built step-by-step in a
stateful fashion, it may require extra recovery handling on the server outside
of your existing `phx-change` callback code. To enable specialized recovery,
provide a `phx-auto-recover` binding on the form to specify a different event
to trigger for recovery, which will receive the form params as usual. For example,
imagine a LiveView wizard form where the form is stateful and built based on what
step the user is on and by prior selections:

```heex
<form id="wizard" phx-change="validate_wizard_step" phx-auto-recover="recover_wizard">
```

On the server, the `"validate_wizard_step"` event is only concerned with the
current client form data, but the server maintains the entire state of the wizard.
To recover in this scenario, you can specify a recovery event, such as `"recover_wizard"`
above, which would wire up to the following server callbacks in your LiveView:

    def handle_event("validate_wizard_step", params, socket) do
      # regular validations for current step
      {:noreply, socket}
    end

    def handle_event("recover_wizard", params, socket) do
      # rebuild state based on client input data up to the current step
      {:noreply, socket}
    end

To forgo automatic form recovery, set `phx-auto-recover="ignore"`.

## Resetting forms

To reset a LiveView form, you can use the standard `type="reset"` on a
form button or input. When clicked, the form inputs will be reset to their
original values.
After the form is reset, a `phx-change` event is emitted with the `_target` param
containing the reset `name`. For example, the following element:

```heex
<form id="my-form" phx-change="changed">
  ...
  <button type="reset" name="reset">Reset</button>
</form>
```

Can be handled on the server differently from your regular change function:

    def handle_event("changed", %{"_target" => ["reset"]} = params, socket) do
      # handle form reset
    end

    def handle_event("changed", params, socket) do
      # handle regular form change
    end

## JavaScript client specifics

The JavaScript client is always the source of truth for current input values.
For any given input with focus, LiveView will never overwrite the input's current
value, even if it deviates from the server's rendered updates. This works well
for updates where major side effects are not expected, such as form validation
errors, or additive UX around the user's input values as they fill out a form.

For these use cases, the `phx-change` input does not concern itself with disabling
input editing while an event to the server is in flight. When a `phx-change` event
is sent to the server, the input tag and parent form tag receive the
`phx-change-loading` CSS class, then the payload is pushed to the server with a
`"_target"` param in the root payload containing the keyspace of the input name
which triggered the change event.

For example, if the following input triggered a change event:

```heex
<input name="user[username]"/>
```

The server's `handle_event/3` would receive a payload:

    %{"_target" => ["user", "username"], "user" => %{"username" => "Name"}}

The `phx-submit` event is used for form submissions where major side effects
typically happen, such as rendering new containers, calling an external
service, or redirecting to a new page.

On submission of a form bound with a `phx-submit` event:

1. The form's inputs are set to `readonly`
2. Any submit button on the form is disabled
3. The form receives the `"phx-submit-loading"` class

On completion of server processing of the `phx-submit` event:

1. The submitted form is reactivated and loses the `"phx-submit-loading"` class
2. The last input with focus is restored (unless another input has received focus)
3. Updates are patched to the DOM as usual

To handle latent events, the `<button>` tag of a form can be annotated with
`phx-disable-with`, which swaps the element's `innerText` with the provided
value during event submission. For example, the following code would change
the "Save" button to "Saving...", and restore it to "Save" on acknowledgment:

```heex
<button type="submit" phx-disable-with="Saving...">Save</button>
```

> #### A note on disabled buttons {: .info}
>
> By default, LiveView only disables submit buttons and inputs within forms
> while waiting for a server acknowledgement. If you want a button outside of
> a form to be disabled without changing its text, you can add `phx-disable-with`
> without a value:
>
> ```heex
>  <button type="button" phx-disable-with>...</button>
> ```
>
> Note also that LiveView ignores clicks on elements that are currently awaiting
> an acknowledgement from the server. This means that although a regular button
> without `phx-disable-with` is not semantically disabled while waiting for a
> server response, it will not trigger duplicate events.
>
> Finally, `phx-disable-with` works with an element‘s `innerText`,
> therefore nested DOM elements, like `svg` or icons, won't be preserved.
> See "CSS loading states" for alternative approaches to this.

You may also take advantage of LiveView's CSS loading state classes to
swap out your form content while the form is submitting. For example,
with the following rules in your `app.css`:

```css
.while-submitting { display: none; }
.inputs { display: block; }

.phx-submit-loading .while-submitting { display: block; }
.phx-submit-loading .inputs { display: none; }
```

You can show and hide content with the following markup:

```heex
<form id="my-form" phx-change="update">
  <div class="while-submitting">Please wait while we save our content...</div>
  <div class="inputs">
    <input type="text" name="text" value={@text}>
  </div>
</form>
```

Additionally, we strongly recommend including a unique HTML "id" attribute on the form.
When DOM siblings change, elements without an ID will be replaced rather than moved,
which can cause issues such as form fields losing focus.

## Triggering `phx-` form events with JavaScript

Often it is desirable to trigger an event on a DOM element without explicit
user interaction on the element. For example, a custom form element such as a
date picker or custom select input which utilizes a hidden input element to
store the selected state.

In these cases, the event functions on the DOM API can be used, for example
to trigger a `phx-change` event:

```javascript
document.getElementById("my-select").dispatchEvent(
  new Event("input", {bubbles: true})
)
```

When using a client hook, `this.el` can be used to determine the element as
outlined in the "Client hooks" documentation.

It is also possible to trigger a `phx-submit` using a "submit" event:

```javascript
document.getElementById("my-form").dispatchEvent(
  new Event("submit", {bubbles: true, cancelable: true})
)
```

## Preventing form submission with JavaScript

In some cases, you may want to conditionally prevent form submission based on client-side validation or other business logic before allowing a `phx-submit` to be processed by the server.

JavaScript can be used to prevent the default form submission behavior, for example with a [hook](js-interop.md#client-hooks-via-phx-hook):

```javascript
/**
 * @type {import("phoenix_live_view").HooksOptions}
 */
let Hooks = {}
Hooks.CustomFormSubmission = {
  mounted() {
    this.el.addEventListener("submit", (event) => {
      if (!this.shouldSubmit()) {
        // prevent the event from bubbling to the default LiveView handler
        event.stopPropagation()
        // prevent the default browser behavior (submitting the form over HTTP)
        event.preventDefault()
      }
    })
  },
  shouldSubmit() {
    // Check if we should submit the form
    ...
  }
}
```

This hook can be set on your form as such:

```heex
<form id="my-form" phx-hook="CustomFormSubmission">
  <input type="text" name="text" value={@text}>
</form>
```
