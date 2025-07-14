defmodule Phoenix.LiveView.ColocatedHook do
  @moduledoc ~S'''
  A special HEEx `:type` that extracts [hooks](js-interop.md#client-hooks-via-phx-hook)
  from a co-located `<script>` tag at compile time.

  Note: To use `ColocatedHook`, you need to run Phoenix 1.8+.

  ## Introduction

  Colocated hooks are defined as with `:type={Phoenix.LiveView.ColocatedHook}`:

      defmodule MyAppWeb.DemoLive do
        use MyAppWeb, :live_view

        def mount(_params, _session, socket) do
          {:ok, socket}
        end

        def render(assigns) do
          ~H"""
          <input type="text" name="user[phone_number]" id="user-phone-number" phx-hook=".PhoneNumber" />
          <script :type={Phoenix.LiveView.ColocatedHook} name=".PhoneNumber">
            export default {
              mounted() {
                this.el.addEventListener("input", e => {
                  let match = this.el.value.replace(/\D/g, "").match(/^(\d{3})(\d{3})(\d{4})$/)
                  if(match) {
                    this.el.value = `${match[1]}-${match[2]}-${match[3]}`
                  }
                })
              }
            }
          </script>
          """
        end
      end

  You can read more about the internals of colocated hooks in the [documentation for colocated JS](`Phoenix.LiveView.ColocatedJS#internals`).
  A brief summary: at compile time, the hook's code is extracted into a special folder, typically in your `_build` directory.
  Each hook is also `import`ed into a special *manifest* file. The manifest file provides
  [a named export](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Statements/export)
  which allows it to be imported by any JavaScript bundler that supports [ES modules](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Modules):

  ```javascript
  import {hooks} from "phoenix-colocated/my_app"

  console.log(hooks);
  /*
  {
    "MyAppWeb.DemoLive.PhoneNumber": {...},
    ...
  }
  */
  ```

  > #### Compilation order {: .info}
  >
  > Colocated hooks are only written when the corresponding component is compiled.
  > Therefore, whenever you need to access a colocated hook, you need to ensure
  > `mix compile` runs first. This automatically happens in development.
  >
  > If you have a custom mix alias, instead of
  >     release: ["assets.deploy", "release"]
  > do
  >     release: ["compile", "assets.deploy", "release"]
  > to ensure that all colocated hooks are extracted before esbuild or any other bundler runs.

  ## Options

  Colocated hooks are configured through the attributes of the `<script>` tag.
  The supported attributes are:

    * `name` - The name of the hook. This is required and must start with a dot,
      for example: `name=".myhook"`. The same name must be used when referring to this
      hook in the `phx-hook` attribute of another HTML element.

    * `runtime` - If present, the hook is not extracted, but instead registered at runtime.
      You should only use this option if you know that you need it. It comes with some limitations:

        1. The content is not processed by any bundler, therefore it must only use features
           supported by the targeted browsers.
        2. You need to take special care about any [Content Security Policies](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CSP)
           that may be in place. See the section on runtime hooks below for more details.

  ## Runtime hooks

  Runtime hooks are a special kind of colocated hook that are not removed from the DOM
  when rendering the component. Instead, the hook's code is executed directly in the
  browser with no bundler involved.

  One example where this can be useful is when you are creating a custom page for a library
  like `Phoenix.LiveDashboard`. The live dashboard already bundles its hooks, therefore there
  is no way to add new hooks to the bundle when the live dashboard is used inside your application.

  Because of this, runtime hooks must also use a slightly different syntax. While in normal
  colocated hooks you'd write an `export default` statement, runtime hooks must evaluate to the
  hook itself:

  ```heex
  <script :type={Phoenix.LiveView.ColocatedHook} name=".MyHook" runtime>
    {
      mounted() {
        ...
      }
    }
  </script>
  ```

  This is because the hook's code is wrapped by LiveView into something like this:

  ```javascript
  window["phx_hook_HASH"] = function() {
    return {
      mounted() {
        ...
      }
    }
  }
  ```

  Still, even for runtime hooks, the hook's name needs to start with a dot and is automatically
  prefixed with the module name to avoid conflicts with other hooks.

  When using runtime hooks, it is important to think about any limitations that content security
  policies may impose. If CSP is involved, the only way to use runtime hooks is by using CSP nonces:

  ```heex
  <script :type={Phoenix.LiveView.ColocatedHook} name=".MyHook" runtime nonce={@script_csp_nonce}>
    function() {
      return ...;
    }
  </script>
  ```

  This is assuming that the `@script_csp_nonce` assign contains the nonce value that is also
  sent in the `Content-Security-Policy` header.
  '''

  @behaviour Phoenix.Component.MacroComponent

  @impl true
  def transform({"script", attributes, [text_content], _tag_meta} = _ast, meta) do
    validate_phx_version!()

    opts = Map.new(attributes)

    name =
      case opts do
        %{"name" => "." <> name} ->
          "#{inspect(meta.env.module)}.#{name}"

        %{"name" => name} when is_binary(name) ->
          raise ArgumentError,
                """
                colocated hook names must start with a dot, invalid hook name: #{name}

                Hint: name your hook <script :type={ColocatedHook} name=".#{name}" ...>
                """

        %{"name" => name} ->
          raise ArgumentError,
                "the name attribute of a colocated hook must be a compile-time string. Got: #{Macro.to_string(name)}"

        %{} ->
          raise ArgumentError, "missing required name attribute for ColocatedHook"
      end

    case opts do
      %{"runtime" => _} ->
        new_content = """
        window["phx_hook_#{Phoenix.HTML.javascript_escape(name)}"] = function() {
          return #{String.trim_leading(text_content)}
        }
        """

        attrs = Enum.to_list(Map.drop(opts, ["name", "runtime"]))
        {:ok, {"script", [{"data-phx-runtime-hook", name} | attrs], [new_content], %{}}}

      _ ->
        # a colocated hook is just a special type of colocated JS,
        # exported under the top-level `hooks` key.
        opts =
          opts
          |> Map.put("key", "hooks")
          |> Map.put("name", name)

        data = Phoenix.LiveView.ColocatedJS.extract(opts, text_content, meta)
        {:ok, "", data}
    end
  end

  def transform(_ast, _meta) do
    raise ArgumentError, "a ColocatedHook can only be defined on script tags"
  end

  defp validate_phx_version! do
    phoenix_version = to_string(Application.spec(:phoenix, :vsn))

    if not Version.match?(phoenix_version, "~> 1.8.0-rc.4") do
      # TODO: bump message to 1.8 once released to avoid confusion
      raise ArgumentError, ~s|ColocatedHook requires at least {:phoenix, "~> 1.8.0-rc.4"}|
    end
  end
end
