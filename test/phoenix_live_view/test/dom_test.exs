defmodule Phoenix.LiveViewTest.DOMTest do
  use ExUnit.Case, async: true

  alias Phoenix.LiveViewTest.DOM

  # >= 4432 characters
  @too_big_session "SFMyNTY.g3QAAAACZAAEZGF0YXQAAAAELklu8c3Rhmby3VudHeWQACl9feGlyLk5haXZlRGF0ZVRpbWVkAAhjYWxlbmRhcmQAE0VsaXhpci5DYWxlbmRhci5JU09kAANkYXlhHWQABGhvdXJhC2QAC21pY3Jvc2Vjb25kaAJiAAwy0WEGZAAGbWludXRlYSRkAAVtb250aGEEZAAGc2Vjb25kYR5kAAR5ZWFyYgAAB-NkAAlsYXN0X25hbWVtAAAABVNtaXRoZAAIbG9jYXRpb25tAAAABENpdHlkAAxvbGRfcGFzc3dvcmRkAANuaWxkAAhwYXNzd29yZGQAA25pbGQAFXBhc3N3b3JkX2NvbmZpcm1hdGlvbmQAA25pbGQADHBob25lX251bWJlcm0AAAAKMDUwNDAxMjIyMGQACHByb3ZpZGVydAAAAB9kAAhfX21ldGFfX3QAAAAGZAAKX19zdHJ1Y3RfX2QAG0VsaXhpci5FY3RvLlNjaGVtYS5NZXRhZGF0YWQAB2NvbnRleHRkAANuaWxkAAZwcmVmaXhkAANuaWxkAAZzY2hlbWFkACJFbGl4aXIuSW5zdGFmb3RvLkFjY291bnRzLlByb3ZpZGVyZAAGc291cmNlbQAAABFhY2NvdW50X3Byb3ZpZGVyc2QABXN0YXRlZAAGbG9hZGVkZAAKX19zdHJ1Y3RfX2QAIkVsaXhpci5JbnN0YWZvdG8uQWNjb3VudHMuUHJvdmlkZXJkAAphYm91dF9kZXNjbQAAABphYm91dCBwcm92aWRlciBkZXNjcmlwdGlvbmQAB2FjY291bnR0AAAABGQAD19fY2FyZGluYWxpdHlfX2QAA29uZWQACV9fZmllbGRfX2QAB2FjY291bnRkAAlfX293bmVyX19kACJFbGl4aXIuSW5zdGFmb3RvLkFjY291bnRzLlByb3ZpZGVyZAAKX19zdHJ1Y3RfX2QAIUVsaXhpci5FY3RvLkFzc29jaWF0aW9uLk5vdExvYWRlZGQACmFjY291bnRfaWRiAAAG72QAEGJhY2tncm91bmRfaW1hZ2V0AAAABGQAD19fY2FyZGluYWxpdHlfX2QAA29uZWQACV9fZmllbGRfX2QAEGJhY2tncm91bmRfaW1hZ2VkAAlfX293bmVyX19kACJFbGl4aXIuSW5zdGFmb3RvLkFjY291bnRzLlByb3ZpZGVyZAAKX19zdHJ1Y3RfX2QAIUVsaXhpci5FY3RvLkFzc29jaWF0aW9uLk5vdExvYWRlZGQAE2JhY2tncm91bmRfaW1hZ2VfaWRiAAAXRmQAB2NvbXBhbnl0AAAABGQAD19fY2FyZGluYWxpdHlfX2QAA29uZWQACV9fZmllbGRfX2QAB2NvbXBhbnlkAAlfX293bmVyX19kACJFbGl4aXIuSW5zdGFmb3RvLkFjY291bnRzLlByb3ZpZGVyZAAKX19zdHJ1Y3RfX2QAIUVsaXhpci5FY3RvLkFzc29jaWF0aW9uLk5vdExvYWRlZGQACmNvbXBhbnlfaWRiAAAD9WQABWRlYWxzdAAAAARkAA9fX2NhcmRpbmFsaXR5X19kAARtYW55ZAAJX19maWVsZF9fZAAFZGVhbHNkAAlfX293bmVyX19kACJFbGl4aXIuSW5zdGFmb3RvLkFjY291bnRzLlByb3ZpZGVyZAAKX19zdHJ1Y3RfX2QAIUVsaXhpci5FY3RvLkFzc29jaWF0aW9uLk5vdExvYWRlZGQACmVxdWlwbWVudHN0AAAABGQAD19fY2FyZGluYWxpdHlfX2QABG1hbnlkAAlfX2ZpZWxkX19kAAplcXVpcG1lbnRzZAAJX19vd25lcl9fZAAiRWxpeGlyLkluc3RhZm90by5BY2NvdW50cy5Qcm92aWRlcmQACl9fc3RydWN0X19kACFFbGl4aXIuRWN0by5Bc3NvY2lhdGlvbi5Ob3RMb2FkZWRkAApleHBlcmllbmNlbQAAAAhTb21lIGV4cGQAHWhhc19hY2Nlc3NfdG9fcGh5c2ljYWxfc3R1ZGlvZAAEdHJ1ZWQAAmlkYgAAA-lkAAtpbnNlcnRlZF9hdHQAAAAJZAAKX19zdHJ1Y3RfX2QAFEVsaXhpci5OYWl2ZURhdGVUaW1lZAAIY2FsZW5kYXJkABNFbGl4aXIuQ2FsZW5kYXIuSVNPZAADZGF5YR1kAARob3VyYQtkAAttaWNyb3NlY29uZGgCYgAMYv9hBmQABm1pbnV0ZWEkZAAFbW9udGhhBGQABnNlY29uZGEeZAAEeWVhcmIAAAfjZAAHaW52aXRlc3QAAAAEZAAPX19jYXJkaW5hbGl0eV9fZAAEbWFueWQACV9fZmllbGRfX2QAB2ludml0ZXNkAAlfX293bmVyX19kACJFbGl4aXIuSW5zdGFmb3RvLkFjY291bnRzLlByb3ZpZGVyZAAKX19zdHJ1Y3RfX2QAIUVsaXhpci5FY3RvLkFzc29jaWF0aW9uLk5vdExvYWRlZGQAF2lzX2FjY2VwdF9jdXN0b21fb2ZmZXJzZAAEdHJ1ZWQAEmlzX2FjY2VwdF9wYWNrYWdlc2QABHRydWVkABFpc19tdmFfcmVnaXN0ZXJlZGQABWZhbHNlZAAcaXNfc2hvd19yZWdpc3RyYXRpb25fbWVzc2FnZWQABHRydWVkAA5qb2JfbW90aXZhdGlvbm0AAAAJTG92ZSB3b3JrZAAKam9ic19jb3VudGEBZAAJbG9jYXRpb25zdAAAAARkAA9fX2NhcmRpbmFsaXR5X19kAARtYW55ZAAJX19maWVsZF9fZAAJbG9jYXRpb25zZAAJX19vd25lcl9fZAAiRWxpeGlyLkluc3RhZm90by5BY2NvdW50cy5Qcm92aWRlcmQACl9fc3RydWN0X19kACFFbGl4aXIuRWN0by5Bc3NvY2lhdGlvbi5Ob3RMb2FkZWRkAAlwb3J0Zm9saW90AAAABGQAD19fY2FyZGluYWxpdHlfX2QABG1hbnlkAAlfX2ZpZWxkX19kAAlwb3J0Zm9saW9kAAlfX293bmVyX19kACJFbGl4aXIuSW5zdGFmb3RvLkFjY291bnRzLlByb3ZpZGVyZAAKX19zdHJ1Y3RfX2QAIUVsaXhpci5FY3RvLkFzc29jaWF0aW9uLk5vdExvYWRlZGQADnBvcnRmb2xpb19saW5rbQAAABJodHRwczovL2dvb2dsZS5jb21kAAhzZWFzb25lZGQABHRydWVkAA5zZWxlY3RlZF9kZWFsc3QAAAAEZAAPX19jYXJkaW5hbGl0eV9fZAAEbWFueWQACV9fZmllbGRfX2QADnNlbGVjdGVkX2RlYWxzZAAJX19vd25lcl9fZAAiRWxpeGlyLkluc3RhZm90by5BY2NvdW50cy5Qcm92aWRlcmQACl9fc3RydWN0X19kACFFbGl4aXIuRWN0by5Bc3NvY2lhdGlvbi5Ob3RMb2FkZWRkABd1bmxpc3RlZF9lcXVpcG1lbnRfbm90ZW0AAAAXTWlzc2luZyBlcXVpcG1lbnRzIG5vdGVkAAp1cGRhdGVkX2F0dAAAAAlkAApfX3N0cnVjdF9fZAAURWxpeGlyLk5haXZlRGF0ZVRpbWVkAAhjYWxlbmRhcmQAE0VsaXhpci5DYWxlbmRhci5JU09kAANkYXlhHWQABGhvdXJhC2QAC21pY3Jvc2Vjb25kaAJiAAxi_2EGZAAGbWludXRlYSRkAAVtb250aGEEZAAGc2Vjb25kYR5kAAR5ZWFyYgAAB-NkAA93b3JraW5nX2FkZHJlc3NtAAAAD3dvcmtpbmcgYWRkcmVzc2QADXllYXJzX29mX3dvcmthAWQABHNhbHRtAAAABTg4NDA4ZAAQdGVsZWdyYW1fY2hhdF9pZG0AAAAkMDg3YjZjZTItNmE3My0xMWU5LTkyY2EtYWNkZTQ4MDAxMTIyZAAEdHlwZW0AAAAVYWNjb3VudF90eXBlX3Byb3ZpZGVyZAAKdXBkYXRlZF9hdHQAAAAJZAAKX19zdHJ1Y3RfX2QAFEVsaXhpci5OYWl2ZURhdGVUaW1lZAAIY2FsZW5kYXJkABNFbGl4aXIuQ2FsZW5kYXIuSVNPZAADZGF5YR1kAARob3VyYQtkAAttaWNyb3NlY29uZGgCYgAMMtFhBmQABm1pbnV0ZWEkZAAFbW9udGhhBGQABnNlY29uZGEeZAAEeWVhcmIAAAfjZAADemlwbQAAAAdVUzg4OTAwZAAEdmlld2QANEVsaXhpci5JbnN0YWZvdG9XZWIuUHJvdmlkZXJOb3RpZmljYXRpb25Db3VudGVyc0xpdmVkAAZzaWduZWRuBgDb0eFoagE.gKSB6m54OSfL6TBMCkKM2_1UtfEW5crbtT8VNqDX3H0"

  @html """
  <h1>top</h1>
  <div data-phx-view="789"
    data-phx-session="SESSION1"
    id="phx-123"></div>
  <div data-phx-parent-id="456"
      data-phx-view="789"
      data-phx-session="SESSION2"
      data-phx-static="STATIC2"
      id="phx-456"></div>
  <div data-phx-session="#{@too_big_session}"
    data-phx-view="789"
    id="phx-458"></div>
  <h1>bottom</h1>
  """

  test "finds session given html" do
    assert DOM.find_sessions(@html) == [
             {"SESSION1", nil, "phx-123"},
             {"SESSION2", "STATIC2", "phx-456"},
             {@too_big_session, nil, "phx-458"}
           ]

    assert DOM.find_sessions("none") == []
  end

  test "inserts session within html" do
    assert DOM.insert_attr(@html, "data-phx-session", "SESSION1", "<span>session1</span>") == """
           <h1>top</h1>
           <div data-phx-view="789"
             data-phx-session="SESSION1"
             id="phx-123"><span>session1</span></div>
           <div data-phx-parent-id="456"
               data-phx-view="789"
               data-phx-session="SESSION2"
               data-phx-static="STATIC2"
               id="phx-456"></div>
           <div data-phx-session="#{@too_big_session}"
             data-phx-view="789"
             id="phx-458"></div>
           <h1>bottom</h1>
           """

    assert_raise MatchError, fn ->
      assert DOM.insert_attr(@html, "data-phx-session", "not exists", "content") == @html
    end
  end
end
