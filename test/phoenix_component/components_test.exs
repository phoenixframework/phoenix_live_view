defmodule Phoenix.LiveView.ComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.HTML.Form
  import Phoenix.Component

  defp render(template) do
    template
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  defp parse(template) do
    template
    |> render()
    |> Phoenix.LiveViewTest.DOM.parse()
  end

  describe "link patch" do
    test "basic usage" do
      assigns = %{}
      dom = render(~H|<.link patch="/home">text</.link>|)

      assert dom =~ ~s|data-phx-link="patch"|
      assert dom =~ ~s|data-phx-link-state="push"|
      assert dom =~ ~s|text</a>|
      refute dom =~ ~s|to="/|
    end

    test "forwards global dom attributes" do
      assigns = %{}

      dom =
        render(~H|<.link patch="/" class="btn btn-large" data={[page_number: 2]}>next</.link>|)

      assert dom =~ ~s|class="btn btn-large"|
      assert dom =~ ~s|data-page-number="2"|
      assert dom =~ ~s|data-phx-link="patch"|
      assert dom =~ ~s|data-phx-link-state="push"|
    end
  end

  describe "link navigate" do
    test "basic usage" do
      assigns = %{}
      dom = render(~H|<.link navigate="/">text</.link>|)

      assert dom =~ ~s|data-phx-link="redirect"|
      assert dom =~ ~s|data-phx-link-state="push"|
      assert dom =~ ~s|text</a>|
      refute dom =~ ~s|to="/|
    end

    test "forwards global dom attributes" do
      assigns = %{}

      dom =
        render(~H|<.link navigate="/" class="btn btn-large" data={[page_number: 2]}>text</.link>|)

      assert dom =~ ~s|class="btn btn-large"|
      assert dom =~ ~s|data-page-number="2"|
      assert dom =~ ~s|data-phx-link="redirect"|
      assert dom =~ ~s|data-phx-link-state="push"|
    end
  end

  describe "link href" do
    test "basic usage" do
      assigns = %{}
      assert render(~H|<.link href="/">text</.link>|) == ~s|<a href="/">text</a>|
    end

    test "arbitrary attrs" do
      assigns = %{}

      assert render(~H|<.link href="/" class="foo">text</.link>|) ==
               ~s|<a href="/" class="foo">text</a>|
    end

    test "with no href" do
      assigns = %{}

      assert render(~H|<.link phx-click="click">text</.link>|) ==
               ~s|<a href="#" phx-click="click">text</a>|
    end

    test "with # ref" do
      assigns = %{}

      assert render(~H|<.link href="#" phx-click="click">text</.link>|) ==
               ~s|<a href="#" phx-click="click">text</a>|
    end

    test "with nil href" do
      assigns = %{}

      assert render(~H|<.link href={nil} phx-click="click">text</.link>|) ==
               ~s|<a href="#" phx-click="click">text</a>|
    end

    test "csrf with get method" do
      assigns = %{}

      assert render(~H|<.link href="/" method="get">text</.link>|) ==
               ~s|<a href="/">text</a>|

      assert render(~H|<.link href="/" method="get" csrf_token="123">text</.link>|) ==
               ~s|<a href="/">text</a>|
    end

    test "csrf with non-get method" do
      assigns = %{}
      csrf = Plug.CSRFProtection.get_csrf_token_for("/users")

      assert render(~H|<.link href="/users" method="delete">delete</.link>|) ==
               ~s|<a href="/users" data-method="delete" data-csrf="#{csrf}" data-to="/users">delete</a>|

      assert render(~H|<.link href="/users" method="delete" csrf_token={true}>delete</.link>|) ==
               ~s|<a href="/users" data-method="delete" data-csrf="#{csrf}" data-to="/users">delete</a>|

      assert render(~H|<.link href="/users" method="delete" csrf_token={false}>delete</.link>|) ==
               ~s|<a href="/users" data-method="delete" data-to="/users">delete</a>|
    end

    test "csrf with custom token" do
      assigns = %{}

      assert render(~H|<.link href="/users" method="post" csrf_token="123">delete</.link>|) ==
               ~s|<a href="/users" data-method="post" data-csrf="123" data-to="/users">delete</a>|
    end

    test "csrf with confirm" do
      assigns = %{}

      assert render(
               ~H|<.link href="/users" method="post" csrf_token="123" data-confirm="are you sure?">delete</.link>|
             ) ==
               "<a href=\"/users\" data-method=\"post\" data-csrf=\"123\" data-to=\"/users\" data-confirm=\"are you sure?\">delete</a>"
    end

    test "js schemes" do
      assigns = %{}

      assert render(~H|<.link href={{:javascript, "alert('bad')"}}>js</.link>|) ==
               ~s|<a href="javascript:alert(&#39;bad&#39;)">js</a>|
    end

    test "invalid schemes" do
      assigns = %{}

      assert_raise ArgumentError, ~r/unsupported scheme given to <.link>/, fn ->
        render(~H|<.link href="javascript:alert('bad')">bad</.link>|) ==
          ~s|<a href="/users" data-method="post" data-csrf="123">delete</a>|
      end
    end
  end

  describe "focus_wrap" do
    test "basic usage" do
      assigns = %{}

      template = ~H"""
      <.focus_wrap id="wrap" class="foo">
        <div>content</div>
      </.focus_wrap>
      """

      dom = render(template)

      assert dom ==
               ~s|<div id="wrap" phx-hook="Phoenix.FocusWrap" class="foo">\n  <span id="wrap-start" tabindex="0" aria-hidden="true"></span>\n  \n  <div>content</div>\n\n  <span id="wrap-end" tabindex="0" aria-hidden="true"></span>\n</div>|
    end
  end

  describe "live_title/2" do
    test "dynamic attrs" do
      assigns = %{prefix: "MyApp – ", title: "My Title"}

      assert render(~H|<.live_title prefix={@prefix}><%= @title %></.live_title>|) ==
               ~s|<title data-prefix="MyApp – ">MyApp – My Title</title>|
    end

    test "prefix only" do
      assigns = %{}

      assert render(~H|<.live_title prefix="MyApp – ">My Title</.live_title>|) ==
               ~s|<title data-prefix="MyApp – ">MyApp – My Title</title>|
    end

    test "suffix only" do
      assigns = %{}

      assert render(~H|<.live_title suffix=" – MyApp">My Title</.live_title>|) ==
               ~s|<title data-suffix=" – MyApp">My Title – MyApp</title>|
    end

    test "prefix and suffix" do
      assigns = %{}

      assert render(~H|<.live_title prefix="Welcome: " suffix=" – MyApp">My Title</.live_title>|) ==
               ~s|<title data-prefix="Welcome: " data-suffix=" – MyApp">Welcome: My Title – MyApp</title>|
    end

    test "without prefix or suffix" do
      assigns = %{}

      assert render(~H|<.live_title>My Title</.live_title>|) ==
               ~s|<title>My Title</title>|
    end
  end

  describe "dynamic_tag/1" do
    test "ensures HTML safe tag names" do
      assigns = %{}

      assert_raise ArgumentError, ~r/expected dynamic_tag name to be safe HTML/, fn ->
        render(~H|<.dynamic_tag name="p><script>alert('nice try');</script>"/>|)
      end
    end

    test "escapes attribute values" do
      assigns = %{}

      assert render(
               ~H|<.dynamic_tag name="p" class="<script>alert('nice try');</script>"></.dynamic_tag>|
             ) == ~s|<p class="&lt;script&gt;alert(&#39;nice try&#39;);&lt;/script&gt;"></p>|
    end

    test "escapes attribute names" do
      assigns = %{}

      assert render(
               ~H|<.dynamic_tag name="p" {%{"<script>alert('nice try');</script>" => ""}}></.dynamic_tag>|
             ) == ~s|<p &lt;script&gt;alert(&#39;nice try&#39;);&lt;/script&gt;=""></p>|
    end

    test "with empty inner block" do
      assigns = %{}

      assert render(~H|<.dynamic_tag name="tr"></.dynamic_tag>|) == ~s|<tr></tr>|

      assert render(~H|<.dynamic_tag name="tr" class="foo"></.dynamic_tag>|) ==
               ~s|<tr class="foo"></tr>|
    end

    test "with inner block" do
      assigns = %{}

      assert render(~H|<.dynamic_tag name="tr">content</.dynamic_tag>|) == ~s|<tr>content</tr>|

      assert render(~H|<.dynamic_tag name="tr" class="foo">content</.dynamic_tag>|) ==
               ~s|<tr class="foo">content</tr>|
    end

    test "self closing without inner block" do
      assigns = %{}

      assert render(~H|<.dynamic_tag name="br"/>|) == ~s|<br/>|
      assert render(~H|<.dynamic_tag name="input" type="text"/>|) == ~s|<input type="text"/>|
    end

    test "keeps underscores in attributes" do
      assigns = %{}

      assert render(~H|<.dynamic_tag name="br" foo_bar="baz"/>|) == ~s|<br foo_bar="baz"/>|
    end
  end

  describe "form" do
    test "let without :for" do
      assigns = %{}

      template = ~H"""
      <.form :let={f}>
        <%= text_input f, :foo %>
      </.form>
      """

      assert parse(template)
    end

    test "generates form with prebuilt form" do
      assigns = %{form: to_form(%{})}

      template = ~H"""
      <.form for={@form}>
        <%= text_input @form, :foo %>
      </.form>
      """

      html = parse(template)

      assert [
               {"form", [],
                [
                  {"input", [{"id", "foo"}, {"name", "foo"}, {"type", "text"}], []}
                ]}
             ] = html
    end

    test "generates form with prebuilt form and :as" do
      assigns = %{form: to_form(%{}, as: :data)}

      template = ~H"""
      <.form :let={f} for={@form}>
        <input id={f[:foo].id} name={f[:foo].name} type="text" />
      </.form>
      """

      html = parse(template)

      assert [
               {"form", [],
                [
                  {"input", [{"id", "data_foo"}, {"name", "data[foo]"}, {"type", "text"}], []}
                ]}
             ] = html
    end

    test "generates form with prebuilt form and options" do
      assigns = %{form: to_form(%{})}

      template = ~H"""
      <.form :let={f} for={@form} as="base" data-foo="bar" class="pretty" phx-change="valid">
        <%= text_input f, :foo %>
      </.form>
      """

      html = parse(template)

      assert [
               {"form", [{"class", "pretty"}, {"data-foo", "bar"}, {"phx-change", "valid"}],
                [
                  {"input", [{"id", "base_foo"}, {"name", "base[foo]"}, {"type", "text"}], []}
                ]}
             ] = html
    end

    test "generates form with prebuilt form and errors" do
      assigns = %{form: to_form(%{})}

      template = ~H"""
      <.form :let={form} for={@form} errors={[name: "can't be blank"]}>
        <%= inspect(form.errors) %>
      </.form>
      """

      html = parse(template)

      assert [
               {"form", [], ["\n  \n  \n  \n  [name: \"can't be blank\"]\n\n"]}
             ] = html
    end

    test "generates form with form data" do
      assigns = %{}

      template = ~H"""
      <.form :let={f} for={%{}}>
        <%= text_input f, :foo %>
      </.form>
      """

      html = parse(template)

      assert [
               {"form", [],
                [
                  {"input", [{"id", "foo"}, {"name", "foo"}, {"type", "text"}], []}
                ]}
             ] = html
    end

    test "does not raise when action is given and method is missing" do
      assigns = %{}

      template = ~H"""
      <.form for={%{}} action="/">
      </.form>
      """

      html = parse(template)
      assert [{"form", [{"action", "/"}, {"method", "post"}], _}] = html
    end

    test "generates a csrf_token if if an action is set" do
      assigns = %{}

      template = ~H"""
      <.form :let={f} for={%{}} action="/">
        <%= text_input f, :foo %>
      </.form>
      """

      html = parse(template)
      csrf_token = Plug.CSRFProtection.get_csrf_token_for("/")

      assert [
               {"form", [{"action", "/"}, {"method", "post"}],
                [
                  {"input",
                   [
                     {"name", "_csrf_token"},
                     {"type", "hidden"},
                     {"hidden", "hidden"},
                     {"value", ^csrf_token}
                   ], []},
                  {"input", [{"id", "foo"}, {"name", "foo"}, {"type", "text"}], []}
                ]}
             ] = html
    end

    test "does not generate csrf_token if method is not post or if no action" do
      assigns = %{}

      template = ~H"""
      <.form :let={f} for={%{}} method="get" action="/">
        <%= text_input f, :foo %>
      </.form>
      """

      html = parse(template)

      assert [
               {"form", [{"action", "/"}, {"method", "get"}],
                [
                  {"input", [{"id", "foo"}, {"name", "foo"}, {"type", "text"}], []}
                ]}
             ] = html

      template = ~H"""
      <.form :let={f} for={%{}}>
        <%= text_input f, :foo %>
      </.form>
      """

      html = parse(template)

      assert [
               {"form", [],
                [
                  {"input", [{"id", "foo"}, {"name", "foo"}, {"type", "text"}], []}
                ]}
             ] = html
    end

    test "generates form with available options and custom attributes" do
      assigns = %{}

      template = ~H"""
      <.form :let={user_form}
        for={%{}}
        id="form"
        action="/"
        method="put"
        multipart
        csrf_token="123"
        as={:user}
        errors={[name: "can't be blank"]}
        data-foo="bar"
        class="pretty"
        phx-change="valid"
      >
        <%= text_input user_form, :foo %>
        <%= inspect(user_form.errors) %>
      </.form>
      """

      html = parse(template)

      assert [
               {"form",
                [
                  {"enctype", "multipart/form-data"},
                  {"action", "/"},
                  {"method", "post"},
                  {"class", "pretty"},
                  {"data-foo", "bar"},
                  {"id", "form"},
                  {"phx-change", "valid"}
                ],
                [
                  {"input",
                   [
                     {"name", "_method"},
                     {"type", "hidden"},
                     {"hidden", "hidden"},
                     {"value", "put"}
                   ], []},
                  {"input",
                   [
                     {"name", "_csrf_token"},
                     {"type", "hidden"},
                     {"hidden", "hidden"},
                     {"value", "123"}
                   ], []},
                  {"input", [{"id", "form_foo"}, {"name", "user[foo]"}, {"type", "text"}], []},
                  "\n  [name: \"can't be blank\"]\n\n"
                ]}
             ] = html
    end
  end

  describe "inputs_for" do
    test "generates nested inputs with no options" do
      assigns = %{}

      template = ~H"""
        <.form :let={f} as={:myform}>
          <.inputs_for :let={finner} field={f[:inner]}}>
            <%= text_input finner, :foo %>
          </.inputs_for>
        </.form>
      """

      html = parse(template)

      assert [
               {
                 "form",
                 [],
                 [
                   {"input",
                    [
                      {"type", "hidden"},
                      {"name", "myform[inner][_persistent_id]"},
                      {"value", "0"}
                    ], []},
                   {"input", [{"id", "myform_inner_0_foo"}, {"name", "myform[inner][foo]"}, {"type", "text"}],
                    []}
                 ]
               }
             ] = html
    end

    test "with naming options" do
      assigns = %{}

      template = ~H"""
        <.form :let={f} as={:myform}>
          <.inputs_for :let={finner} field={f[:inner]}} id="test" as={:name}>
            <%= text_input finner, :foo %>
          </.inputs_for>
        </.form>
      """

      html = parse(template)

      assert [
               {
                 "form",
                 [],
                 [
                   {"input",
                    [{"type", "hidden"}, {"name", "name[_persistent_id]"}, {"value", "0"}], []},
                   {"input", [{"id", "myform_inner_0_foo"}, {"name", "name[foo]"}, {"type", "text"}], []}
                 ]
               }
             ] = html
    end

    test "with default map option" do
      assigns = %{}

      template = ~H"""
        <.form :let={f} as={:myform}>
          <.inputs_for :let={finner} field={f[:inner]}} default={%{foo: "123"}}>
            <%= text_input finner, :foo %>
          </.inputs_for>
        </.form>
      """

      html = parse(template)

      assert [
               {
                 "form",
                 [],
                 [
                   {"input",
                    [
                      {"type", "hidden"},
                      {"name", "myform[inner][_persistent_id]"},
                      {"value", "0"}
                    ], []},
                   {"input",
                    [
                      {"id", "myform_inner_0_foo"},
                      {"name", "myform[inner][foo]"},
                      {"type", "text"},
                      {"value", "123"}
                    ], []}
                 ]
               }
             ] = html
    end

    test "with default list and list related options" do
      assigns = %{}

      template = ~H"""
        <.form :let={f} as={:myform}>
          <.inputs_for
            :let={finner}
            field={f[:inner]}}
            default={[%{foo: "456"}]}
            prepend={[%{foo: "123"}]}
            append={[%{foo: "789"}]}
          >
            <%= text_input finner, :foo %>
          </.inputs_for>
        </.form>
      """

      html = parse(template)

      assert [
               {
                 "form",
                 [],
                 [
                   {"input",
                    [
                      {"type", "hidden"},
                      {"name", "myform[inner][0][_persistent_id]"},
                      {"value", "0"}
                    ], []},
                   {"input",
                    [
                      {"id", "myform_inner_0_foo"},
                      {"name", "myform[inner][0][foo]"},
                      {"type", "text"},
                      {"value", "123"}
                    ], []},
                   {"input",
                    [
                      {"type", "hidden"},
                      {"name", "myform[inner][1][_persistent_id]"},
                      {"value", "1"}
                    ], []},
                   {"input",
                    [
                      {"id", "myform_inner_1_foo"},
                      {"name", "myform[inner][1][foo]"},
                      {"type", "text"},
                      {"value", "456"}
                    ], []},
                   {"input",
                    [
                      {"type", "hidden"},
                      {"name", "myform[inner][2][_persistent_id]"},
                      {"value", "2"}
                    ], []},
                   {"input",
                    [
                      {"id", "myform_inner_2_foo"},
                      {"name", "myform[inner][2][foo]"},
                      {"type", "text"},
                      {"value", "789"}
                    ], []}
                 ]
               }
             ] = html
    end
  end

  describe "live_file_input/1" do
    test "renders attributes" do
      assigns = %{
        conf: %Phoenix.LiveView.UploadConfig{
          auto_upload?: true,
          entries: [%{preflighted?: false, done?: false, ref: "foo"}]
        }
      }

      assert render(
               ~H|<.live_file_input upload={@conf} class={"<script>alert('nice try');</script>"} />|
             ) ==
               ~s|<input type="file" accept="" data-phx-hook="Phoenix.LiveFileUpload" data-phx-update="ignore" data-phx-active-refs="foo" data-phx-done-refs="" data-phx-preflighted-refs="" data-phx-auto-upload class="&lt;script&gt;alert(&#39;nice try&#39;);&lt;/script&gt;">|
    end

    test "renders optional webkitdirectory attribute" do
      assigns = %{
        conf: %Phoenix.LiveView.UploadConfig{
          entries: [%{preflighted?: false, done?: false, ref: "foo"}]
        }
      }

      assert render(~H|<.live_file_input upload={@conf} webkitdirectory />|) ==
               ~s|<input type="file" accept="" data-phx-hook="Phoenix.LiveFileUpload" data-phx-update="ignore" data-phx-active-refs="foo" data-phx-done-refs="" data-phx-preflighted-refs="" webkitdirectory>|
    end

    test "sets accept from config" do
      assigns = %{
        conf: %Phoenix.LiveView.UploadConfig{
          accept: ~w(.png),
          entries: [%{preflighted?: false, done?: false, ref: "foo"}]
        }
      }

      assert render(~H|<.live_file_input upload={@conf} />|) ==
               ~s|<input type="file" accept=".png" data-phx-hook="Phoenix.LiveFileUpload" data-phx-update="ignore" data-phx-active-refs="foo" data-phx-done-refs="" data-phx-preflighted-refs="">|
    end

    test "renders accept override" do
      assigns = %{
        conf: %Phoenix.LiveView.UploadConfig{
          accept: ~w(.png),
          entries: [%{preflighted?: false, done?: false, ref: "foo"}]
        }
      }

      assert render(~H|<.live_file_input upload={@conf} accept=".jpeg" />|) ==
               ~s|<input type="file" accept=".jpeg" data-phx-hook="Phoenix.LiveFileUpload" data-phx-update="ignore" data-phx-active-refs="foo" data-phx-done-refs="" data-phx-preflighted-refs="">|
    end
  end

  describe "intersperse" do
    test "generates form with no options" do
      assigns = %{}

      template = ~H"""
      <.intersperse :let={item} enum={[1, 2, 3]}>
        <:separator><span class="sep">|</span></:separator>
        Item<%= item %>
      </.intersperse>
      """

      assert render(template) ==
               "\n  Item1\n<span class=\"sep\">|</span>\n  Item2\n<span class=\"sep\">|</span>\n  Item3\n"

      template = ~H"""
      <.intersperse :let={item} enum={[1]}>
        <:separator><span class="sep">|</span></:separator>
        Item<%= item %>
      </.intersperse>
      """

      assert render(template) == "\n  Item1\n"
    end
  end
end
