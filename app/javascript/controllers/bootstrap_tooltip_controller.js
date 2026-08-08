import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    if (!window.bootstrap?.Tooltip) return

    this.dispose = this.dispose.bind(this)
    this.tooltip = window.bootstrap.Tooltip.getOrCreateInstance(this.element, {
      container: "body",
      trigger: "hover focus"
    })
    document.addEventListener("turbo:before-cache", this.dispose)
  }

  disconnect() {
    document.removeEventListener("turbo:before-cache", this.dispose)
    this.dispose()
  }

  dispose() {
    this.tooltip?.dispose()
    this.tooltip = null
  }
}
