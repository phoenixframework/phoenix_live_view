defmodule Phoenix.LiveView.HTMLFormatterTest do
  use ExUnit.Case, async: true

  alias Phoenix.LiveView.HTMLFormatter

  defp assert_formatter_output(input, expected, dot_formatter_opts \\ []) do
    dot_formatter_opts =
      Keyword.put_new(dot_formatter_opts, :migrate_eex_to_curly_interpolation, false)

    first_pass = HTMLFormatter.format(input, dot_formatter_opts) |> IO.iodata_to_binary()
    assert first_pass == expected

    second_pass = HTMLFormatter.format(first_pass, dot_formatter_opts) |> IO.iodata_to_binary()
    assert second_pass == expected
  end

  def assert_formatter_doesnt_change(code, dot_formatter_opts \\ []) do
    dot_formatter_opts =
      Keyword.put_new(dot_formatter_opts, :migrate_eex_to_curly_interpolation, false)

    first_pass = HTMLFormatter.format(code, dot_formatter_opts) |> IO.iodata_to_binary()
    assert first_pass == code

    second_pass = HTMLFormatter.format(first_pass, dot_formatter_opts) |> IO.iodata_to_binary()
    assert second_pass == code
  end

  test "errors on invalid HTML" do
    assert_raise Phoenix.LiveView.Tokenizer.ParseError,
                 ~r/end of template reached without closing tag for <style>/,
                 fn -> assert_formatter_doesnt_change("<style>foo") end
  end

  test "always break lines for block elements" do
    input = """
      <section><h1><%= @user.name %></h1></section>
    """

    expected = """
    <section>
      <h1><%= @user.name %></h1>
    </section>
    """

    assert_formatter_output(input, expected)
  end

  test "keep inline elements in the current line" do
    input = """
      <section><h1><b><%= @user.name %></b></h1></section>
    """

    expected = """
    <section>
      <h1><b><%= @user.name %></b></h1>
    </section>
    """

    assert_formatter_output(input, expected)
  end

  test "break inline elements to the next line when it doesn't fit" do
    input = """
      <section><h1><b><%= @user.name %></b></h1></section>
    """

    expected = """
    <section>
      <h1>
        <b><%= @user.name %></b>
      </h1>
    </section>
    """

    assert_formatter_output(input, expected, line_length: 20)
  end

  test "break inline elements to the next line when it doesn't fit and element is empty" do
    input = """
      <section><h1><b class="there are several classes"></b></h1></section>
    """

    expected = """
    <section>
      <h1>
        <b class="there are several classes"></b>
      </h1>
    </section>
    """

    assert_formatter_output(input, expected, line_length: 20)
  end

  test "always break line for block elements" do
    input = """
    <h1>1</h1>
    <h2>2</h2>
    <h3>3</h3>
    """

    assert_formatter_doesnt_change(input)
  end

  test "do not break between EEx tags when there is no space before or after" do
    assert_formatter_output(
      """
      <p>first <%= @name %>second</p>
      """,
      """
      <p>
        first <%= @name %>second
      </p>
      """,
      line_length: 10
    )

    assert_formatter_output(
      """
      <p>first<%= @name %> second</p>
      """,
      """
      <p>
        first<%= @name %> second
      </p>
      """,
      line_length: 20
    )
  end

  test "do not break between inline tags when there is no space before or after" do
    assert_formatter_output(
      """
      <p>first <span>name</span>second</p>
      """,
      """
      <p>
        first <span>name</span>second
      </p>
      """,
      line_length: 10
    )

    assert_formatter_doesnt_change(
      """
      <p>first<span>name</span> second</p>
      """,
      line_length: 40
    )
  end

  test "remove unwanted empty lines" do
    input = """
    <section>
    <div>
    <h1>    Hello</h1>
    <h2>
    Sub title
    </h2>
    </div>
    </section>

    """

    expected = """
    <section>
      <div>
        <h1>Hello</h1>
        <h2>
          Sub title
        </h2>
      </div>
    </section>
    """

    assert_formatter_output(input, expected)
  end

  test "texts with inline elements and block elements" do
    input = """
    <div>
      Long long long loooooooooooong text: <i>...</i>
      <ul>
        <li>Item 1</li>
        <li>Item 2</li>
      </ul>
      Texto
    </div>
    """

    expected = """
    <div>
      Long long long loooooooooooong text:
      <i>...</i>
      <ul>
        <li>Item 1</li>
        <li>Item 2</li>
      </ul>
      Texto
    </div>
    """

    assert_formatter_output(input, expected, line_length: 20)
  end

  test "add indentation when there aren't any" do
    input = """
    <section>
    <div>
    <h1>Hello</h1>
    </div>
    </section>
    """

    expected = """
    <section>
      <div>
        <h1>Hello</h1>
      </div>
    </section>
    """

    assert_formatter_output(input, expected)
  end

  test "break HTML into multiple lines when it doesn't fit" do
    input = """
    <p class="alert alert-info more-class more-class" role="alert" phx-click="lv:clear-flash" phx-value-key="info">
      <%= live_flash(@flash, :info) %>
    </p>
    """

    expected = """
    <p
      class="alert alert-info more-class more-class"
      role="alert"
      phx-click="lv:clear-flash"
      phx-value-key="info"
    >
      <%= live_flash(@flash, :info) %>
    </p>
    """

    assert_formatter_output(input, expected)
  end

  test "handle HTML attributes" do
    input = """
    <p class="alert alert-info" phx-click="lv:clear-flash" phx-value-key="info">
      <%= live_flash(@flash, :info) %>
    </p>
    """

    assert_formatter_doesnt_change(input)
  end

  test "fix indentation when everything is inline" do
    input = """
    <section><div><h1>Hello</h1></div></section>
    """

    expected = """
    <section>
      <div>
        <h1>Hello</h1>
      </div>
    </section>
    """

    assert_formatter_output(input, expected)
  end

  test "fix indentation when it fits inline" do
    input = """
    <section id="id" phx-hook="PhxHook">
      <.component
        image_url={@url} />
    </section>
    """

    expected = """
    <section id="id" phx-hook="PhxHook">
      <.component image_url={@url} />
    </section>
    """

    assert_formatter_output(input, expected)
  end

  test "keep attributes at the same line if it fits 98 characters (default)" do
    input = """
    <Component foo="..........." bar="..............." baz="............" qux="..................." />
    """

    assert_formatter_doesnt_change(input)
  end

  test "keep attributes in separate lines if written as such" do
    input = """
    <Component
      foo="..."
      bar="..."
      baz="..."
      qux="..."
    >
      Foo
    </Component>
    """

    assert_formatter_doesnt_change(input)
  end

  test "break attributes into multiple lines in case it doesn't fit 98 characters (default)" do
    input = """
    <div foo="..........." bar="....................." baz="................." qux="....................">
    <p><%= @user.name %></p>
    </div>
    """

    expected = """
    <div
      foo="..........."
      bar="....................."
      baz="................."
      qux="...................."
    >
      <p><%= @user.name %></p>
    </div>
    """

    assert_formatter_output(input, expected)
  end

  test "single line inputs are not changed" do
    assert_formatter_doesnt_change("""
    <div />
    """)

    assert_formatter_doesnt_change("""
    <.component with="attribute" />
    """)
  end

  test "handle if/else/end block" do
    input = """
    <%= if true do %>
    <p>do something</p><p>more stuff</p>
    <% else %>
    <p>do something else</p><p>more stuff</p>
    <% end %>
    """

    expected = """
    <%= if true do %>
      <p>do something</p><p>more stuff</p>
    <% else %>
      <p>do something else</p><p>more stuff</p>
    <% end %>
    """

    assert_formatter_output(input, expected)
  end

  test "handle if/end block" do
    input = """
    <%= if true do %><p>do something</p>
    <% end %>
    """

    expected = """
    <%= if true do %>
      <p>do something</p>
    <% end %>
    """

    assert_formatter_output(input, expected)
  end

  test "handle case/end block" do
    input = """
    <div>
    <%= case {:ok, "elixir"} do %>
    <% {:ok, text} -> %>
    <%= text %>
    <p>text</p>
    <div />
    <% {:error, error} -> %>
    <%= error %>
    <p>error</p>
    <div />
    <% end %>
    </div>
    """

    expected = """
    <div>
      <%= case {:ok, "elixir"} do %>
        <% {:ok, text} -> %>
          <%= text %>
          <p>text</p>
          <div />
        <% {:error, error} -> %>
          <%= error %>
          <p>error</p>
          <div />
      <% end %>
    </div>
    """

    assert_formatter_output(input, expected)
  end

  test "format when there are curly interpolations" do
    input = """
      <section>
        <p>pre{@user.name}pos</p>
        <p>pre { @user.name}pos</p>
        <p>pre{@user.name } pos</p>
        <p>pre { @user.name } pos</p>
      </section>
    """

    expected = """
    <section>
      <p>pre{@user.name}pos</p>
      <p>pre {@user.name}pos</p>
      <p>pre{@user.name} pos</p>
      <p>pre {@user.name} pos</p>
    </section>
    """

    assert_formatter_output(input, expected)
  end

  test "avoids additional whitespace on curly" do
    assert_formatter_doesnt_change(
      """
      {@value}<span
        :if={is_nil(@value)}
        class={@class}
        aria-label={@accessibility_text}
        {@rest}
      >{@placeholder}</span>
      """,
      line_length: 50
    )
  end

  test "avoids additional whitespace on curly with html comments" do
    assert_formatter_doesnt_change("""
    <select>
      <!-- Comment -->
      {hello + world}
    </select>
    """)
  end

  test "migrates from eex to curly braces" do
    input = """
      <section>
        <p><%= @user.name %></p>
        <p><%= "{" %></p>
        <script>window.url = "<%= @user.name %>"</script>
      </section>
    """

    expected = """
    <section>
      <p>{@user.name}</p>
      <p><%= "{" %></p>
      <script>
        window.url = "<%= @user.name %>"
      </script>
    </section>
    """

    assert_formatter_output(input, expected, migrate_eex_to_curly_interpolation: true)
  end

  test "format when there are EEx tags" do
    input = """
      <section>
        <%= live_redirect to: "url", id: "link", role: "button" do %>
          <div>     <p>content 1</p><p>content 2</p></div>
        <% end %>
        <p><%= @user.name %></p>
        <%= if true do %> <p>it worked</p><% else %><p> it failed </p><% end %>
      </section>
    """

    expected = """
    <section>
      <%= live_redirect to: "url", id: "link", role: "button" do %>
        <div>
          <p>content 1</p><p>content 2</p>
        </div>
      <% end %>
      <p><%= @user.name %></p>
      <%= if true do %>
        <p>it worked</p>
      <% else %>
        <p>it failed</p>
      <% end %>
    </section>
    """

    assert_formatter_output(input, expected)
  end

  test "does not add newline after DOCTYPE" do
    input = """
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
      </head>
      <body>
        <%= @inner_content %>
      </body>
    </html>
    """

    assert_formatter_doesnt_change(input)
  end

  test "format tags with attributes without value" do
    assert_formatter_output(
      """

        <button class="btn-primary" autofocus disabled> Submit </button>

      """,
      """
      <button class="btn-primary" autofocus disabled> Submit </button>
      """
    )

    assert_formatter_output(
      """

        <button class="btn-primary" autofocus disabled>Submit</button>

      """,
      """
      <button class="btn-primary" autofocus disabled>Submit</button>
      """
    )
  end

  test "parse EEx inside of html tags" do
    assert_formatter_output(
      """
        <button {build_phx_attrs_dynamically()}>Test</button>
      """,
      """
      <button {build_phx_attrs_dynamically()}>Test</button>
      """
    )
  end

  test "lines with inline or EEx tags" do
    assert_formatter_output(
      """
        <p><span>this is a long long long long long looooooong text</span> <%= @product.value %> and more stuff over here</p>
      """,
      """
      <p>
        <span>this is a long long long long long looooooong text</span> <%= @product.value %> and more stuff over here
      </p>
      """
    )

    assert_formatter_output(
      """
      <p>first <span>name</span> second</p>
      """,
      """
      <p>
        first
        <span>name</span>
        second
      </p>
      """,
      line_length: 10
    )
  end

  test "text between inline elements" do
    assert_formatter_doesnt_change(
      """
      <span><%= @user_a %></span>
      X
      <span><%= @user_b %></span>
      """,
      line_length: 27
    )

    assert_formatter_output(
      """
      <span><%= @user_a %></span>
      X
      <span><%= @user_b %></span>
      """,
      """
      <span><%= @user_a %></span> X <span><%= @user_b %></span>
      """
    )

    assert_formatter_doesnt_change("""
    <span><%= @user_a %></span> X <span><%= @user_b %></span>
    """)

    assert_formatter_output(
      """
      <span><%= @user_a %></span> X <span><%= @user_b %></span>
      """,
      """
      <span><%= @user_a %></span>
      X
      <span><%= @user_b %></span>
      """,
      line_length: 5
    )

    assert_formatter_doesnt_change("""
    <span><%= link("Edit", to: Routes.post_path(@conn, :edit, @post)) %></span>
    | <span><%= link("Back", to: Routes.post_path(@conn, :index)) %></span>
    """)
  end

  test "handle EEx cond statement" do
    input = """
    <div>
    <%= cond do %>
    <% 1 == 1 -> %>
    <%= "Hello" %>
    <% 2 == 2 -> %>
    <%= "World" %>
    <% true -> %>
    <%= "" %>
    <% end %>
    </div>
    """

    expected = """
    <div>
      <%= cond do %>
        <% 1 == 1 -> %>
          <%= "Hello" %>
        <% 2 == 2 -> %>
          <%= "World" %>
        <% true -> %>
          <%= "" %>
      <% end %>
    </div>
    """

    assert_formatter_output(input, expected)
  end

  test "proper format elixir functions" do
    input = """
    <div>
    <%= live_component(MyAppWeb.Components.SearchBox, id: :search_box, on_select: :user_selected, label: gettext("Search User")) %>
    </div>
    """

    expected = """
    <div>
      <%= live_component(MyAppWeb.Components.SearchBox,
        id: :search_box,
        on_select: :user_selected,
        label: gettext("Search User")
      ) %>
    </div>
    """

    assert_formatter_output(input, expected)
  end

  test "does not add parentheses when tag is configured to not to" do
    input = """
    <%= text_input f, :name %>
    """

    expected = """
    <%= text_input f, :name %>
    """

    assert_formatter_output(input, expected, locals_without_parens: [text_input: 2])
  end

  test "does not add a line break in the first line" do
    assert_formatter_output(
      """
      <%= @user.name %>
      """,
      """
      <%= @user.name %>
      """
    )

    assert_formatter_output(
      """
      <div />
      """,
      """
      <div />
      """
    )

    assert_formatter_output(
      """
      <% "Hello" %>
      """,
      """
      <% "Hello" %>
      """
    )
  end

  test "use the configured line_length for breaking texts into new lines" do
    input = """
      <p>My title</p>
    """

    expected = """
    <p>
      My title
    </p>
    """

    assert_formatter_output(input, expected, line_length: 5)
  end

  test "doesn't break lines when tag doesn't have any attrs and it fits using the configured line length" do
    input = """
      <p>
      My title
      </p>
      <p>This is tooooooooooooooooooooooooooooooooooooooo looooooong annnnnnnnnnnnnnd should breeeeeak liines</p>
      <p class="some-class">Should break line</p>
      <p><%= @user.name %></p>
      should not break when there it is not wrapped by any tags
    """

    expected = """
    <p>
      My title
    </p>
    <p>
      This is tooooooooooooooooooooooooooooooooooooooo looooooong annnnnnnnnnnnnnd should breeeeeak liines
    </p>
    <p class="some-class">Should break line</p>
    <p><%= @user.name %></p>
    should not break when there it is not wrapped by any tags
    """

    assert_formatter_output(input, expected)
  end

  test "does not break lines for single long attributes" do
    assert_formatter_doesnt_change("""
    <h1 class="font-medium leading-tight text-5xl mt-0 mb-2 text-blue-600 text-sm sm:text-sm lg:text-sm font-semibold">
      Title
    </h1>
    """)

    assert_formatter_doesnt_change("""
    <div class="font-medium leading-tight text-5xl mt-0 mb-2 text-blue-600 text-sm sm:text-sm lg:text-sm font-semibold" />
    """)
  end

  test "changes expr to literal when it is an string" do
    assert_formatter_doesnt_change("""
    <div class={@id} />
    """)

    assert_formatter_doesnt_change("""
    <div class={some_function(:foo, :bar)} />
    """)

    assert_formatter_doesnt_change("""
    <div class={
      # test
      "mx-auto"
    } />
    """)

    assert_formatter_output(
      """
      <div class={"mx-auto flex-shrink-0 flex items-center justify-center h-8 w-8 rounded-full bg-purple-100 sm:mx-0"}>
        Content
      </div>
      """,
      """
      <div class="mx-auto flex-shrink-0 flex items-center justify-center h-8 w-8 rounded-full bg-purple-100 sm:mx-0">
        Content
      </div>
      """
    )
  end

  test "does not break lines when tag doesn't contain content" do
    input = """
    <thead>
      <tr>
        <th>Name</th>
        <th>Age</th>
        <th></th>
        <th>
        </th>
      </tr>
    </thead>
    """

    expected = """
    <thead>
      <tr>
        <th>Name</th>
        <th>Age</th>
        <th></th>
        <th></th>
      </tr>
    </thead>
    """

    assert_formatter_output(input, expected)
  end

  test "handle case statement within for statement" do
    input = """
    <tr>
      <%= for value <- @values do %>
        <td class="border-2">
          <%= case value.type do %>
          <% :text -> %>
          Do something
          <p>Hello</p>
          <% _ -> %>
          Do something else
          <p>Hello</p>
          <% end %>
        </td>
      <% end %>
    </tr>
    """

    expected = """
    <tr>
      <%= for value <- @values do %>
        <td class="border-2">
          <%= case value.type do %>
            <% :text -> %>
              Do something
              <p>Hello</p>
            <% _ -> %>
              Do something else
              <p>Hello</p>
          <% end %>
        </td>
      <% end %>
    </tr>
    """

    assert_formatter_output(input, expected)
  end

  test "proper indent if when it is in the beginning of the template" do
    input = """
    <%= if @live_action == :edit do %>
    <.modal return_to={Routes.store_index_path(@socket, :index)}>
      <.live_component
        id={@product.id}
        module={MystoreWeb.ReserveFormComponent}
        action={@live_action}
        product={@product}
        return_to={Routes.store_index_path(@socket, :index)}
      />
    </.modal>
    <% end %>
    """

    expected = """
    <%= if @live_action == :edit do %>
      <.modal return_to={Routes.store_index_path(@socket, :index)}>
        <.live_component
          id={@product.id}
          module={MystoreWeb.ReserveFormComponent}
          action={@live_action}
          product={@product}
          return_to={Routes.store_index_path(@socket, :index)}
        />
      </.modal>
    <% end %>
    """

    assert_formatter_output(input, expected)
  end

  test "handle void elements" do
    input = """
    <div>
    <link rel="shortcut icon" href={~p"/images/favicon.png"} type="image/x-icon">
    <p>some text</p>
    <br>
    <hr>
    <input type="text" value="Foo Bar">
    <img src="./image.png">
    </div>
    """

    expected = """
    <div>
      <link rel="shortcut icon" href={~p"/images/favicon.png"} type="image/x-icon" />
      <p>some text</p>
      <br />
      <hr />
      <input type="text" value="Foo Bar" />
      <img src="./image.png" />
    </div>
    """

    assert_formatter_output(input, expected)
  end

  test "format expressions within attributes" do
    input = """
      <.modal
        id={id}
        on_cancel={focus("#1", "#delete-song-1")}
        on_confirm={JS.push("delete", value: %{id: song.id})
                    |> hide_modal(id)
                    |> focus_closest("#song-1")
                    |> hide("#song-1")}
      />
    """

    expected = """
    <.modal
      id={id}
      on_cancel={focus("#1", "#delete-song-1")}
      on_confirm={
        JS.push("delete", value: %{id: song.id})
        |> hide_modal(id)
        |> focus_closest("#song-1")
        |> hide("#song-1")
      }
    />
    """

    assert_formatter_output(input, expected)
  end

  test "keep intentional line breaks" do
    assert_formatter_doesnt_change("""
    <section>
      <h1>
        <b>
          <%= @user.first_name %> <%= @user.last_name %>
        </b>
      </h1>

      <div>
        <p>test</p>
      </div>

      <h2>Subtitle</h2>
    </section>
    """)

    assert_formatter_output(
      """
        <p>
          $ <%= @product.value %> in Dollars
        </p>
        <button>
          Submit
        </button>
      """,
      """
      <p>
        $ <%= @product.value %> in Dollars
      </p>
      <button>
        Submit
      </button>
      """
    )
  end

  test "keep EEx expressions in the next line" do
    input = """
    <div class="mb-5">
      <%= live_file_input(@uploads.image_url) %>
      <%= error_tag(f, :image_url) %>
    </div>
    """

    assert_formatter_doesnt_change(input)
  end

  test "keep intentional extra line break between EEx expressions" do
    input = """
    <div class="mb-5">
      <%= live_file_input(@uploads.image_url) %>

      <%= error_tag(f, :image_url) %>
    </div>
    """

    assert_formatter_doesnt_change(input)
  end

  test "force unfit when there are line breaks in the text" do
    assert_formatter_doesnt_change("""
    <b>
      Text
      Text
      Text
    </b>
    <p>
      Text
      Text
      Text
    </p>
    """)

    assert_formatter_output(
      """
      <b>\s\s
      \tText
        Text
      \tText
      </b>
      """,
      """
      <b>
        Text
        Text
        Text
      </b>
      """
    )

    assert_formatter_output(
      """
      <b>\s\s
      \tText
      \t
      \tText
      </b>
      """,
      """
      <b>
        Text

        Text
      </b>
      """
    )

    assert_formatter_output(
      """
      <b>\s\s
      \t
      \tText
      \t
      \t
      \tText
      \t
      </b>
      """,
      """
      <b>
        Text

        Text
      </b>
      """
    )
  end

  test "doesn't format content within <pre>" do
    assert_formatter_output(
      """
      <div>
      <pre>
      Text
      Text
      </pre>
      </div>
      """,
      """
      <div>
        <pre>
      Text
      Text
      </pre>
      </div>
      """
    )

    assert_formatter_output(
      """
      <div><pre>Text
      Text</pre></div>
      """,
      """
      <div>
        <pre>Text
      Text</pre>
      </div>
      """
    )

    assert_formatter_doesnt_change("""
    <pre>
    Text
      <div>
          Text
        </div>
    </pre>
    """)

    assert_formatter_doesnt_change("""
    <pre><code><div>
    <p>Text</p>
    <%= if true do %>
      Hi
    <% else %>
      Ho
    <% end %>
    <p>Text</p>
    </div></code>
    </pre>
    """)
  end

  test "format <pre> tag with EEx" do
    assert_formatter_doesnt_change("""
    <pre>
      :root &lbrace;
        <%= 2 + 2 %>
        <%= 2 + 2 %>
      }
    </pre>
    """)
  end

  test "format label block correctly" do
    input = """
    <%= label @f, :email_address, class: "text-gray font-medium" do %> Email Address
    <% end %>
    """

    expected = """
    <%= label @f, :email_address, class: "text-gray font-medium" do %>
      Email Address
    <% end %>
    """

    assert_formatter_output(input, expected)
  end

  test "formats script tag" do
    assert_formatter_output(
      """
      <body>

      text
        <div><script>
      const foo = 1;
      const map = {
        a: 1,
        b: 2,
      };
      console.log(foo);
      </script></div>
      </body>
      """,
      """
      <body>
        text
        <div>
          <script>
            const foo = 1;
            const map = {
              a: 1,
              b: 2,
            };
            console.log(foo);
          </script>
        </div>
      </body>
      """
    )

    assert_formatter_output(
      """
      <body>

      text
        <div><script>
      \t\tconst foo = 1;
      \s\s
          const map = {
            a: 1,
            b: 2,
          };
      \t
      \s\s\s\sconsole.log(foo);
        </script></div>

      </body>
      """,
      """
      <body>
        text
        <div>
          <script>
            const foo = 1;

            const map = {
              a: 1,
              b: 2,
            };

            console.log(foo);
          </script>
        </div>
      </body>
      """
    )
  end

  test "formats EEx within script tag" do
    assert_formatter_doesnt_change("""
    <script>
      var foo = 1;
      var bar = <%= @bar %>
      var baz = <%= @baz %>
      console.log(1)
    </script>
    """)

    assert_formatter_output(
      """
      <script type="text/props">
        <%= %{
        a: 1,
        b: 2
      } %>
      </script>
      """,
      """
      <script type="text/props">
          <%= %{
          a: 1,
          b: 2
        } %>
      </script>
      """
    )

    assert_formatter_doesnt_change("""
    <script type="text/props">
        <%= raw(Jason.encode!(%{whatEndpoint: Routes.api_search_options_path(@conn, :role_search_options)},
      escape: :html_safe)) %>
    </script>
    """)
  end

  test "formats EEx blocks within script tag" do
    assert_formatter_doesnt_change("""
    <script>
      var foo = 1;
      <%= if @bar do %>
      var bar = 2;
      <% end %>
    </script>
    """)

    assert_formatter_doesnt_change("""
    <script>
      var foo = 1;
      <% if @bar do %>
      var bar = 2;
      <% end %>
    </script>
    """)
  end

  test "formats style tag" do
    input = """
    <div>
    <style>
    h1 {
      font-weight: 900;
    }
    </style>
    </div>
    """

    expected = """
    <div>
      <style>
        h1 {
          font-weight: 900;
        }
      </style>
    </div>
    """

    assert_formatter_output(input, expected)
  end

  test "format style tag with EEx" do
    assert_formatter_doesnt_change("""
    <style>
      :root {
        <%= 2 + 2 %>
        <%= 2 + 2 %>
      }
    </style>
    """)
  end

  test "handle HTML comments but doesn't format it" do
    assert_formatter_output(
      """
          <!-- Inline comment -->
      <section>
        <!-- commenting out this div
        <div>
          <p><%= @user.name %></p>
          <p
            class="my-class">
            text
          </p>
        </div>
           -->
      </section>
      """,
      """
      <!-- Inline comment -->
      <section>
        <!-- commenting out this div
        <div>
          <p><%= @user.name %></p>
          <p
            class="my-class">
            text
          </p>
        </div>
           -->
      </section>
      """
    )

    assert_formatter_doesnt_change("""
    <!-- Modal content -->
    <%= render_slot(@inner_block) %>
    """)

    assert_formatter_doesnt_change("""
    <!-- a comment -->
    <!-- a comment -->
    """)
  end

  test "handle case end when previous block is blank" do
    input = """
    <%= case :foo do %>
      <% :foo -> %>
        something
      <% _ -> %>
      <% end %>
    """

    expected = """
    <%= case :foo do %>
      <% :foo -> %>
        something
      <% _ -> %>
    <% end %>
    """

    assert_formatter_output(input, expected)
  end

  test "keep intentional spaces" do
    input = """
    <p>
            Last <%= length(@backlog_feeds) %> of <%= @feedcount %> backlog feeds </p>
    """

    expected = """
    <p>
      Last <%= length(@backlog_feeds) %> of <%= @feedcount %> backlog feeds
    </p>
    """

    assert_formatter_output(input, expected)
  end

  test "handle comment block with eex" do
    assert_formatter_doesnt_change("""
    <div></div>
    <!-- <%= "comment" %> -->
    <div></div>
    """)
  end

  test "handle spaces properly" do
    input = """
    <button>
      <i class="fa-solid fa-xmark"></i>
      Close
    </button>
    """

    expected = """
    <button>
      <i class="fa-solid fa-xmark"></i> Close
    </button>
    """

    assert_formatter_output(input, expected)
  end

  test "keep at least one space around inline tags" do
    assert_formatter_doesnt_change("""
    <b>Foo: </b>
    """)

    assert_formatter_doesnt_change("""
    <b> Foo: </b>
    """)

    assert_formatter_doesnt_change("""
    <b> Foo:</b>
    """)

    assert_formatter_doesnt_change("""
    <b>{code}: </b>
    """)

    assert_formatter_doesnt_change("""
    <b> :{code}</b>
    """)

    assert_formatter_doesnt_change("""
    <p>
      <b>Foo: </b>bar
    </p>
    """)

    assert_formatter_doesnt_change("""
    <p>
      <b>Foo: </b><span>bar</span>
    </p>
    """)

    assert_formatter_output(
      """
      <p> <span>bar </span> </p>
      """,
      """
      <p><span>bar </span></p>
      """
    )

    assert_formatter_doesnt_change("""
    <p><b>Foo: </b><span>bar</span></p>
    """)

    assert_formatter_doesnt_change("""
    <p>
      <b>Foo: </b><%= some_var %>
    </p>
    """)

    assert_formatter_doesnt_change("""
    <p>
      <b>Foo:</b><%= some_var %>
    </p>
    """)

    assert_formatter_output(
      """
      <b>      Foo  Bar    </b>
      """,
      """
      <b> Foo  Bar </b>
      """
    )

    assert_formatter_doesnt_change("""
    <b> Foo Bar </b>
    """)

    assert_formatter_output(
      """
      <b>Foo:    </b>
      """,
      """
      <b>Foo: </b>
      """
    )

    assert_formatter_output(
      """
      <b>        Foo: </b>
      """,
      """
      <b> Foo: </b>
      """
    )
  end

  test "doesn't add extra spaces to inline tags with nested inline tags with leading whitespace" do
    assert_formatter_doesnt_change("""
    <a>foo<b>bar</b></a>
    """)

    assert_formatter_doesnt_change("""
    <a>foo <b>bar</b></a>
    """)

    assert_formatter_doesnt_change("""
    <a> foo<b>bar</b></a>
    """)

    assert_formatter_doesnt_change("""
    <a> foo <b>bar</b></a>
    """)

    assert_formatter_doesnt_change("""
    <a>foo<b>bar</b></a>
    """)

    assert_formatter_doesnt_change("""
    <a>foo <b> bar</b></a>
    """)

    assert_formatter_doesnt_change("""
    <a> foo<b>bar </b></a>
    """)

    assert_formatter_doesnt_change("""
    <a> foo <b> bar </b></a>
    """)
  end

  test "treats components with link or button in their name as inline" do
    assert_formatter_doesnt_change("""
    <.styled_link> Foo: </.styled_link>
    """)

    assert_formatter_output(
      """
      <.styled_link> Foo: </.styled_link>
      """,
      """
      <.styled_link>Foo:</.styled_link>
      """,
      inline_matcher: []
    )

    assert_formatter_doesnt_change("""
    <.styled_button_custom> Foo: </.styled_button_custom>
    """)

    assert_formatter_doesnt_change(
      """
      <.my_custom_inline_element> Foo: </.my_custom_inline_element>
      """,
      inline_matcher: [~r/inline_element$/]
    )
  end

  test "does not keep empty lines on script and styles tags" do
    input = """
    <script>

    </script>
    """

    expected = """
    <script>
    </script>
    """

    assert_formatter_output(input, expected)

    input = """
    <style>

    </style>
    """

    expected = """
    <style>
    </style>
    """

    assert_formatter_output(input, expected)
  end

  test "does not break lines in self closed elements" do
    assert_formatter_doesnt_change("""
    <div>
      This should not wrap on a new line <input />.
    </div>
    """)
  end

  test "keep EEx along with the text" do
    assert_formatter_doesnt_change("""
    <div>
      _______________________________________________________ result<%= if(@row_count != 1, do: "s") %>
    </div>
    """)

    assert_formatter_doesnt_change("""
    <div>
      _______________________________________________________ result <%= if(@row_count != 1, do: "s") %>
    </div>
    """)
  end

  test "keep single quote delimiter when value has quotes" do
    assert_formatter_doesnt_change("""
    <div title='Say "hi!"'></div>
    """)
  end

  test "transform single quotes to double when value has no quotes" do
    input = """
    <div title='Say hi!'></div>
    """

    expected = """
    <div title="Say hi!"></div>
    """

    assert_formatter_output(input, expected)
  end

  test "does not format inline elements surrounded by texts without white spaces" do
    assert_formatter_output(
      """
      <p>
        text text text<a class="text-blue-500" href="" target="_blank" attr1="">link</a>
      </p>
      """,
      """
      <p>
        text text text<a
          class="text-blue-500"
          href=""
          target="_blank"
          attr1=""
        >link</a>
      </p>
      """,
      line_length: 50
    )

    assert_formatter_output(
      """
      <p>
        first <a class="text-blue-500" href="" target="_blank" attr1="">link</a>second.
      </p>
      """,
      """
      <p>
        first <a
          class="text-blue-500"
          href=""
          target="_blank"
          attr1=""
        >link</a>second.
      </p>
      """,
      line_length: 50
    )

    assert_formatter_output(
      """
      <p>
        <a class="text-blue-500" href="" target="_blank" attr1="">link</a>text text text text.
      </p>
      """,
      """
      <p>
        <a
          class="text-blue-500"
          href=""
          target="_blank"
          attr1=""
        >link</a>text text text text.
      </p>
      """,
      line_length: 50
    )

    assert_formatter_output(
      """
      <p>
        <a class="text-blue-500" href="" target="_blank" attr1="">link</a>{code}.
      </p>
      """,
      """
      <p>
        <a
          class="text-blue-500"
          href=""
          target="_blank"
          attr1=""
        >link</a>{code}.
      </p>
      """,
      line_length: 50
    )

    assert_formatter_doesnt_change(
      """
      <p>
        long line of text <span>span 1</span>
        more text <span>span 2</span>
      </p>
      """,
      line_length: 45
    )
  end

  test "preserve inline element when there aren't whitespaces" do
    assert_formatter_doesnt_change(
      """
      <b>foo</b><i><span>bar</span></i><span>baz</span>
      """,
      line_length: 20
    )

    assert_formatter_output(
      """
      <b>Foo</b><i>bar</i> <span>baz</span>
      """,
      """
      <b>Foo</b><i>bar</i>
      <span>baz</span>
      """,
      line_length: 20
    )

    assert_formatter_doesnt_change(
      """
      <b>foo</b><i>bar</i><%= @user.name %><span>baz</span>
      """,
      line_length: 20
    )

    assert_formatter_output(
      """
      <b>foo</b><i><span id="myspan" class="a long list of classes">bar</span></i><span>baz</span>
      """,
      """
      <b>foo</b><i><span
        id="myspan"
        class="a long list of classes"
      >bar</span></i><span>baz</span>
      """,
      line_length: 20
    )

    assert_formatter_output(
      """
      <b>foo</b><i><span><div>bar</div></span></i><span>baz</span>
      """,
      """
      <b>foo</b><i><span><div>
        bar
      </div></span></i><span>baz</span>
      """,
      line_length: 20
    )
  end

  test "does not add space between elements without space" do
    assert_formatter_doesnt_change(
      """
      <span>foo</span><span>bar</span>
      <span>foo</span><.foo_bar_baz />
      <.foo_bar_baz /><span>bar</span>
      <div>foo</div><div>
        bar
      </div>
      <div>foo</div><.foo_bar_baz />
      <.foo_bar_baz /><div>
        bar
      </div>
      """,
      line_length: 20
    )
  end

  test "preserve inline element on the same line when followed by a EEx expression without whitespaces" do
    assert_formatter_doesnt_change(
      """
      <%= some_function("arg") %><span>content</span>
      """,
      line_length: 25
    )

    assert_formatter_output(
      """
      <%= some_function("arg") %> <span>content</span>
      """,
      """
      <%= some_function("arg") %>
      <span>content</span>
      """,
      line_length: 25
    )
  end

  test "does not format when contenteditable is present" do
    assert_formatter_doesnt_change(
      """
      <div contenteditable>The content content content content content</div>
      """,
      line_length: 10
    )

    assert_formatter_doesnt_change(
      """
      <div contenteditable="true">The content content content content content</div>
      """,
      line_length: 10
    )

    assert_formatter_output(
      """
      <div contenteditable="false">The content content content content content</div>
      """,
      """
      <div contenteditable="false">
        The content content content content content
      </div>
      """,
      line_length: 10
    )
  end

  test "does not format textarea" do
    assert_formatter_doesnt_change(
      """
      <textarea><%= @content %></textarea>
      """,
      line_length: 5
    )

    assert_formatter_doesnt_change(
      """
      <textarea>
        <div
        class="one"
        id="two"
      >
      <outside />
        </div>
      </textarea>
      """,
      line_length: 5
    )

    assert_formatter_doesnt_change("""
    <textarea />
    """)

    assert_formatter_doesnt_change(
      """
      <textarea></textarea>
      """,
      line_length: 5
    )
  end

  test "keeps right format for inline elements within block elements" do
    assert_formatter_doesnt_change("""
    <section>
      <svg
        id="game"
        viewBox="0 0 1000 1000"
        width="1000"
        height="1000"
        class="bg-white dark:bg-zinc-900 shadow mx-auto"
      >
        <defs>
          <pattern id="tenthGrid" width="10" height="10" patternUnits="userSpaceOnUse">
            <path d="M 10 0 L 0 0 0 10" fill="none" stroke="silver" stroke-width="0.5" />
          </pattern>
        </defs>
      </svg>
    </section>
    """)
  end

  test "respects heex_line_length" do
    assert_formatter_doesnt_change(
      """
      <p>
        <strong>Please let me be in the same line</strong> Value <strong>Please let me be in the same line</strong>.
      </p>
      """,
      heex_line_length: 1000
    )
  end

  test "does not format when phx-no-format attr is present" do
    assert_formatter_doesnt_change(
      """
      <.textarea phx-no-format>My content</.textarea>
      """,
      line_length: 5
    )

    assert_formatter_output(
      """
      <script phx-no-format><%= raw(js_code()) %></script>
      """,
      """
      <script phx-no-format><%= raw(js_code()) %></script>
      """,
      line_length: 5
    )

    assert_formatter_output(
      """
      <span phx-no-format class="underline">Check</span> Messages
      """,
      """
      <span
        phx-no-format
        class="underline"
      >Check</span> Messages
      """,
      line_length: 5
    )
  end

  test "respect interpolation when phx-no-format is present" do
    assert_formatter_doesnt_change("""
    <title data-prefix={@prefix} data-default={@default} data-suffix={@suffix} phx-no-format>{@prefix}{render_present(render_slot(@inner_block), @default)}{@suffix}</title>
    """)
  end

  test "respect nesting of children when phx-no-format is present" do
    assert_formatter_doesnt_change(
      """
      <ul class="root" phx-no-format><!-- comment
      --><%= for user <- @users do %>
          <li class="list">
            <div class="child1">
              <span class="child2">text</span>
            </div>
          </li>
        <% end %><!-- comment
      --></ul>
      """,
      line_length: 100
    )

    assert_formatter_doesnt_change(
      """
      <ul class="root" phx-no-format>
      <li class="list">
          <div
          class="child1">
        <span class="child2">text</span>
          </div>
      </li>
      </ul>
      """,
      line_length: 100
    )
  end

  test "order :let :for and :if over HTML attributes" do
    assert_formatter_output(
      """
      <.form for={@changeset} :let={f} class="form">
        <%= input(f, :foo) %>
      </.form>
      """,
      """
      <.form :let={f} for={@changeset} class="form">
        <%= input(f, :foo) %>
      </.form>
      """
    )

    assert_formatter_output(
      """
      <div :for={item <- @items} :if={true} :let={@name} />
      """,
      """
      <div :let={@name} :for={item <- @items} :if={true} />
      """
    )

    assert_formatter_output(
      """
      <div id="id" class="class" :if={true} :for={item <- @items} :let={@name} />
      """,
      """
      <div :let={@name} :for={item <- @items} :if={true} id="id" class="class" />
      """
    )
  end

  test "handle html comments + EEx expressions" do
    assert_formatter_output(
      """
      <%= if @comment do %><!-- <%= @comment %> --><% end %>
      """,
      """
      <%= if @comment do %>
        <!-- <%= @comment %> -->
      <% end %>
      """
    )
  end

  test "keep intentional line breaks between slots" do
    assert_formatter_doesnt_change("""
    <.component>
      <:title>Guides & Docs</:title>

      <:desc>View our step-by-step guides, or browse the comprehensive API docs</:desc>
    </.component>
    """)

    assert_formatter_output(
      """
      <.component>

        <:title>Guides & Docs</:title>


        <:desc>View our step-by-step guides, or browse the comprehensive API docs</:desc>

      </.component>
      """,
      """
      <.component>
        <:title>Guides & Docs</:title>

        <:desc>View our step-by-step guides, or browse the comprehensive API docs</:desc>
      </.component>
      """
    )
  end

  test "does not not break lines for long css lines when there are interpolation" do
    assert_formatter_doesnt_change(
      ~S"""
      <div class={"#{@errors} mt-1 block w-full"}>
        Hi
      </div>
      """,
      heex_line_length: 10
    )

    assert_formatter_doesnt_change(
      """
      <div class={@errors <> "mt-1 block w-full"}>
        Hi
      </div>
      """,
      heex_line_length: 10
    )
  end

  test "break text to next line when previous inline element is indented" do
    assert_formatter_output(
      """
      <p>foo <strong class="foo bar baz"> <%= some_function() %></strong> baz</p>
      """,
      """
      <p>
        foo
        <strong class="foo bar baz"><%= some_function() %></strong>
        baz
      </p>
      """,
      heex_line_length: 15
    )
  end

  test "format attrs from self tag close correctly within preserve mode" do
    assert_formatter_doesnt_change("""
    <button>
      <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
        <path
          fill-rule="evenodd"
          d="M15.707 15.707a1 1 0 01-1.414 0l-5-5a1 1 0 010-1.414l5-5a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 010 1.414zm-6 0a1 1 0 01-1.414 0l-5-5a1 1 0 010-1.414l5-5a1 1 0 011.414 1.414L5.414 10l4.293 4.293a1 1 0 010 1.414z"
          clip-rule="evenodd"
        />
      </svg>Back to previous page
    </button>
    """)

    assert_formatter_doesnt_change("""
    <button>
      <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
        <nest>
          <path
            fill-rule="evenodd"
            d="M15.707 15.707a1 1 0 01-1.414 0l-5-5a1 1 0 010-1.414l5-5a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 010 1.414zm-6 0a1 1 0 01-1.414 0l-5-5a1 1 0 010-1.414l5-5a1 1 0 011.414 1.414L5.414 10l4.293 4.293a1 1 0 010 1.414z"
            clip-rule="evenodd"
          />
        </nest>
      </svg>Back to previous page
    </button>
    """)
  end

  test "does not break attrs" do
    assert_formatter_output(
      """
      <button
        type={@type}
        class={
          [
            "phx-submit-loading:opacity-75 rounded-lg bg-zinc-900 py-2 px-3 text-sm font-semibold",
            "leading-6 text-white hover:bg-zinc-700 active:text-white/80",
            @class
          ]
        }
        {@rest}
      >
        <%= render_slot(@inner_block) %>
      </button>
      """,
      """
      <button
        type={@type}
        class={[
          "phx-submit-loading:opacity-75 rounded-lg bg-zinc-900 py-2 px-3 text-sm font-semibold",
          "leading-6 text-white hover:bg-zinc-700 active:text-white/80",
          @class
        ]}
        {@rest}
      >
        <%= render_slot(@inner_block) %>
      </button>
      """
    )

    assert_formatter_doesnt_change("""
    <div class={
      [
        # test
        "mx-auto"
      ]
    } />
    """)

    assert_formatter_doesnt_change("""
    <div class={
      # test
      [
        "mx-auto"
      ]
    } />
    """)

    assert_formatter_doesnt_change("""
    <div class={
      [
        # test
        "mx-auto"
      ]
    } />
    """)
  end

  test "doesn't break line when tag/component is right after the text" do
    assert_formatter_doesnt_change("""
    <p>
      (<span label="application programming interface">API</span>).
    </p>
    """)

    assert_formatter_doesnt_change("""
    <p>
      (<div label="application programming interface">API</div>).
    </p>
    """)

    assert_formatter_doesnt_change("""
    <p>
      (<.abbr label="application programming interface">API</.abbr>).
    </p>
    """)
  end

  test "handle heredocs" do
    assert_formatter_output(
      """
      <.component msg={"text"}>
        <div />
      </.component>
      """,
      """
      <.component msg="text">
        <div />
      </.component>
      """
    )

    assert_formatter_doesnt_change("""
    <.component msg={\"""
    text
    \"""}>
      <div />
    </.component>
    """)

    assert_formatter_output(
      """
      <.component id={@id} msg={\"""
      text
      \"""}>
        <div />
      </.component>
      """,
      """
      <.component
        id={@id}
        msg={\"""
        text
        \"""}
      >
        <div />
      </.component>
      """
    )
  end

  test "handle var <> heredocs" do
    assert_formatter_doesnt_change("""
    <.component id={@id} msg={@test <> \"""
    text
    \"""}>
      <div />
    </.component>
    """)
  end

  test "handle multiple HTML comments with EEx vars" do
    assert_formatter_doesnt_change("""
    <!--
    <button><%= @var %></button>
    -->
    <!-- comment -->
    """)
  end

  test "treats .link component as inline" do
    assert_formatter_doesnt_change(
      """
      <.link class="font-semibold" navigate={~p"/open/file?autosave=true"}>Browse them here</.link>.
      """,
      heex_line_length: 72
    )
  end

  test "does not format when empty" do
    assert_formatter_doesnt_change("")

    assert_formatter_doesnt_change("", opening_delimiter: "\"")

    assert_formatter_doesnt_change("", opening_delimiter: "\"\"\"")
  end

  test "doesn't convert <% to <%=" do
    assert_formatter_doesnt_change("""
    <% fun = fn assigns -> %>
      <hr />
    <% end %>
    """)
  end

  test "doesn't flatten strings containing double quotes (#3336)" do
    assert_formatter_doesnt_change(~S"""
    <div data-foo={"{\"tag\": \"<something>\"}"}></div>
    """)
  end

  test "keep intentional lines breaks from HTML comments" do
    assert_formatter_doesnt_change("""
    <h1>Title</h1>

    <!-- comment -->
    <p>Text</p>
    """)

    assert_formatter_doesnt_change("""
    <h1>Title</h1>

    <!-- comment -->

    <p>Text</p>
    """)

    assert_formatter_output(
      """
      <h1>Title</h1>


      <!-- comment -->


      <p>Text</p>
      """,
      """
      <h1>Title</h1>

      <!-- comment -->

      <p>Text</p>
      """
    )
  end

  test "handle EEx comments" do
    assert_formatter_doesnt_change("""
    <div>
      <%!-- some --%>
      <%!-- comment --%>
      <%!--
        <div>
          <%= @user.name %>
        </div>
      --%>
    </div>
    """)

    assert_formatter_doesnt_change("""
    <div>
      <%= # some %>
      <%= # comment %>
      <%= # lines %>
    </div>
    """)
  end

  test "supports attribute_formatters" do
    defmodule UpcaseFormatter do
      def render_attribute({"upcased", {:string, value, meta}, attr_meta}, _opts) do
        {"upcased", {:string, String.upcase(value), meta}, attr_meta}
      end
    end

    assert_formatter_output(
      """
      <div upcased='foo' untouched='bar' unloaded='baz' />
      """,
      """
      <div upcased="FOO" untouched="bar" unloaded="baz" />
      """,
      attribute_formatters: %{upcased: UpcaseFormatter, unloaded: Unloaded}
    )
  end
end
