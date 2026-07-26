import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    show: Boolean
  }

  connect() {
    this.dispose = this.dispose.bind(this)

    if (window.bootstrap?.Modal) {
      this.modal = window.bootstrap.Modal.getOrCreateInstance(this.element)
      if (this.showValue) this.modal.show()
    }

    document.addEventListener("turbo:before-cache", this.dispose)
  }

  disconnect() {
    document.removeEventListener("turbo:before-cache", this.dispose)
    this.dispose()
  }

  dispose() {
    this.modal?.dispose()
    this.modal = null
  }
}
