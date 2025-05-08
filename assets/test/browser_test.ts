import Browser from "phoenix_live_view/browser"

describe("Browser", () => {
  beforeEach(() => {
    clearCookies()
  })

  describe("setCookie", () => {
    test("sets a cookie", () => {
      Browser.setCookie("apple", 1234)
      Browser.setCookie("orange", "5678")
      expect(document.cookie).toContain("apple")
      expect(document.cookie).toContain("1234")
      expect(document.cookie).toContain("orange")
      expect(document.cookie).toContain("5678")
    })
  })

  describe("getCookie", () => {
    test("returns the value for a cookie", () => {
      document.cookie = "apple=1234"
      document.cookie = "orange=5678"
      expect(Browser.getCookie("apple")).toEqual("1234")
    })
    test("returns an empty string for a non-existent cookie", () => {
      document.cookie = "apple=1234"
      document.cookie = "orange=5678"
      expect(Browser.getCookie("plum")).toEqual("")
    })
  })

  describe("redirect", () => {
    let originalLocation: Location
    let mockHrefSetter: jest.Mock
    let currentHref: string

    beforeAll(() => {
      originalLocation = window.location
    })

    beforeEach(() => {
      currentHref = "https://example.com" // Initial mocked URL
      mockHrefSetter = jest.fn((newHref: string) => {
        currentHref = newHref
      })

      Object.defineProperty(window, "location", {
        writable: true,
        configurable: true,
        value: {
          get href(){
            return currentHref
          },
          set href(url: string){
            mockHrefSetter(url)
          }
        },
      })
    })

    afterAll(() => {
      // Restore the original window.location object
      Object.defineProperty(window, "location", {
        writable: true,
        configurable: true,
        value: originalLocation,
      })
    })

    test("redirects to a new URL", () => {
      const targetUrl = "https://phoenixframework.com"
      Browser.redirect(targetUrl)
      expect(mockHrefSetter).toHaveBeenCalledWith(targetUrl)
      expect(window.location.href).toEqual(targetUrl)
    })

    test("sets a flash cookie before redirecting", () => {
      const targetUrl = "https://phoenixframework.com"
      const flashMessage = "mango"
      Browser.redirect(targetUrl, flashMessage)

      expect(document.cookie).toContain("__phoenix_flash__")
      expect(document.cookie).toContain(flashMessage)
      expect(mockHrefSetter).toHaveBeenCalledWith(targetUrl)
      expect(window.location.href).toEqual(targetUrl)
    })
  })
})

// Adapted from https://stackoverflow.com/questions/179355/clearing-all-cookies-with-javascript/179514#179514
function clearCookies(){
  const cookies = document.cookie.split(";")

  for(let i = 0; i < cookies.length; i++){
    const cookie = cookies[i]
    const eqPos = cookie.indexOf("=")
    const name = eqPos > -1 ? cookie.substr(0, eqPos) : cookie
    document.cookie = name + "=;expires=Thu, 01 Jan 1970 00:00:00 GMT"
  }
}
