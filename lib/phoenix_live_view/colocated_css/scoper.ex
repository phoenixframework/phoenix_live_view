defmodule Phoenix.LiveView.ColocatedCSS.Scoper do
  @moduledoc """
  A behaviour for scoping Colocated CSS.
  """

  @doc """
  Callback invoked for each colocated CSS tag.

  The callback receives the tag name, the string attributes and a map of metadata.

  For example, for the following tag:

  ```heex
  <style :type={Phoenix.LiveView.ColocatedCSS} data-scope="my-scope" foo={@bar}>
    .my-class { color: red; }
  </style>
  ```

  The callback would receive the following arguments:

    * tag_name: `"style"`
    * attrs: %{"data-scope" => "my-scope"}
    * meta: `%{file: "path/to/file.ex", module: MyApp.MyModule, line: 10}`

  The callback must return either `{:ok, scoped_css, directives}` or `{:error, reason}`.
  If an error is returned, it will be logged and the CSS will not be extracted.

  The `directives` needs to be a keyword list that supports the following options:

    * `root_tag_attribute`: A `{key, value}` tuple that will be added a
       an attribute to all "root tags" of the template defining the scoped CSS tag.
       See the section on root tags below for more information.
    * `tag_attribute`: A `{key, value}` tuple that will be added as an attribute to
       all HTML tags in the template defining the scoped CSS tag.

  ## Root tags

  In a HEEx template, all outermost tags are considered "root tags" and are
  affected by the `root_tag_attribute` directive. If a template uses components,
  the slots of those components are considered as root tags as well.

  Here's an example showing which elements would be considered root tags:

  ```heex
  <div>                              <---- root tag
    <span>Hello</span>               <---- not a root tag

    <.my_component>
      <p>World</p>                   <---- root tag
    </.my_component>
  </div>

  <.my_component>
    <span>World</span>               <---- root tag

    <:a_named_slot>
      <div>                          <---- root tag
        Foo
        <p>Bar</p>                   <---- not a root tag
      </div>
    </:a_named_slot>
  </.my_component>
  ```
  """
  @callback scope(tag_name :: binary(), attrs :: map(), css :: binary(), meta :: keyword()) ::
              {:ok, binary(), keyword()} | {:error, term()}
end
