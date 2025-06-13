import Browser from "phoenix_live_view/browser";

describe("Browser", () => {
  beforeEach(() => {
    clearCookies();
  });

  describe("setCookie", () => {
    test("sets a cookie", () => {
      Browser.setCookie("apple", 1234);
      Browser.setCookie("orange", "5678");
      expect(document.cookie).toContain("apple");
      expect(document.cookie).toContain("1234");
      expect(document.cookie).toContain("orange");
      expect(document.cookie).toContain("5678");
    });
  });

  describe("getCookie", () => {
    test("returns the value for a cookie", () => {
      document.cookie = "apple=1234";
      document.cookie = "orange=5678";
      expect(Browser.getCookie("apple")).toEqual("1234");
    });
    test("returns an empty string for a non-existent cookie", () => {
      document.cookie = "apple=1234";
      document.cookie = "orange=5678";
      expect(Browser.getCookie("plum")).toEqual("");
    });
  });

  describe("redirect", () => {
    test("redirects to a new URL", () => {
      const navigate = jest.fn();
      const targetUrl = "https://phoenixframework.com";
      Browser.redirect(targetUrl, null, navigate);
      expect(navigate).toHaveBeenCalledWith(targetUrl);
    });

    test("sets a flash cookie before redirecting", () => {
      const navigate = jest.fn();
      const targetUrl = "https://phoenixframework.com";
      const flashMessage = "mango";
      Browser.redirect(targetUrl, flashMessage, navigate);

      expect(document.cookie).toContain("__phoenix_flash__");
      expect(document.cookie).toContain(flashMessage);
      expect(navigate).toHaveBeenCalledWith(targetUrl);
    });
  });
});

// Adapted from https://stackoverflow.com/questions/179355/clearing-all-cookies-with-javascript/179514#179514
function clearCookies() {
  const cookies = document.cookie.split(";");

  for (let i = 0; i < cookies.length; i++) {
    const cookie = cookies[i];
    const eqPos = cookie.indexOf("=");
    const name = eqPos > -1 ? cookie.substr(0, eqPos) : cookie;
    document.cookie = name + "=;expires=Thu, 01 Jan 1970 00:00:00 GMT";
  }
}
