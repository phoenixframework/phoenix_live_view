// TODO: use liveSocket.execJS or provide a nicer API via liveSocket
//       to set/remove classes persistently
import JS from "./js"

const PHX_FEEDBACK_FOR = "phx-feedback-for"
const PHX_FEEDBACK_GROUP = "phx-feedback-group"
const PHX_NO_FEEDBACK_CLASS = "phx-no-feedback"

const FeedbackFor = {
  showError(inputEl){
    if(inputEl.name){
      let query = this.feedbackSelector(inputEl)
      document.querySelectorAll(query).forEach((el) => {
        JS.addOrRemoveClasses(el, [], [PHX_NO_FEEDBACK_CLASS])
      })
    }
  },

  isFeedbackContainer(el){
    return el.hasAttribute && el.hasAttribute(PHX_FEEDBACK_FOR)
  },

  resetForm(form){
    Array.from(form.elements).forEach(input => {
      let query = this.feedbackSelector(input)
      document.querySelectorAll(query).forEach((feedbackEl) => {
        JS.addOrRemoveClasses(feedbackEl, [PHX_NO_FEEDBACK_CLASS], [])
      })
    })
  },

  maybeHideFeedback(liveSocket, feedbackContainers){
    // because we can have multiple containers with the same phxFeedbackFor value
    // we perform the check only once and store the result;
    // we often have multiple containers, because we push both fromEl and toEl in onBeforeElUpdated
    // when a container is updated
    const feedbackResults = {}
    feedbackContainers.forEach(el => {
      // skip elements that are not in the DOM
      if(!document.contains(el)) return
      const feedback = el.getAttribute(PHX_FEEDBACK_FOR)
      if(!feedback){
        // the container previously had phx-feedback-for, but now it doesn't
        // remove the class from the container (if it exists)
        JS.addOrRemoveClasses(el, [], [PHX_NO_FEEDBACK_CLASS])
        return
      }
      if(feedbackResults[feedback] === true){
        this.hideFeedback(el)
        return
      }
      feedbackResults[feedback] = this.shouldHideFeedback(liveSocket, feedback, PHX_FEEDBACK_GROUP)
      if(feedbackResults[feedback] === true){
        this.hideFeedback(el)
      }
    })
  },

  hideFeedback(el){
    JS.addOrRemoveClasses(el, [PHX_NO_FEEDBACK_CLASS], [])
  },

  shouldHideFeedback(liveSocket, nameOrGroup, phxFeedbackGroup){
    const query = `[name="${nameOrGroup}"],
                   [name="${nameOrGroup}[]"],
                   [${phxFeedbackGroup}="${nameOrGroup}"]`
    let interacted = false
    document.querySelectorAll(query).forEach((input) => {
      if(liveSocket.inputInteracted(input)){
        interacted = true
      }
    })
    return !interacted
  },

  feedbackSelector(input){
    let query = `[${PHX_FEEDBACK_FOR}="${input.name}"],
                 [${PHX_FEEDBACK_FOR}="${input.name.replace(/\[\]$/, "")}"]`
    if(input.getAttribute(PHX_FEEDBACK_GROUP)){
      query += `,[${PHX_FEEDBACK_FOR}="${input.getAttribute(PHX_FEEDBACK_GROUP)}"]`
    }
    return query
  },
}

export const init = (liveSocket) => {
  let feedbackContainers = []
  let inputPending = false
  let submitPending = false

  // TODO: provide a way to hook into onBeforeElUpdated / onNodeAdded without needing
  //       to overwrite the existing handlers
  const existingOnBeforeElUpdated = liveSocket.domCallbacks.onBeforeElUpdated
  const existingOnNodeAdded = liveSocket.domCallbacks.onNodeAdded

  liveSocket.domCallbacks.onBeforeElUpdated = (fromEl, toEl) => {
    // mark both from and to els as feedback containers, as we don't know yet which one will be used
    // and we also need to remove the phx-no-feedback class when the phx-feedback-for attribute is removed
    if(FeedbackFor.isFeedbackContainer(fromEl) || FeedbackFor.isFeedbackContainer(toEl)){
      feedbackContainers.push(fromEl)
      feedbackContainers.push(toEl)
    }
    existingOnBeforeElUpdated(fromEl, toEl)
  }

  liveSocket.domCallbacks.onNodeAdded = (el) => {
    if(FeedbackFor.isFeedbackContainer(el)) feedbackContainers.push(el)
    existingOnNodeAdded(el)
  }
  
  const onPatchStart = () => feedbackContainers = []
  const onPatchEnd = () => {
    if(inputPending){
      FeedbackFor.showError(inputPending)
      inputPending = null
    }
    if(submitPending){
      Array.from(submitPending.elements).forEach(input => FeedbackFor.showError(input))
      submitPending = null
    }
    FeedbackFor.maybeHideFeedback(liveSocket, feedbackContainers)
  }

  // we only want to update the feedback after the patch has been applied
  const onInput = (e) => inputPending = e.target
  const onSubmit = (e) => submitPending = e.target

  const onReset = (e) => FeedbackFor.resetForm(e.target)

  window.addEventListener("change", onInput)
  window.addEventListener("input", onInput)
  window.addEventListener("submit", onSubmit)
  window.addEventListener("reset", onReset)

  document.addEventListener("phx:update-start", onPatchStart)
  document.addEventListener("phx:update-end", onPatchEnd)

  return () => {
    document.removeEventListener("phx:update-start", onPatchStart)
    document.removeEventListener("phx:update-end", onPatchEnd)
    window.removeEventListener("change", onInput)
    window.removeEventListener("input", onInput)
    window.removeEventListener("submit", onSubmit)
    window.removeEventListener("reset", onReset)
  }
}
