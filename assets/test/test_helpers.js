import View from "phoenix_live_view/view"

export let appendTitle = opts => {
  let title = document.createElement("title")
  let {prefix, suffix} = opts
  if(prefix){ title.setAttribute("data-prefix", prefix) }
  if(suffix){ title.setAttribute("data-suffix", suffix) }
  document.head.appendChild(title)
}

export let rootContainer = (content) => {
  let div = tag("div", {id: 123}, content)
  document.body.appendChild(div)
  return div
}

export let tag = (tagName, attrs, innerHTML) => {
  let el = document.createElement(tagName)
  el.innerHTML = innerHTML
  for(let key in attrs){ el.setAttribute(key, attrs[key]) }
  return el
}

export let simulateJoinedView = (el, liveSocket) => {
  let view = new View(el, liveSocket)
  stubChannel(view)
  liveSocket.roots[view.id] = view
  view.isConnected = () => true
  view.onJoin({rendered: {s: [el.innerHTML]}})
  return view
}

export let stubChannel = view => {
  let fakePush = {
    receives: [],
    receive(kind, cb){
      this.receives.push([kind, cb])
      return this
    }
  }
  view.channel.push = () => fakePush
}

export function liveViewDOM(content){
  const div = document.createElement("div")
  div.setAttribute("data-phx-view", "User.Form")
  div.setAttribute("data-phx-session", "abc123")
  div.setAttribute("id", "container")
  div.setAttribute("class", "user-implemented-class")
  div.innerHTML = content || `
    <form>
      <label for="plus">Plus</label>
      <input id="plus" value="1" name="increment" />
      <textarea id="note" name="note">2</textarea>
      <input type="checkbox" phx-click="toggle_me" />
      <button phx-click="inc_temperature">Inc Temperature</button>
    </form>
  `
  document.body.innerHTML = ""
  document.body.appendChild(div)
  return div
}


