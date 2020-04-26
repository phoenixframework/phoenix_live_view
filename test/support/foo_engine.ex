defmodule Phoenix.LiveViewTest.FooEngine do
  def compile(template, path) do
    (File.read!(template) <> "compiled by FooEngine!")
    |> EEx.compile_string(engine: Phoenix.LiveView.Engine, file: path, line: 1)
  end
end
