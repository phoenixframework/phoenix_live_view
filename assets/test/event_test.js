import {Socket} from "phoenix"
import LiveSocket, {View, DOM} from "../js/phoenix_live_view"

let containerId = 0

let simulateView = (liveSocket, events, innerHTML) => {
  let el = document.createElement("div")
  el.setAttribute("data-phx-view", "Events")
  el.setAttribute("data-phx-session", "abc123")
  el.setAttribute("id", `container${containerId++}`)
  el.innerHTML = innerHTML
  document.body.appendChild(el)

  let view = new View(el, liveSocket)
  view.onJoin({rendered: {e: events, s: [innerHTML]}})
  return view
}

let processedEvents

describe("events", function() {
  beforeEach(() => {
    processedEvents = []
  })

  test("events on join", async () => {
    let liveSocket = new LiveSocket("/live", Socket, {hooks: {
      Map: {
        mounted(){
          this.handleEvent("points", data => processedEvents.push({event: "points", data: data}))
        }
      }
    }})
    let view = simulateView(liveSocket, [["points", {values: [1, 2, 3]}]], `
      <div id="map" phx-hook="Map">
      </div>
    `)

    expect(processedEvents).toEqual([{event: "points", data: {values: [1, 2, 3]}}])
  })

  test("events on update", async () => {
    let liveSocket = new LiveSocket("/live", Socket, {hooks: {
      Game: {
        mounted(){
          this.handleEvent("scores", data => processedEvents.push({event: "scores", data: data}))
        }
      }
    }})
    let view = simulateView(liveSocket, [], `
      <div id="game" phx-hook="Game">
      </div>
    `)

    expect(processedEvents).toEqual([])

    view.update({}, [["scores", {values: [1, 2, 3]}]])
    expect(processedEvents).toEqual([{event: "scores", data: {values: [1, 2, 3]}}])
  })

  test("events handlers are cleaned up on destroy", async () => {
    let destroyed = []
    let liveSocket = new LiveSocket("/live", Socket, {hooks: {
      Handler: {
        mounted(){
          this.handleEvent("my-event", data => processedEvents.push({id: this.el.id, event: "my-event", data: data}))
        },
        destroyed(){ destroyed.push(this.el.id) }
      }
    }})
    let view = simulateView(liveSocket, [], `
      <div id="handler1" phx-hook="Handler"></div>
      <div id="handler2" phx-hook="Handler"></div>
    `)

    expect(processedEvents).toEqual([])

    view.update({}, [["my-event", {val: 1}]])
    expect(processedEvents).toEqual([
      {id: "handler1", event: "my-event", data: {val: 1}},
      {id: "handler2", event: "my-event", data: {val: 1}}
    ])

    let newHTML = `<div id="handler1" phx-hook="Handler"></div>`
    view.update({s: [newHTML]}, [["my-event", {val: 2}]])

    expect(destroyed).toEqual(["handler2"])

    expect(processedEvents).toEqual([
      {id: "handler1", event: "my-event", data: {val: 1}},
      {id: "handler2", event: "my-event", data: {val: 1}},
      {id: "handler1", event: "my-event", data: {val: 2}}
    ])
  })
})