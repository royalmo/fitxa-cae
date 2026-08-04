import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["limit", "value"]

  connect() {
    this.update()
  }

  update() {
    if (this.hasValueTarget) this.valueTarget.textContent = this.limitTarget.value
  }
}
