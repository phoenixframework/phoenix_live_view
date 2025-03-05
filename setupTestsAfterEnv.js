// https://github.com/jestjs/jest/pull/14598#issuecomment-1748047560
// TODO: remove this once jest.advanceTimersToNextFrame() is available
// ensure you are using "modern" fake timers
// 1. before doing anything, grab the start time `setStartSystemTime()`
// 2. step through frames by using `advanceTimersToNextFrame()`

let startTime = null

/** Record the initial (mocked) system start time 
 * 
 * This is no longer needed once `jest.advanceTimersToNextFrame()` is available
 * https://github.com/jestjs/jest/pull/14598
*/
global.setStartSystemTime = () => {
  startTime = Date.now()
}

/** Step forward a single animation frame
 * 
 * This is no longer needed once `jest.advanceTimersToNextFrame()` is available
 * https://github.com/jestjs/jest/pull/14598
 */
global.advanceTimersToNextFrame = () => {
  if(startTime == null){
    throw new Error("Must call `setStartSystemTime` before using `advanceTimersToNextFrame()`")
  }

  // Stealing logic from sinon fake timers
  // https://github.com/sinonjs/fake-timers/blob/fc312b9ce96a4ea2c7e60bb0cccd2c604b75cdbd/src/fake-timers-src.js#L1102-L1105
  const timePassedInFrame = (Date.now() - startTime) % 16
  const timeToNextFrame = 16 - timePassedInFrame
  jest.advanceTimersByTime(timeToNextFrame)
}
