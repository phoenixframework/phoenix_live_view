defmodule Phoenix.LiveViewTest.DOMWarnTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Phoenix.LiveViewTest.DOM

  describe "parse" do
    test "detects duplicate ids" do
      assert capture_io(:stderr, fn ->
               DOM.parse("""
               <div id="foo">
                 <div id="foo"></div>
               </div>
               """)
             end) =~ "Duplicate id found while testing LiveView"
    end

    test "handles declarations (issue #3594)" do
      assert DOM.parse("""
             <div id="foo">
               <?xml version="1.0" standalone="yes"?>
             </div>
             """)
    end
  end
end
