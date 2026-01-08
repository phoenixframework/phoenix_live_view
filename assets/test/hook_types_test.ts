/**
 * Type tests for Hook and HooksOptions.
 *
 * These tests verify:
 * 1. Typed hooks with custom state and element types can be assigned to HooksOptions
 *    (requires Hook<any, any> in HooksOptions definition)
 * 2. Hook<SpecificType> is assignable to Hook<object> due to covariant `out T` annotation
 *    (see https://github.com/phoenixframework/phoenix_live_view/issues/3955)
 *
 * This file is checked by `npm run typecheck:tests`.
 */

import type { Hook, HooksOptions } from "phoenix_live_view/view_hook";

// Hook with custom state
interface CounterState {
  count: number;
  increment(): void;
}

const CounterHook: Hook<CounterState> = {
  count: 0,
  increment() {
    this.count++;
  },
  mounted() {
    this.el.addEventListener("click", () => this.increment());
  },
};

// Hook targeting a specific element type
interface CanvasState {
  ctx: CanvasRenderingContext2D | null;
}

const CanvasHook: Hook<CanvasState, HTMLCanvasElement> = {
  ctx: null,
  mounted() {
    // this.el should be typed as HTMLCanvasElement
    this.ctx = this.el.getContext("2d");
  },
};

// Hook with both custom state and specific element type
interface VideoState {
  isPlaying: boolean;
  toggle(): void;
}

const VideoHook: Hook<VideoState, HTMLVideoElement> = {
  isPlaying: false,
  toggle() {
    if (this.isPlaying) {
      this.el.pause();
    } else {
      this.el.play();
    }
    this.isPlaying = !this.isPlaying;
  },
  mounted() {
    this.el.addEventListener("click", () => this.toggle());
  },
};

// All typed hooks should be assignable to HooksOptions
const hooks: HooksOptions = {
  Counter: CounterHook,
  Canvas: CanvasHook,
  Video: VideoHook,
};

// =============================================================================
// Test for issue #3955: Hook<T> with required properties in HooksOptions
// https://github.com/phoenixframework/phoenix_live_view/issues/3955
//
// The fix using Hook<any, any> in HooksOptions allows typed hooks to be
// assigned regardless of their specific type parameters.
// =============================================================================

interface LinksInTab {
  tabName: string; // required property
  links: string[];
}

const LinksInTabHook: Hook<LinksInTab> = {
  tabName: "",
  links: [],
  mounted() {
    this.tabName = this.el.dataset.tab || "default";
    console.log(`Tab ${this.tabName} mounted with ${this.links.length} links`);
  },
};

// This tests that Hook<LinksInTab> (with required properties) can be
// assigned to HooksOptions. This was the original issue #3955.
const hooksWithRequiredProps: HooksOptions = {
  LinksInTab: LinksInTabHook,
};

export { hooks, hooksWithRequiredProps };

// https://github.com/phoenixframework/phoenix_live_view/issues/3913
// Checks that custom methods and properties are allowed for a basic Hook.
const InfiniteScroll: Hook = {
  page() {
    return this.el.dataset.page;
  },
  mounted() {
    this.pending = this.page();
    window.addEventListener("scroll", () => {
      if (this.pending == this.page() && 80 > 90) {
        this.pending = this.page() + 1;
        this.pushEvent("load-more", {});
      }
    });
  },
  updated() {
    this.pending = this.page();
  },
};

export { InfiniteScroll };

// This file is primarily for compile-time type checking via `npm run typecheck:tests`.
// The dummy test below satisfies Jest's requirement for at least one test.
test("hook types compile correctly", () => {
  expect(hooks).toBeDefined();
  expect(hooksWithRequiredProps).toBeDefined();
});
