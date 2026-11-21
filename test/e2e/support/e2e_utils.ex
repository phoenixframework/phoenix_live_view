defmodule Phoenix.LiveViewTest.E2E.Utils do
  @moduledoc """
  Helpers of the e2e tests: `sync_lv/1`, `eval_lv/3`, `eval_plug/2`, `attribute_mutations/2`, plus
  arrays filled by listeners, promises resolved from outside, and asymmetric matchers.
  """

  import Playwright.Test.Assertions

  alias Playwright.{APIRequestContext, APIResponse, Expect, Locator, Page, Promise}

  def random_string(size \\ 21) do
    size |> :crypto.strong_rand_bytes() |> Base.encode64() |> binary_part(0, size)
  end

  # a helper function to wait until the LV has no pending events
  def sync_lv(page) do
    promises = [
      Promise.async(fn ->
        page |> Page.locator(".phx-connected") |> Locator.first() |> Expect.to_be_visible!()
      end),
      Promise.async(fn ->
        page |> Page.locator(".phx-change-loading") |> Expect.to_have_count!(0)
      end),
      Promise.async(fn ->
        page |> Page.locator(".phx-click-loading") |> Expect.to_have_count!(0)
      end),
      Promise.async(fn ->
        page |> Page.locator(".phx-submit-loading") |> Expect.to_have_count!(0)
      end)
    ]

    promises |> Promise.all() |> Promise.await!()
  end

  # this function executes the given code inside the liveview that is responsible
  # for the given selector; it uses private phoenix live view js functions, so it could
  # break in the future
  # we handle the evaluation in a LV hook
  # (`selector` defaults in the body, so `nil` is the default too)
  def eval_lv(page, code, selector \\ nil) do
    selector = selector || "[data-phx-main]"

    Page.evaluate!(
      page,
      """
      ([code, selector]) => {
        return new Promise((resolve) => {
          window.liveSocket.main.withinTargets(
            selector,
            (targetView, targetCtx) => {
              targetView.pushEvent(
                "event",
                document.body,
                targetCtx,
                "sandbox:eval",
                { value: code },
                {},
                ({ result }) => resolve(result),
              );
            },
          );
        });
      }
      """,
      [code, selector]
    )
  end

  # executes the given code inside a new process
  # (in context of a plug request)
  def eval_plug(request, code) do
    request |> APIRequestContext.post!("/eval", data: %{code: code}) |> APIResponse.json!()
  end

  def attribute_mutations(page, selector) do
    # this is a bit of a hack, basically we create a MutationObserver on the page
    # that will record any changes to a selector until the promise is awaited
    #
    # we use a random id to store the resolve function in the window object
    id = random_string(24)
    # this promise resolves to the mutation list
    promise =
      Promise.async(fn ->
        page
        |> Page.locator(selector)
        |> Locator.evaluate!(
          """
          (target, id) => {
            return new Promise((resolve) => {
              const mutations = [];
              let observer;
              window[id] = () => {
                if (observer) observer.disconnect();
                resolve(mutations);
                delete window[id];
              };
              // https://developer.mozilla.org/en-US/docs/Web/API/MutationObserver
              observer = new MutationObserver((mutationsList, _observer) => {
                mutationsList.forEach((mutation) => {
                  if (mutation.type === "attributes") {
                    mutations.push({
                      attr: mutation.attributeName,
                      oldValue: mutation.oldValue,
                      newValue: mutation.target.getAttribute(mutation.attributeName),
                    });
                  }
                });
              }).observe(target, { attributes: true, attributeOldValue: true });
            });
          }
          """,
          id
        )
      end)

    fn ->
      # we want to stop observing!
      page |> Page.locator(selector) |> Locator.evaluate!("(_target, id) => window[id]()", id)
      # return the result of the initial promise
      Promise.await!(promise)
    end
  end

  ## Arrays filled by listeners

  @doc """
  A JS array that listeners fill (`const logs = []; page.on("console", (e) => logs.push(...))`).

  An unlinked process: listeners still run in `on_exit` callbacks, after the test process has
  exited (see "Route handlers and listeners" in playwright_ex's ExUnit guide).
  """
  def array do
    {:ok, array} = Agent.start(fn -> [] end)
    array
  end

  @doc "`array.push(value)`."
  def push(array, value), do: Agent.update(array, &(&1 ++ [value]))

  @doc "The array's elements."
  def values(array), do: Agent.get(array, & &1)

  @doc "`array = []`, as the specs reset their arrays."
  def clear(array), do: Agent.update(array, fn _ -> [] end)

  ## Promises resolved from outside

  @doc """
  `let resolve; const promise = new Promise((r) => (resolve = r))`: `resolve/1` it, and
  `await_deferred/1` blocks until it is resolved. `reset/1` is the reassignment
  `promise = new Promise(...)` (a route handler holds the deferred, not the variable).

  A route handler must not block (it would stall the connection), so where JS `await`s in a
  handler, a process of its own awaits and continues.
  """
  def deferred do
    {:ok, deferred} = Agent.start(fn -> {:pending, []} end)
    deferred
  end

  def resolve(deferred) do
    Agent.update(deferred, fn
      {:pending, waiters} ->
        Enum.each(waiters, &send(&1, {:resolved, deferred}))
        :resolved

      :resolved ->
        :resolved
    end)
  end

  def reset(deferred), do: Agent.update(deferred, fn _ -> {:pending, []} end)

  def await_deferred(deferred) do
    waiter = self()

    wait =
      Agent.get_and_update(deferred, fn
        :resolved -> {:ok, :resolved}
        {:pending, waiters} -> {:wait, {:pending, [waiter | waiters]}}
      end)

    if wait == :wait do
      receive do
        {:resolved, ^deferred} -> :ok
      end
    end

    :ok
  end

  ## Asymmetric matchers

  @doc """
  `expect(actual).toEqual(expected)` where `expected` may hold asymmetric matchers:
  `array_containing/1`, `object_containing/1`, `string_containing/1`, `string_matching/1`.
  """
  def assert_equal(actual, expected) do
    assert matches?(actual, expected),
           "expected #{inspect(actual)} to equal #{inspect(expected)}"
  end

  @doc "`expect(actual).not.toEqual(expected)`, see `assert_equal/2`."
  def refute_equal(actual, expected) do
    refute matches?(actual, expected),
           "expected #{inspect(actual)} not to equal #{inspect(expected)}"
  end

  @doc "`expect.arrayContaining(list)`."
  def array_containing(list) when is_list(list), do: {:array_containing, list}

  @doc "`expect.objectContaining(map)`."
  def object_containing(map) when is_map(map), do: {:object_containing, map}

  @doc "`expect.stringContaining(string)`."
  def string_containing(string) when is_binary(string), do: {:string_containing, string}

  @doc "`expect.stringMatching(regex)` (a string is compiled as a regex, as in JS)."
  def string_matching(%Regex{} = regex), do: {:string_matching, regex}

  def string_matching(string) when is_binary(string),
    do: {:string_matching, Regex.compile!(string)}

  defp matches?(actual, {:array_containing, expected}) do
    # every expected element matches some element (arrayContaining doesn't consume them)
    is_list(actual) and Enum.all?(expected, fn e -> Enum.any?(actual, &matches?(&1, e)) end)
  end

  defp matches?(actual, {:object_containing, expected}) do
    is_map(actual) and
      Enum.all?(expected, fn {k, v} -> Map.has_key?(actual, k) and matches?(actual[k], v) end)
  end

  defp matches?(actual, {:string_containing, expected}),
    do: is_binary(actual) and String.contains?(actual, expected)

  defp matches?(actual, {:string_matching, regex}),
    do: is_binary(actual) and actual =~ regex

  defp matches?(actual, expected) when is_list(expected) do
    is_list(actual) and length(actual) == length(expected) and
      Enum.all?(Enum.zip(actual, expected), fn {a, e} -> matches?(a, e) end)
  end

  defp matches?(actual, expected) when is_map(expected) and not is_struct(expected) do
    is_map(actual) and map_size(actual) == map_size(expected) and
      Enum.all?(expected, fn {k, v} -> Map.has_key?(actual, k) and matches?(actual[k], v) end)
  end

  defp matches?(actual, expected), do: actual == expected
end
