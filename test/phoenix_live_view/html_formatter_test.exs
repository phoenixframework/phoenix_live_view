if Version.match?(System.version(), ">= 1.13.0") do
  defmodule Phoenix.LiveView.HTMLFormatterTest do
    use ExUnit.Case, async: true

    alias Phoenix.LiveView.HTMLFormatter

    defp assert_formatter_output(input, expected, dot_formatter_opts \\ []) do
      formatted = HTMLFormatter.format(input, dot_formatter_opts)
      assert formatted == expected
      assert HTMLFormatter.format(input, dot_formatter_opts) == formatted
    end

    def assert_formatter_doesnt_change(code, opts \\ []) do
      assert_formatter_output(code, code, opts)
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
          <b>
            <%= @user.name %>
          </b>
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
          <b
            class="there are several classes"
          >
          </b>
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
        Long long long loooooooooooong text: <i>...</i>.
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
        <i>...</i>.
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
        <p>do something</p>
        <p>more stuff</p>
      <% else %>
        <p>do something else</p>
        <p>more stuff</p>
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

    test "format when there are EEx tags" do
      input = """
        <section>
          <%= live_redirect to: "url", id: "link", role: "button" do %>
            <div>     <p>content 1</p><p>content 2</p></div>
          <% end %>
          <p><%= @user.name %></p>
          <%= if true do %> <p>deu bom</p><% else %><p> deu ruim </p><% end %>
        </section>
      """

      expected = """
      <section>
        <%= live_redirect to: "url", id: "link", role: "button" do %>
          <div>
            <p>content 1</p>
            <p>content 2</p>
          </div>
        <% end %>
        <p><%= @user.name %></p>
        <%= if true do %>
          <p>deu bom</p>
        <% else %>
          <p>deu ruim</p>
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
        <button class="btn-primary" autofocus disabled>Submit</button>
        """
      )
    end

    test "keep tags with text and eex expressions inline" do
      assert_formatter_output(
        """
          <p>
            $
            <%= @product.value %> in Dollars
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

    test "parse eex inside of html tags" do
      assert_formatter_output(
        """
          <button {build_phx_attrs_dynamically()}>Test</button>
        """,
        """
        <button {build_phx_attrs_dynamically()}>Test</button>
        """
      )
    end

    test "format long lines splitting into multiple lines" do
      assert_formatter_output(
        """
          <p><span>this is a long long long long long looooooong text</span> <%= @product.value %> and more stuff over here</p>
        """,
        """
        <p>
          <span>this is a long long long long long looooooong text</span> <%= @product.value %>
          and more stuff over here
        </p>
        """
      )
    end

    test "handle eex cond statement" do
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
      <link rel="shortcut icon" href={Routes.static_path(@conn, "/images/favicon.png")} type="image/x-icon">
      <p>some text</p>
      <br>
      <hr>
      <input type="text" value="Foo Bar">
      <img src="./image.png">
      </div>
      """

      expected = """
      <div>
        <link
          rel="shortcut icon"
          href={Routes.static_path(@conn, "/images/favicon.png")}
          type="image/x-icon"
        />
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
      input = """
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
      """

      assert_formatter_doesnt_change(input)
    end

    test "keep eex expressions in the next line" do
      input = """
      <div class="mb-5">
        <%= live_file_input(@uploads.image_url) %>
        <%= error_tag(f, :image_url) %>
      </div>
      """

      assert_formatter_doesnt_change(input)
    end

    test "keep intentional extra line break between eex expressions" do
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
        :root {
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

    test "formats eex within script tag" do
      input = """
      <script>
        var foo = 1;
        var bar = <%= @bar %>
        var baz = <%= @baz %>
        console.log(1)
      </script>
      """

      assert_formatter_doesnt_change(input)
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

    test "handle HTML comments but doens't format it" do
      input = """
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

      expected = """
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

      assert_formatter_output(input, expected)

      assert_formatter_doesnt_change("""
      <!-- Modal content -->
      <%= render_slot(@inner_block) %>
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

    # TODO: Remove this `if` after Elixir versions before than 1.14 are no
    # longer supported.
    if function_exported?(EEx, :tokenize, 2) do
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
    end
  end
end
