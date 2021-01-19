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
  view.isConnected = () => true
  return view
}

let stubNextChannelReply = (view, replyPayload) => {
  let oldPush = view.channel.push
  view.channel.push = () => {
    return {
      receives: [],
      receive(kind, cb){
        if(kind === "ok"){
          cb({diff: {r: replyPayload}})
          view.channel.push = oldPush
        }
        return this
      }
    }
  }
}


describe("events", () => {
  let processedEvents
  beforeEach(() => {
    document.body.innerHTML = ""
    processedEvents = []
  })

  test("events on join", () => {
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

  test("events on update", () => {
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

  test("events handlers are cleaned up on destroy", () => {
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

  test("removeHandleEvent", () => {
    let liveSocket = new LiveSocket("/live", Socket, {hooks: {
      Remove: {
        mounted(){
          let ref = this.handleEvent("remove", data => {
            this.removeHandleEvent(ref)
            processedEvents.push({event: "remove", data: data})
          })
        }
      }
    }})
    let view = simulateView(liveSocket, [], `
      <div id="remove" phx-hook="Remove"></div>
    `)

    expect(processedEvents).toEqual([])

    view.update({}, [["remove", {val: 1}]])
    expect(processedEvents).toEqual([{event: "remove", data: {val: 1}}])

    view.update({}, [["remove", {val: 1}]])
    expect(processedEvents).toEqual([{event: "remove", data: {val: 1}}])
  })
})

describe("pushEvent replies", () => {
  let processedReplies
  beforeEach(() => {
    processedReplies = []
  })

  test("reply", () => {
    let view
    let pushedRef = null
    let liveSocket = new LiveSocket("/live", Socket, {hooks: {
      Gateway: {
        mounted(){
          stubNextChannelReply(view, {transactionID: "1001"})
          pushedRef = this.pushEvent("charge", {amount: 123}, (resp, ref) => {
            processedReplies.push({resp, ref})
          })
        }
      }
    }})
    view = simulateView(liveSocket, [], ``)
    view.update({s: [`
      <div id="gateway" phx-hook="Gateway">
      </div>
    `]}, [])

    expect(pushedRef).toEqual(0)
    expect(processedReplies).toEqual([{resp: {transactionID: "1001"}, ref: 0}])
  })

  test("pushEvent without connection noops", () => {
    let view
    let pushedRef = "before"
    let liveSocket = new LiveSocket("/live", Socket, {hooks: {
      Gateway: {
        mounted(){
          stubNextChannelReply(view, {transactionID: "1001"})
          pushedRef = this.pushEvent("charge", {amount: 123})
        }
      }
    }})
    view = simulateView(liveSocket, [], ``)
    view.isConnected = () => false
    view.update({s: [`
      <div id="gateway" phx-hook="Gateway">
      </div>
    `]}, [])

    expect(pushedRef).toEqual(false)
  })
})
