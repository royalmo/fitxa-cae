import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source"]

  copyToModal(event) {
    if (!this.hasSourceTarget) return

    const modal = this.modalFor(event.currentTarget)
    const comments = modal?.querySelector("textarea[name='validator_comments']")

    if (comments) comments.value = this.sourceTarget.value
  }

  modalFor(trigger) {
    const selector = trigger?.dataset.bsTarget
    if (!selector) return null

    try {
      return document.querySelector(selector)
    } catch {
      return null
    }
  }
}
