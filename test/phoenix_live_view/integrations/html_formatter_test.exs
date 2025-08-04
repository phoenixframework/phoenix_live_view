defmodule Phoenix.LiveView.Integrations.HTMLFormatterTest do
  use ExUnit.Case

  alias Phoenix.LiveView.HTMLFormatter

  defp assert_mix_format_output(input_ex, expected, dot_formatter_opts \\ []) do
    filename = "index.html.heex"
    ex_path = Path.join(System.tmp_dir(), filename)
    dot_formatter_path = ex_path <> ".formatter.exs"
    dot_formatter_opts = Keyword.put(dot_formatter_opts, :plugins, [HTMLFormatter])

    on_exit(fn ->
      File.rm(ex_path)
      File.rm(dot_formatter_path)
    end)

    File.write!(ex_path, input_ex)
    File.write!(dot_formatter_path, inspect(dot_formatter_opts))

    # Run mix format twice to make sure the formatted file doesn't change after
    # another mix format.
    formatted = run_formatter(ex_path, dot_formatter_path)
    assert formatted == expected
    assert run_formatter(ex_path, dot_formatter_path) == formatted
  end

  defp run_formatter(ex_path, dot_formatter_path) do
    Mix.Tasks.Format.run([ex_path, "--dot-formatter", dot_formatter_path])
    File.read!(ex_path)
  end

  test "formats with default options" do
    input = """
      <section>
        <%= live_redirect to: "url", id: "link", role: "button" do %>
          <div>     <p>content 1</p><p>content 2</p></div>
        <% end %>
        <p><%= @user.name %></p>
        <%= if true do %> <p>good</p><% else %><p>bad</p><% end %>
      </section>

      <section>
      <%= for value <- @values do %>
        <td class="border-2">
          <%= case value.type do %>
          <% :text -> %>
          <p>Hello</p>
          <% _ -> %>
          <p>Hello</p>
          <% end %>
        </td>
      <% end %>
      </section>

      <!-- comment -->
      <div><p>Hello</p></div>

      <pre>
               Leave me alone</pre>

      <script>
      const foo = 1;
      console.log(foo);
      </script>
      <!-- html block comment
          <div>leave me alone</div>
      -->
    """

    expected = """
    <section>
      <%= live_redirect to: "url", id: "link", role: "button" do %>
        <div>
          <p>content 1</p><p>content 2</p>
        </div>
      <% end %>
      <p>{@user.name}</p>
      <%= if true do %>
        <p>good</p>
      <% else %>
        <p>bad</p>
      <% end %>
    </section>

    <section>
      <%= for value <- @values do %>
        <td class="border-2">
          <%= case value.type do %>
            <% :text -> %>
              <p>Hello</p>
            <% _ -> %>
              <p>Hello</p>
          <% end %>
        </td>
      <% end %>
    </section>

    <!-- comment -->
    <div>
      <p>Hello</p>
    </div>

    <pre>
               Leave me alone</pre>

    <script>
      const foo = 1;
      console.log(foo);
    </script>
    <!-- html block comment
          <div>leave me alone</div>
      -->
    """

    assert_mix_format_output(input, expected)
  end

  test "accept line_length as option" do
    input = """
      <section><h1><b class="there are several classes">{@user.name}</b></h1></section>
    """

    expected = """
    <section>
      <h1>
        <b class="there are several classes">{@user.name}</b>
      </h1>
    </section>
    """

    assert_mix_format_output(input, expected, line_length: 20)
  end

  test "heex_line_length overrides line_length" do
    input = """
      <section><h1><b class="there are several classes">{@user.name}</b></h1></section>
    """

    expected = """
    <section>
      <h1><b class="there are several classes">{@user.name}</b></h1>
    </section>
    """

    assert_mix_format_output(input, expected, line_length: 20, heex_line_length: 80)
  end
end
