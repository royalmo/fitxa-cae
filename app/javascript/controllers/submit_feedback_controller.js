import { Controller } from "@hotwired/stimulus"

const SUBMIT_SELECTOR = "button[type='submit'], input[type='submit']"

export default class extends Controller {
  connect() {
    this.submitterStates = new WeakMap()
    this.submitters = new Set()
    this.start = this.start.bind(this)
    this.end = this.end.bind(this)
    this.nativeStart = this.nativeStart.bind(this)
    this.restoreSubmitters = this.restoreSubmitters.bind(this)

    document.addEventListener("submit", this.nativeStart)
    document.addEventListener("turbo:submit-start", this.start)
    document.addEventListener("turbo:submit-end", this.end)
    document.addEventListener("turbo:before-cache", this.restoreSubmitters)
  }

  disconnect() {
    document.removeEventListener("submit", this.nativeStart)
    document.removeEventListener("turbo:submit-start", this.start)
    document.removeEventListener("turbo:submit-end", this.end)
    document.removeEventListener("turbo:before-cache", this.restoreSubmitters)
  }

  start(event) {
    this.dismissFlashes()
    this.disableSubmitter(this.submitterFor(event))
  }

  nativeStart(event) {
    if (event.defaultPrevented || !this.turboDisabled(event.target)) return

    this.dismissFlashes()
    this.disableSubmitter(event.submitter || this.submitterForForm(event.target), { disable: true })
  }

  end(event) {
    this.restoreSubmitter(this.submitterFor(event))
  }

  submitterFor(event) {
    return event.detail.formSubmission?.submitter || event.target.querySelector(SUBMIT_SELECTOR)
  }

  submitterForForm(form) {
    return Array.from(document.querySelectorAll(SUBMIT_SELECTOR)).find((submitter) => submitter.form === form)
  }

  turboDisabled(form) {
    return form instanceof HTMLFormElement && form.closest("[data-turbo='false']")
  }

  disableSubmitter(submitter, { disable = false } = {}) {
    if (!submitter || submitter.dataset.submitFeedbackDisabled === "true") return
    if (this.submitterStates.has(submitter)) return

    const state = {
      ariaBusy: submitter.getAttribute("aria-busy"),
      disabled: disable ? submitter.disabled : null
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
    this.submitters.add(submitter)
    if (disable) submitter.disabled = true
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

    if (state.ariaBusy === null) {
      submitter.removeAttribute("aria-busy")
    } else {
      submitter.setAttribute("aria-busy", state.ariaBusy)
    }
    submitter.disabled = state.disabled ?? false
    submitter.classList.remove("is-submitting")
    this.submitterStates.delete(submitter)
    this.submitters.delete(submitter)
  }

  restoreSubmitters() {
    Array.from(this.submitters).forEach((submitter) => this.restoreSubmitter(submitter))
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
