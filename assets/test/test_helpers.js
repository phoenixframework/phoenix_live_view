import {View} from "../js/phoenix_live_view"

export let appendTitle = opts => {
  let title = document.createElement("title")
  let {prefix, suffix} = opts
  if(prefix){ title.setAttribute("data-prefix", prefix) }
  if(suffix){ title.setAttribute("data-suffix", suffix) }
  document.head.appendChild(title)
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
  view.onJoin({rendered: {s: []}})
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