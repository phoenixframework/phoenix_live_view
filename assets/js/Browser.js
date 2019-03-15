export let Browser = {
  setCookie(name, value) {
    document.cookie = `${name}=${value}`
  },
  getCookie(name) {
    return document.cookie.replace(
      new RegExp(`(?:(?:^|.*;\s*)${name}\s*\=\s*([^;]*).*$)|^.*$`),
      '$1'
    )
  },
  redirect(toURL, flash) {
    if (flash) {
      Browser.setCookie('__phoenix_flash__', flash + '; max-age=60000; path=/')
    }
    window.location = toURL
  },
}
