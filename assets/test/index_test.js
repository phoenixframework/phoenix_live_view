import {LiveSocket} from "phoenix_live_view"
import * as LiveSocket2 from "phoenix_live_view/live_socket"

describe("Named Imports", () => {
  test("LiveSocket is equal to the actual LiveSocket", () => {
    expect(LiveSocket).toBe(LiveSocket2.default)
  })
})
