defmodule Phoenix.LiveViewTest.DOMTest do
  use ExUnit.Case, async: true

  alias Phoenix.LiveViewTest.DOM

  describe "parse_fragment" do
    test "detects duplicate ids" do
      assert DOM.parse_fragment(
               """
               <div id="foo">
                 <div id="foo"></div>
               </div>
               """,
               fn msg -> send(self(), {:error, msg}) end
             )

      assert_receive {:error, msg}
      assert msg =~ "Duplicate id found while testing LiveView"
    end

    test "handles declarations (issue #3594)" do
      assert DOM.parse_fragment(
               """
               <div id="foo">
                 <?xml version="1.0" standalone="yes"?>
               </div>
               """,
               fn msg -> send(self(), {:error, msg}) end
             )

      refute_receive {:error, _}
    end
  end

  describe "parse_document" do
    test "detects duplicate ids" do
      assert DOM.parse_document(
               """
               <html>
                <body>
                  <div id="foo">
                    <div id="foo"></div>
                  </div>
                </body>
               </html>
               """,
               fn msg -> send(self(), {:error, msg}) end
             )

      assert_receive {:error, msg}
      assert msg =~ "Duplicate id found while testing LiveView"
    end

    test "handles declarations (issue #3594)" do
      assert DOM.parse_document(
               """
               <html>
                <body>
                  <div id="foo">
                    <?xml version="1.0" standalone="yes"?>
                  </div>
                </body>
               </html>
               """,
               fn msg -> send(self(), {:error, msg}) end
             )

      refute_receive {:error, _}
    end
  end
end
