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
               fn type, msg -> send(self(), {:error, type, msg}) end
             )

      assert_receive {:error, :duplicate_id, msg}
      assert msg =~ "Duplicate id found while testing LiveView"
    end

    test "handles declarations (issue #3594)" do
      assert DOM.parse_fragment(
               """
               <div id="foo">
                 <?xml version="1.0" standalone="yes"?>
               </div>
               """,
               fn type, msg -> send(self(), {:error, type, msg}) end
             )

      refute_receive {:error, _, _}
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
               fn type, msg -> send(self(), {:error, type, msg}) end
             )

      assert_receive {:error, :duplicate_id, msg}
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
               fn type, msg -> send(self(), {:error, type, msg}) end
             )

      refute_receive {:error, _, _}
    end
  end
end
