import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static values = {
    interval: { type: Number, default: 30000 },
    signature: String,
    url: String
  }

  connect() {
    if (!this.hasUrlValue || !this.hasSignatureValue) return

    this.pollingInterval = window.setInterval(() => this.check(), this.intervalValue)
  }

  disconnect() {
    if (this.pollingInterval) window.clearInterval(this.pollingInterval)
  }

  async check() {
    if (this.checking) return

    this.checking = true

    try {
      const response = await fetch(this.urlValue, {
        cache: "no-store",
        credentials: "same-origin",
        headers: { Accept: "application/json" }
      })

      if (response.redirected) {
        this.reload()
        return
      }

      if (!response.ok) return

      const contentType = response.headers.get("content-type") || ""
      if (!contentType.includes("application/json")) {
        this.reload()
        return
      }

      const state = await response.json()
      if (state.signature && state.signature !== this.signatureValue) this.reload()
    } catch (_error) {
      // Ignore transient offline/network errors. The next interval will retry.
    } finally {
      this.checking = false
    }
  }

  reload() {
    Turbo.visit(window.location.href, { action: "replace" })
  }
}
