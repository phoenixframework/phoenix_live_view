import { Browser } from '../js/phoenix_live_view'

describe('Browser', () => {
  beforeEach(() => {
    clearCookies()
  })

  describe('setCookie', () => {
    it('sets a cookie', () => {
      Browser.setCookie('apple', 1234)
      Browser.setCookie('orange', '5678')
      expect(document.cookie).toContain('apple')
      expect(document.cookie).toContain('1234')
      expect(document.cookie).toContain('orange')
      expect(document.cookie).toContain('5678')
    })
  })

  describe('getCookie', () => {
    it('returns the value for a cookie', () => {
      document.cookie = 'apple=1234'
      document.cookie = 'orange=5678'
      expect(Browser.getCookie('apple')).toEqual('1234')
    })
    it('returns an empty string for a non-existant cookie', () => {
      document.cookie = 'apple=1234'
      document.cookie = 'orange=5678'
      expect(Browser.getCookie('plum')).toEqual('')
    })
  })

  describe('redirect', () => {
    const originalWindowLocation = global.window.location

    beforeEach(() => {
      delete global.window.location
      global.window.location = 'https://example.com'
    })

    afterAll(() => {
      global.window.location = originalWindowLocation
    })

    it('redirects to a new URL', () => {
      Browser.redirect('https://phoenixframework.com')
      expect(window.location).toEqual('https://phoenixframework.com')
    })

    it('sets a flash cookie before redirecting', () => {
      Browser.redirect('https://phoenixframework.com', 'mango')
      expect(document.cookie).toContain('__phoenix_flash__')
      expect(document.cookie).toContain('mango')
    })
  })
})

// Adapted from https://stackoverflow.com/questions/179355/clearing-all-cookies-with-javascript/179514#179514
function clearCookies() {
  var cookies = document.cookie.split(';')

  for (var i = 0; i < cookies.length; i++) {
    var cookie = cookies[i]
    var eqPos = cookie.indexOf('=')
    var name = eqPos > -1 ? cookie.substr(0, eqPos) : cookie
    document.cookie = name + '=;expires=Thu, 01 Jan 1970 00:00:00 GMT'
  }
}
