import { Controller } from "@hotwired/stimulus"

const SUBMIT_SELECTOR = "button[type='submit'], input[type='submit']"

export default class extends Controller {
  connect() {
    this.submitterStates = new WeakMap()
    this.start = this.start.bind(this)
    this.end = this.end.bind(this)

    document.addEventListener("turbo:submit-start", this.start)
    document.addEventListener("turbo:submit-end", this.end)
  }

  disconnect() {
    document.removeEventListener("turbo:submit-start", this.start)
    document.removeEventListener("turbo:submit-end", this.end)
  }

  start(event) {
    this.dismissFlashes()
    this.disableSubmitter(this.submitterFor(event))
  }

  end(event) {
    if (event.detail.success) return

    this.restoreSubmitter(this.submitterFor(event))
  }

  submitterFor(event) {
    return event.detail.formSubmission?.submitter || event.target.querySelector(SUBMIT_SELECTOR)
  }

  disableSubmitter(submitter) {
    if (!submitter || submitter.dataset.submitFeedbackDisabled === "true") return
    if (this.submitterStates.has(submitter)) return

    const state = {
      disabled: submitter.disabled,
      ariaBusy: submitter.getAttribute("aria-busy")
    }

    const submittingLabel = this.submittingLabel(submitter)

    if (submitter instanceof HTMLInputElement) {
      state.value = submitter.value
      if (submittingLabel) submitter.value = submittingLabel
    } else {
      state.html = submitter.innerHTML
      this.replaceButtonContent(submitter, submittingLabel)
    }

    this.submitterStates.set(submitter, state)
    submitter.disabled = true
    submitter.setAttribute("aria-busy", "true")
    submitter.classList.add("is-submitting")
  }

  restoreSubmitter(submitter) {
    const state = this.submitterStates.get(submitter)
    if (!submitter || !state) return

    if (submitter instanceof HTMLInputElement) {
      submitter.value = state.value
    } else {
      submitter.innerHTML = state.html
    }

    submitter.disabled = state.disabled
    if (state.ariaBusy === null) {
      submitter.removeAttribute("aria-busy")
    } else {
      submitter.setAttribute("aria-busy", state.ariaBusy)
    }
    submitter.classList.remove("is-submitting")
    this.submitterStates.delete(submitter)
  }

  submittingLabel(submitter) {
    return submitter.dataset.submittingLabel || submitter.form?.dataset.submittingLabel
  }

  replaceButtonContent(button, label) {
    const spinner = document.createElement("span")
    spinner.className = "submit-spinner"
    spinner.setAttribute("aria-hidden", "true")

    if (!label) {
      button.replaceChildren(spinner)
      return
    }

    const labelElement = document.createElement("span")
    labelElement.textContent = label

    button.replaceChildren(spinner, labelElement)
  }

  dismissFlashes() {
    document.querySelectorAll(".flash").forEach((flash) => flash.remove())
  }
}
