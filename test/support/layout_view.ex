defmodule Phoenix.LiveViewTest.LayoutView do
  use Phoenix.View, root: ""
  alias Phoenix.LiveViewTest.Router.Helpers, as: Routes
  import Phoenix.LiveView.Helpers

  def render("app.html", assigns) do
    # Assert those assigns are always available
    _ = assigns.live_module
    _ = assigns.live_action

    ["LAYOUT", assigns.inner_content]
  end

  def render("live.html", assigns) do
    ~L"""
    LIVELAYOUTSTART-<%= @val %>-<%= @inner_content %>-LIVELAYOUTEND
    """
  end

  def render("live-override.html", assigns) do
    ~L"""
    LIVEOVERRIDESTART-<%= @val %>-<%= @inner_content %>-LIVEOVERRIDEEND
    """
  end

  def render("widget.html", assigns) do
    ~L"""
    WIDGET:<%= live_render(@conn, Phoenix.LiveViewTest.ClockLive) %>
    """
  end

  def render("with-function-component.html", assigns) do
    ~L"""
    RENDER:<%= component(&Phoenix.LiveViewTest.FunctionComponent.render/1, value: "from component") %>
    """
  end

  def render("layout-with-function-component.html", assigns) do
    ~L"""
    LAYOUT:<%= component(&Phoenix.LiveViewTest.FunctionComponent.render/1, value: "from layout") %>
    <%= @inner_content %>
    """
  end

  def render("hello.html", assigns) do
    ~L"""
    Hello
    """
  end

  def render("styled.html", assigns) do
    ~L"""
    <html>
      <head>
        <link rel="stylesheet" href="/css/custom.css"/>
        <link rel="stylesheet" href="<%= Routes.static_path(@conn, "/css/app.css") %>"/>
        <link rel="stylesheet" href="//example.com/a.css"/>
        <link rel="stylesheet" href="https://example.com/b.css"/>
        <style>body { background-color: #eee; }</style>
        <script>console.log("script")</script>
      </head>
      <body>
        <%= @inner_content %>
      </body>
    </html>
    """
  end
end

defmodule Phoenix.LiveViewTest.AssignsLayoutView do
  use Phoenix.View, root: ""

  def render("app.html", assigns) do
    ["title: #{assigns.title}", assigns.inner_content]
  end
end
