defmodule Phoenix.LiveView.HelpersTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveView.Helpers
  import Phoenix.Component

  defp render(template) do
    template
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  test "deprecated live_file_input escapes attributes" do
    assigns = %{}

    assert render(
             ~H|<%= live_file_input %Phoenix.LiveView.UploadConfig{}, class: "<script>alert('nice try');</script>" %>|
           ) ==
             ~s|<input type="file" accept="" data-phx-hook="Phoenix.LiveFileUpload" data-phx-update="ignore" data-phx-active-refs="" data-phx-done-refs="" data-phx-preflighted-refs="" class="&lt;script&gt;alert(&#39;nice try&#39;);&lt;/script&gt;">|
  end
end
