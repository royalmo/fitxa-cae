import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["row"]

  connect() {
    if (!this.hasRowTarget) return

    requestAnimationFrame(() => {
      this.rowTarget.scrollIntoView({
        block: "center",
        behavior: this.prefersReducedMotion ? "auto" : "smooth",
      })
      this.rowTarget.focus({ preventScroll: true })
    })
  }

  get prefersReducedMotion() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches
  }
}
