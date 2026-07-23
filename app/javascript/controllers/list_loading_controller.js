import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["results", "loading"]

  connect() {
    this.hideLoading = this.hideLoading.bind(this)
    document.addEventListener("turbo:before-cache", this.hideLoading)
    this.hideLoading()
  }

  disconnect() {
    document.removeEventListener("turbo:before-cache", this.hideLoading)
  }

  filter(event) {
    this.showLoading()
    event.currentTarget.form?.requestSubmit()
  }

  navigate(event) {
    if (this.modifiedClick(event)) return

    this.showLoading()
  }

  showLoading() {
    this.resultsTargets.forEach((target) => {
      target.hidden = true
    })
    if (this.hasLoadingTarget) this.loadingTarget.hidden = false
    this.element.setAttribute("aria-busy", "true")
  }

  hideLoading() {
    this.resultsTargets.forEach((target) => {
      target.hidden = false
    })
    if (this.hasLoadingTarget) this.loadingTarget.hidden = true
    this.element.removeAttribute("aria-busy")
  }

  modifiedClick(event) {
    return event.metaKey || event.ctrlKey || event.shiftKey || event.altKey || event.button !== 0
  }
}
