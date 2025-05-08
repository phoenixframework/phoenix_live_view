declare global {
  function setStartSystemTime(): void
  function advanceTimersToNextFrame(): void
  let LV_VSN: string
}

export {}
