import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["hours", "minutes", "seconds"]
  static values = {
    baseSeconds: Number,
    startedAt: String
  }

  connect() {
    this.update()
    if (this.hasStartedAtValue && this.startedAtValue) {
      this.interval = window.setInterval(() => this.update(), 1000)
    }
  }

  disconnect() {
    if (this.interval) window.clearInterval(this.interval)
  }

  update() {
    const seconds = Math.floor(this.currentSeconds())
    const hours = Math.floor(seconds / 3600)
    const minutes = Math.floor((seconds % 3600) / 60)
    const remainingSeconds = seconds % 60

    this.hoursTarget.textContent = hours.toString()
    this.minutesTarget.textContent = minutes.toString().padStart(2, "0")
    this.secondsTarget.textContent = remainingSeconds.toString().padStart(2, "0")
  }

  currentSeconds() {
    let seconds = Math.max(0, this.baseSecondsValue || 0)
    const startedAt = Date.parse(this.startedAtValue)

    if (!Number.isNaN(startedAt)) {
      seconds += Math.max(0, Math.floor((Date.now() - startedAt) / 1000))
    }

    return seconds
  }
}
