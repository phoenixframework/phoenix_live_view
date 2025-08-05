defmodule Phoenix.LiveView.ComponentsTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO
  import Phoenix.Component
  import Phoenix.LiveViewTest.TreeDOM, only: [t2h: 1, sigil_X: 2, sigil_x: 2]

  alias Phoenix.LiveViewTest.TreeDOM

  describe "link patch" do
    test "basic usage" do
      assigns = %{}

      assert t2h(~H|<.link patch="/home">text</.link>|) ==
               ~X[<a data-phx-link="patch" data-phx-link-state="push" href="/home">text</a>]
    end

    test "forwards global dom attributes" do
      assigns = %{}

      assert t2h(~H|<.link patch="/" class="btn btn-large" data={[page_number: 2]}>next</.link>|) ==
               ~X[<a class="btn btn-large" data-page-number="2" data-phx-link="patch" data-phx-link-state="push" href="/">next</a>]
    end
  end

  describe "link navigate" do
    test "basic usage" do
      assigns = %{}

      assert t2h(~H|<.link navigate="/">text</.link>|) ==
               ~X[<a data-phx-link="redirect" data-phx-link-state="push" href="/">text</a>]
    end

    test "forwards global dom attributes" do
      assigns = %{}

      assert t2h(
               ~H|<.link navigate="/" class="btn btn-large" data={[page_number: 2]}>text</.link>|
             ) ==
               ~X[<a class="btn btn-large" data-page-number="2" data-phx-link="redirect" data-phx-link-state="push" href="/">text</a>]
    end
  end

  describe "link href" do
    test "basic usage" do
      assigns = %{}
      assert t2h(~H|<.link href="/">text</.link>|) == ~X|<a href="/">text</a>|
    end

    test "arbitrary attrs" do
      assigns = %{}

      assert t2h(~H|<.link href="/" class="foo">text</.link>|) ==
               ~X|<a href="/" class="foo">text</a>|
    end

    test "with no href" do
      assigns = %{}

      assert t2h(~H|<.link phx-click="click">text</.link>|) ==
               ~X|<a href="#" phx-click="click">text</a>|
    end

    test "with # ref" do
      assigns = %{}

      assert t2h(~H|<.link href="#" phx-click="click">text</.link>|) ==
               ~X|<a href="#" phx-click="click">text</a>|
    end

    test "with nil href" do
      assigns = %{}

      assert t2h(~H|<.link href={nil} phx-click="click">text</.link>|) ==
               ~X|<a href="#" phx-click="click">text</a>|
    end

    test "csrf with get method" do
      assigns = %{}

      assert t2h(~H|<.link href="/" method="get">text</.link>|) == ~X|<a href="/">text</a>|

      assert t2h(~H|<.link href="/" method="get" csrf_token="123">text</.link>|) ==
               ~X|<a href="/">text</a>|
    end

    test "csrf with non-get method" do
      assigns = %{}
      csrf = Plug.CSRFProtection.get_csrf_token_for("/users")

      assert t2h(~H|<.link href="/users" method="delete">delete</.link>|) ==
               ~x|<a href="/users" data-method="delete" data-csrf="#{csrf}" data-to="/users">delete</a>|

      assert t2h(~H|<.link href="/users" method="delete" csrf_token={true}>delete</.link>|) ==
               ~x|<a href="/users" data-method="delete" data-csrf="#{csrf}" data-to="/users">delete</a>|

      assert t2h(~H|<.link href="/users" method="delete" csrf_token={false}>delete</.link>|) ==
               ~X|<a href="/users" data-method="delete" data-to="/users">delete</a>|
    end

    test "csrf with custom token" do
      assigns = %{}

      assert t2h(~H|<.link href="/users" method="post" csrf_token="123">delete</.link>|) ==
               ~X|<a href="/users" data-method="post" data-csrf="123" data-to="/users">delete</a>|
    end

    test "csrf with confirm" do
      assigns = %{}

      assert t2h(
               ~H|<.link href="/users" method="post" csrf_token="123" data-confirm="are you sure?">delete</.link>|
             ) ==
               ~X|<a href="/users" data-method="post" data-csrf="123" data-to="/users" data-confirm="are you sure?">delete</a>|
    end

    test "js schemes" do
      assigns = %{}

      assert t2h(~H|<.link href={{:javascript, "alert('bad')"}}>js</.link>|) ==
               ~X|<a href="javascript:alert(&#39;bad&#39;)">js</a>|
    end

    test "invalid schemes" do
      assigns = %{}

      assert_raise ArgumentError, ~r/unsupported scheme given to <.link>/, fn ->
        t2h(~H|<.link href="javascript:alert('bad')">bad</.link>|) ==
          ~X|<a href="/users" data-method="post" data-csrf="123">delete</a>|
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

      assert t2h(template) ==
               ~X"""
               <div id="wrap" phx-hook="Phoenix.FocusWrap" class="foo">
                 <div id="wrap-start" tabindex="0" aria-hidden="true"></div>
                 <div>content</div>
                 <div id="wrap-end" tabindex="0" aria-hidden="true"></div>
               </div>
               """
    end
  end

  describe "live_title/2" do
    test "dynamic attrs" do
      assigns = %{prefix: "MyApp – ", title: "My Title"}

      assert t2h(~H|<.live_title prefix={@prefix}>{@title}</.live_title>|) ==
               ~X|<title data-prefix="MyApp – ">MyApp – My Title</title>|
    end

    test "prefix only" do
      assigns = %{}

      assert t2h(~H|<.live_title prefix="MyApp – ">My Title</.live_title>|) ==
               ~X|<title data-prefix="MyApp – ">MyApp – My Title</title>|
    end

    test "suffix only" do
      assigns = %{}

      assert t2h(~H|<.live_title suffix=" – MyApp">My Title</.live_title>|) ==
               ~X|<title data-suffix=" – MyApp">My Title – MyApp</title>|
    end

    test "prefix and suffix" do
      assigns = %{}

      assert t2h(~H|<.live_title prefix="Welcome: " suffix=" – MyApp">My Title</.live_title>|) ==
               ~X|<title data-prefix="Welcome: " data-suffix=" – MyApp">Welcome: My Title – MyApp</title>|
    end

    test "without prefix or suffix" do
      assigns = %{}

      assert t2h(~H|<.live_title>My Title</.live_title>|) ==
               ~X|<title>My Title</title>|
    end

    test "default with blank inner block" do
      assigns = %{
        val: """


        """
      }

      assert t2h(~H|<.live_title default="DEFAULT" phx-no-format>   <%= @val %>   </.live_title>|) ==
               ~X|<title data-default="DEFAULT">DEFAULT</title>|
    end

    test "default with present inner block" do
      assigns = %{val: "My Title"}

      assert t2h(~H|<.live_title default="DEFAULT" phx-no-format>   <%= @val %>   </.live_title>|) ==
               ~X|<title data-default="DEFAULT">   My Title   </title>|
    end
  end

  describe "dynamic_tag/1" do
    test "ensures HTML safe tag names" do
      assigns = %{}

      assert_raise ArgumentError, ~r/expected dynamic_tag name to be safe HTML/, fn ->
        t2h(~H|<.dynamic_tag tag_name="p><script>alert('nice try');</script>" />|)
      end
    end

    test "escapes attribute values" do
      assigns = %{}

      assert t2h(
               ~H|<.dynamic_tag tag_name="p" class="<script>alert('nice try');</script>"></.dynamic_tag>|
             ) == ~X|<p class="&lt;script&gt;alert(&#39;nice try&#39;);&lt;/script&gt;"></p>|
    end

    test "escapes attribute names" do
      assigns = %{}

      assert t2h(
               ~H|<.dynamic_tag tag_name="p" {%{"<script>alert('nice try');</script>" => ""}}></.dynamic_tag>|
             ) == ~X|<p &lt;script&gt;alert(&#39;nice try&#39;);&lt;/script&gt;=""></p>|
    end

    test "with empty inner block" do
      assigns = %{}

      assert t2h(~H|<.dynamic_tag tag_name="tr"></.dynamic_tag>|) == ~X|<tr></tr>|

      assert t2h(~H|<.dynamic_tag tag_name="tr" class="foo"></.dynamic_tag>|) ==
               ~X|<tr class="foo"></tr>|
    end

    test "with inner block" do
      assigns = %{}

      assert t2h(~H|<.dynamic_tag tag_name="tr">content</.dynamic_tag>|) == ~X|<tr>content</tr>|

      assert t2h(~H|<.dynamic_tag tag_name="tr" class="foo">content</.dynamic_tag>|) ==
               ~X|<tr class="foo">content</tr>|
    end

    test "self closing without inner block" do
      assigns = %{}

      assert t2h(~H|<.dynamic_tag tag_name="br" />|) == ~X|<br/>|
      assert t2h(~H|<.dynamic_tag tag_name="input" type="text" />|) == ~X|<input type="text"/>|
    end

    test "keeps underscores in attributes" do
      assigns = %{}

      assert t2h(~H|<.dynamic_tag tag_name="br" foo_bar="baz" />|) == ~X|<br foo_bar="baz"/>|
    end

    test "can pass tag_name and name" do
      assigns = %{}

      assert t2h(~H|<.dynamic_tag tag_name="input" name="my-input" />|) ==
               ~X|<input name="my-input"/>|
    end

    test "warns when using deprecated name attribute" do
      assigns = %{}

      assert capture_io(:stderr, fn ->
               assert t2h(~H|<.dynamic_tag name="br" foo_bar="baz" />|) == ~X|<br foo_bar="baz"/>|
             end) =~
               "Passing the tag name to `Phoenix.Component.dynamic_tag/1` using the `name` attribute is deprecated"
    end
  end

  describe "form" do
    test "let without :for" do
      assigns = %{}

      template = ~H"""
      <.form :let={f}>
        <input id={f[:foo].id} name={f[:foo].name} type="text" />
      </.form>
      """

      assert t2h(template) == ~X[<form><input id="foo" name="foo" type="text"></input></form>]
    end

    test "generates form with prebuilt form" do
      assigns = %{form: to_form(%{})}

      template = ~H"""
      <.form for={@form}>
        <input id={@form[:foo].id} name={@form[:foo].name} type="text" />
      </.form>
      """

      assert t2h(template) == ~X[<form><input id="foo" name="foo" type="text"></input></form>]
    end

    test "generates form with prebuilt form and :as" do
      assigns = %{form: to_form(%{}, as: :data)}

      template = ~H"""
      <.form :let={f} for={@form}>
        <input id={f[:foo].id} name={f[:foo].name} type="text" />
      </.form>
      """

      assert t2h(template) ==
               ~X{<form><input id="data_foo" name="data[foo]" type="text"></input></form>}
    end

    test "generates form with prebuilt form and options" do
      assigns = %{form: to_form(%{})}

      template = ~H"""
      <.form :let={f} for={@form} as="base" data-foo="bar" class="pretty" phx-change="valid">
        <input id={f[:foo].id} name={f[:foo].name} type="text" />
      </.form>
      """

      assert t2h(template) ==
               ~X"""
               <form data-foo="bar" class="pretty" phx-change="valid">
                 <input id="base_foo" name=base[foo] type="text"/>
               </form>
               """
    end

    test "generates form with prebuilt form and errors" do
      assigns = %{form: to_form(%{})}

      template = ~H"""
      <.form :let={form} for={@form} errors={[name: "can't be blank"]}>
        {inspect(form.errors)}
      </.form>
      """

      assert t2h(template) == [{"form", [], ["\n  \n  \n  \n  [name: \"can't be blank\"]\n\n"]}]
    end

    test "generates form with form data" do
      assigns = %{}

      template = ~H"""
      <.form :let={f} for={%{}}>
        <input id={f[:foo].id} name={f[:foo].name} type="text" />
      </.form>
      """

      assert t2h(template) ==
               ~X{<form><input id="foo" name="foo" type="text"></input></form>}
    end

    test "does not raise when action is given and method is missing" do
      assigns = %{}

      template = ~H"""
      <.form for={%{}} action="/"></.form>
      """

      csrf_token = Plug.CSRFProtection.get_csrf_token_for("/")

      assert t2h(template) ==
               ~x{<form action="/" method="post"><input name="_csrf_token" type="hidden" hidden="" value="#{csrf_token}"></input></form>}
    end

    test "generates a csrf_token if if an action is set" do
      assigns = %{}

      template = ~H"""
      <.form :let={f} for={%{}} action="/">
        <input id={f[:foo].id} name={f[:foo].name} type="text" />
      </.form>
      """

      csrf_token = Plug.CSRFProtection.get_csrf_token_for("/")

      assert t2h(template) ==
               ~x"""
               <form action="/" method="post">
                 <input name="_csrf_token" type="hidden" hidden="" value="#{csrf_token}"></input>
                 <input id="foo" name="foo" type="text"></input>
               </form>
               """
    end

    test "does not generate csrf_token if method is not post or if no action" do
      assigns = %{}

      template = ~H"""
      <.form :let={f} for={%{}} method="get" action="/">
        <input id={f[:foo].id} name={f[:foo].name} type="text" />
      </.form>
      """

      assert t2h(template) ==
               ~X"""
               <form action="/" method="get">
                 <input id="foo" name="foo" type="text"></input>
               </form>
               """

      template = ~H"""
      <.form :let={f} for={%{}}>
        <input id={f[:foo].id} name={f[:foo].name} type="text" />
      </.form>
      """

      assert t2h(template) ==
               ~X"""
               <form>
                 <input id="foo" name="foo" type="text"></input>
               </form>
               """
    end

    test "generates form with available options and custom attributes" do
      assigns = %{}

      template = ~H"""
      <.form
        :let={user_form}
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
        <input id={user_form[:foo].id} name={user_form[:foo].name} type="text" />
        {inspect(user_form.errors)}
      </.form>
      """

      assert t2h(template) ==
               ~X"""
               <form
                 id="form"
                 action="/"
                 method="post"
                 enctype="multipart/form-data"
                 data-foo="bar"
                 class="pretty"
                 phx-change="valid"
               >
                 <input name="_method" type="hidden" hidden="" value="put">
                 <input name="_csrf_token" type="hidden" hidden="" value="123">
                 <input id="form_foo" name="user[foo]" type="text">
                 [name: "can't be blank"]

               </form>
               """
    end

    test "method is case insensitive when using get or post with action" do
      assigns = %{}

      template = ~H"""
      <.form for={%{}} method="GET" action="/"></.form>
      """

      assert t2h(template) ==
               ~x{<form method="get" action="/"></form>}

      template = ~H"""
      <.form for={%{}} method="PoST" action="/"></.form>
      """

      csrf = Plug.CSRFProtection.get_csrf_token_for("/")

      assert t2h(template) ==
               ~x{<form method="post" action="/"><input name="_csrf_token" type="hidden" hidden="" value="#{csrf}"></form>}

      # for anything != get or post we use post and set the hidden _method field
      template = ~H"""
      <.form for={%{}} method="PuT" action="/"></.form>
      """

      assert t2h(template) ==
               ~x"""
               <form action="/" method="post">
                 <input name="_method" type="hidden" hidden="" value="PuT">
                 <input name="_csrf_token" type="hidden" hidden="" value="#{csrf}">
               </form>
               """
    end
  end

  describe "inputs_for" do
    test "generates nested inputs with no options" do
      assigns = %{}

      template = ~H"""
      <.form :let={f} as={:myform}>
        <.inputs_for :let={finner} field={f[:inner]}>
          <% 0 = finner.index %>
          <input id={finner[:foo].id} name={finner[:foo].name} type="text" />
        </.inputs_for>
      </.form>
      """

      assert t2h(template) ==
               ~X"""
               <form>
                 <input type="hidden" name="myform[inner][_persistent_id]" value="0"> </input>
                 <input id="myform_inner_0_foo" name="myform[inner][foo]" type="text"></input>
               </form>
               """
    end

    test "with naming options" do
      assigns = %{}

      template = ~H"""
      <.form :let={f} as={:myform}>
        <.inputs_for :let={finner} field={f[:inner]} id="test" as={:name}>
          <input id={finner[:foo].id} name={finner[:foo].name} type="text" />
        </.inputs_for>
      </.form>
      """

      assert t2h(template) ==
               ~X"""
               <form>
                 <input type="hidden" name="name[_persistent_id]" value="0"> </input>
                 <input id="test_inner_0_foo" name="name[foo]" type="text"></input>
               </form>
               """

      template = ~H"""
      <.form :let={f} as={:myform}>
        <.inputs_for :let={finner} field={f[:inner]} as={:name}>
          <input id={finner[:foo].id} name={finner[:foo].name} type="text" />
        </.inputs_for>
      </.form>
      """

      assert t2h(template) ==
               ~X"""
               <form>
                 <input type="hidden" name="name[_persistent_id]" value="0"> </input>
                 <input id="myform_inner_0_foo" name="name[foo]" type="text"></input>
               </form>
               """
    end

    test "with default map option" do
      assigns = %{}

      template = ~H"""
      <.form :let={f} as={:myform}>
        <.inputs_for :let={finner} field={f[:inner]} default={%{foo: "123"}}>
          <input id={finner[:foo].id} name={finner[:foo].name} type="text" value={finner[:foo].value} />
        </.inputs_for>
      </.form>
      """

      assert t2h(template) ==
               ~X"""
               <form>
                 <input type="hidden" name="myform[inner][_persistent_id]" value="0"> </input>
                 <input id="myform_inner_0_foo" name="myform[inner][foo]" type="text" value="123"></input>
               </form>
               """
    end

    test "with default list and list related options" do
      assigns = %{}

      template = ~H"""
      <.form :let={f} as={:myform}>
        <.inputs_for
          :let={finner}
          field={f[:inner]}
          default={[%{foo: "456"}]}
          prepend={[%{foo: "123"}]}
          append={[%{foo: "789"}]}
        >
          <input id={finner[:foo].id} name={finner[:foo].name} type="text" value={finner[:foo].value} />
        </.inputs_for>
      </.form>
      """

      assert t2h(template) ==
               ~X"""
               <form>
                 <input type="hidden" name="myform[inner][0][_persistent_id]" value="0"></input>
                 <input id="myform_inner_0_foo" name="myform[inner][0][foo]" type="text" value="123"></input>
                 <input type="hidden" name="myform[inner][1][_persistent_id]" value="1"></input>
                 <input id="myform_inner_1_foo" name="myform[inner][1][foo]" type="text" value="456"></input>
                 <input type="hidden" name="myform[inner][2][_persistent_id]" value="2"></input>
                 <input id="myform_inner_2_foo" name="myform[inner][2][foo]" type="text" value="789"></input>
               </form>
               """
    end

    test "with FormData implementation options" do
      assigns = %{}

      template = ~H"""
      <.form :let={f} as={:myform}>
        <.inputs_for :let={finner} field={f[:inner]} options={[foo: "bar"]}>
          <p>{finner.options[:foo]}</p>
        </.inputs_for>
      </.form>
      """

      html = t2h(template)
      assert [p] = TreeDOM.filter(html, &(TreeDOM.tag(&1) == "p"))
      assert TreeDOM.to_text(p) =~ "bar"
    end

    test "can disable persistent ids" do
      assigns = %{}

      template = ~H"""
      <.form :let={f} as={:myform}>
        <.inputs_for
          :let={finner}
          field={f[:inner]}
          default={[%{foo: "456"}, %{foo: "789"}]}
          prepend={[%{foo: "123"}]}
          append={[%{foo: "101112"}]}
          skip_persistent_id
        >
          <input id={finner[:foo].id} name={finner[:foo].name} type="text" value={finner[:foo].value} />
        </.inputs_for>
      </.form>
      """

      assert t2h(template) ==
               ~X"""
               <form>
                 <input id="myform_inner_0_foo" name="myform[inner][0][foo]" type="text" value="123"></input>
                 <input id="myform_inner_1_foo" name="myform[inner][1][foo]" type="text" value="456"></input>
                 <input id="myform_inner_2_foo" name="myform[inner][2][foo]" type="text" value="789"></input>
                 <input id="myform_inner_3_foo" name="myform[inner][3][foo]" type="text" value="101112"></input>
               </form>
               """
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

      assert t2h(
               ~H|<.live_file_input upload={@conf} class="<script>alert('nice try');</script>" />|
             ) ==
               ~X|<input type="file" accept="" data-phx-hook="Phoenix.LiveFileUpload" data-phx-update="ignore" data-phx-active-refs="foo" data-phx-done-refs="" data-phx-preflighted-refs="" data-phx-auto-upload class="&lt;script&gt;alert(&#39;nice try&#39;);&lt;/script&gt;">|
    end

    test "renders optional webkitdirectory attribute" do
      assigns = %{
        conf: %Phoenix.LiveView.UploadConfig{
          entries: [%{preflighted?: false, done?: false, ref: "foo"}]
        }
      }

      assert t2h(~H|<.live_file_input upload={@conf} webkitdirectory />|) ==
               ~X|<input type="file" accept="" data-phx-hook="Phoenix.LiveFileUpload" data-phx-update="ignore" data-phx-active-refs="foo" data-phx-done-refs="" data-phx-preflighted-refs="" webkitdirectory>|
    end

    test "renders optional capture attribute" do
      assigns = %{
        conf: %Phoenix.LiveView.UploadConfig{
          entries: [%{preflighted?: false, done?: false, ref: "foo"}]
        }
      }

      assert t2h(~H|<.live_file_input upload={@conf} capture="user" />|) ==
               ~X|<input type="file" accept="" data-phx-hook="Phoenix.LiveFileUpload" data-phx-update="ignore" data-phx-active-refs="foo" data-phx-done-refs="" data-phx-preflighted-refs="" capture="user">|
    end

    test "sets accept from config" do
      assigns = %{
        conf: %Phoenix.LiveView.UploadConfig{
          accept: ~w(.png),
          entries: [%{preflighted?: false, done?: false, ref: "foo"}]
        }
      }

      assert t2h(~H|<.live_file_input upload={@conf} />|) ==
               ~X|<input type="file" accept=".png" data-phx-hook="Phoenix.LiveFileUpload" data-phx-update="ignore" data-phx-active-refs="foo" data-phx-done-refs="" data-phx-preflighted-refs="">|
    end

    test "renders accept override" do
      assigns = %{
        conf: %Phoenix.LiveView.UploadConfig{
          accept: ~w(.png),
          entries: [%{preflighted?: false, done?: false, ref: "foo"}]
        }
      }

      assert t2h(~H|<.live_file_input upload={@conf} accept=".jpeg" />|) ==
               ~X|<input type="file" accept=".jpeg" data-phx-hook="Phoenix.LiveFileUpload" data-phx-update="ignore" data-phx-active-refs="foo" data-phx-done-refs="" data-phx-preflighted-refs="">|
    end
  end

  describe "intersperse" do
    test "generates form with no options" do
      assigns = %{}

      template = ~H"""
      <.intersperse :let={item} enum={[1, 2, 3]}>
        <:separator><span class="sep">|</span></:separator>
        Item{item}
      </.intersperse>
      """

      assert Phoenix.LiveViewTest.rendered_to_string(template) ==
               ~s"\n  Item1\n<span class=\"sep\">|</span>\n  Item2\n<span class=\"sep\">|</span>\n  Item3\n"

      template = ~H"""
      <.intersperse :let={item} enum={[1]}>
        <:separator><span class="sep">|</span></:separator>
        Item{item}
      </.intersperse>
      """

      assert Phoenix.LiveViewTest.rendered_to_string(template) == ~s"\n  Item1\n"
    end
  end
end
