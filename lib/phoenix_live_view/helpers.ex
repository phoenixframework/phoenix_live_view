defmodule Phoenix.LiveView.Helpers do
  @moduledoc false

  import Phoenix.Component
  alias Phoenix.LiveView.Socket

  @doc """
  Provides `~L` sigil with HTML safe Live EEx syntax inside source files.

      iex> ~L"\""
      ...> Hello <%= "world" %>
      ...> "\""
      {:safe, ["Hello ", "world", "\\n"]}

  """
  @deprecated "Use ~H instead"
  defmacro sigil_L({:<<>>, meta, [expr]}, []) do
    options = [
      engine: Phoenix.LiveView.Engine,
      file: __CALLER__.file,
      line: __CALLER__.line + 1,
      indentation: meta[:indentation] || 0
    ]

    EEx.compile_string(expr, options)
  end

  @deprecated "Use link/1 instead"
  def live_patch(opts) when is_list(opts) do
    live_link("patch", Keyword.fetch!(opts, :do), Keyword.delete(opts, :do))
  end

  @deprecated "Use <.link> instead"
  def live_patch(text, opts)

  def live_patch(%Socket{}, _) do
    raise """
    you are invoking live_patch/2 with a socket but a socket is not expected.

    If you want to live_patch/2 inside a LiveView, use push_patch/2 instead.
    If you are inside a template, make sure the first argument is a string.
    """
  end

  def live_patch(opts, do: block) when is_list(opts) do
    live_link("patch", block, opts)
  end

  def live_patch(text, opts) when is_list(opts) do
    live_link("patch", text, opts)
  end

  @deprecated "Use <.link> instead"
  def live_redirect(opts) when is_list(opts) do
    live_link("redirect", Keyword.fetch!(opts, :do), Keyword.delete(opts, :do))
  end

  @deprecated "Use <.link> instead"
  def live_redirect(text, opts)

  def live_redirect(%Socket{}, _) do
    raise """
    you are invoking live_redirect/2 with a socket but a socket is not expected.

    If you want to live_redirect/2 inside a LiveView, use push_redirect/2 instead.
    If you are inside a template, make sure the first argument is a string.
    """
  end

  def live_redirect(opts, do: block) when is_list(opts) do
    live_link("redirect", block, opts)
  end

  def live_redirect(text, opts) when is_list(opts) do
    live_link("redirect", text, opts)
  end

  defp live_link(type, block_or_text, opts) do
    uri = Keyword.fetch!(opts, :to)
    replace = Keyword.get(opts, :replace, false)
    kind = if replace, do: "replace", else: "push"

    data = [phx_link: type, phx_link_state: kind]

    opts =
      opts
      |> Keyword.update(:data, data, &Keyword.merge(&1, data))
      |> Keyword.put(:href, uri)
      |> Keyword.delete(:to)

    assigns = %{opts: opts, content: block_or_text}

    ~H|<a {@opts}><%= @content %></a>|
  end

  @deprecated "Use <.live_title> instead"
  def live_title_tag(title, opts \\ []) do
    assigns = %{title: title, prefix: opts[:prefix], suffix: opts[:suffix]}

    ~H"""
    <Phoenix.Component.live_title prefix={@prefix} suffix={@suffix}>
      <%= @title %>
    </Phoenix.Component.live_title>
    """
  end
end
