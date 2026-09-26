import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "confirmButton",
    "confirmModal",
    "runModal",
    "runProgress",
    "runProgressBar",
    "runStatusMessage"
  ]

  static values = {
    url: String,
    requestErrorLabel: String
  }

  connect() {
    this.running = false
    this.pollTimeout = null
    this.resendButtons = Array.from(this.element.querySelectorAll("[data-action='employee-welcome-resend#openConfirm']"))
    this.resendButtons.forEach((button) => {
      button.dataset.employeeWelcomeResendInitiallyDisabled = button.disabled ? "true" : "false"
    })
    this.disposeModal = this.disposeModal.bind(this)
    document.addEventListener("turbo:before-cache", this.disposeModal)
  }

  disconnect() {
    this.stopPolling()
    document.removeEventListener("turbo:before-cache", this.disposeModal)
    this.disposeModal()
  }

  openConfirm(event) {
    event.preventDefault()
    if (this.running || !this.hasConfirmModalTarget || !window.bootstrap?.Modal) return

    window.bootstrap.Modal.getOrCreateInstance(this.confirmModalTarget).show()
  }

  async send(event) {
    event.preventDefault()
    if (this.running) return

    this.hideConfirmModal()
    this.startProgress()

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        credentials: "same-origin",
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": this.csrfToken
        }
      })
      const data = await this.responseJson(response)

      if (!response.ok) throw new Error(data.error || data.message || this.requestErrorLabelValue)

      this.renderProgress(data)
      this.advance(data)
    } catch (error) {
      this.renderFailure(error.message || this.requestErrorLabelValue)
    }
  }

  startProgress() {
    this.stopPolling()
    this.running = true
    this.toggleButtons(true)
    this.setProgress(0)

    if (this.hasRunProgressBarTarget) {
      this.runProgressBarTarget.classList.add("progress-bar-striped", "progress-bar-animated")
      this.runProgressBarTarget.classList.remove("bg-danger", "bg-success")
    }
    if (this.hasRunStatusMessageTarget) {
      this.runStatusMessageTarget.textContent = ""
      this.runStatusMessageTarget.classList.add("text-body-secondary")
      this.runStatusMessageTarget.classList.remove("text-danger", "text-success")
    }

    this.showRunModal()
  }

  schedulePoll(statusUrl) {
    if (!statusUrl) {
      this.renderFailure(this.requestErrorLabelValue)
      return
    }

    this.pollTimeout = window.setTimeout(() => this.poll(statusUrl), 1500)
  }

  async poll(statusUrl) {
    try {
      const response = await fetch(statusUrl, { headers: { Accept: "application/json" } })
      const data = await this.responseJson(response)

      if (!response.ok) throw new Error(data.error || data.message || this.requestErrorLabelValue)

      this.renderProgress(data)
      this.advance(data)
    } catch (error) {
      this.renderFailure(error.message || this.requestErrorLabelValue)
    }
  }

  advance(data) {
    if (["completed", "failed"].includes(data.status)) {
      this.renderTerminal(data)
      return
    }

    this.schedulePoll(data.status_url)
  }

  renderProgress(data) {
    this.setProgress(data.progress || 0)
    if (this.hasRunStatusMessageTarget) this.runStatusMessageTarget.textContent = data.message || ""
  }

  renderTerminal(data) {
    this.stopPolling()
    this.running = false
    this.toggleButtons(false)
    this.setProgress(data.progress || 100)
    if (this.hasRunStatusMessageTarget) this.runStatusMessageTarget.textContent = data.message || this.requestErrorLabelValue
    this.renderTerminalState(data.status === "completed" ? "success" : "danger")
    this.showRunModal()
  }

  renderFailure(message) {
    this.stopPolling()
    this.running = false
    this.toggleButtons(false)
    this.setProgress(100)
    if (this.hasRunStatusMessageTarget) this.runStatusMessageTarget.textContent = message
    this.renderTerminalState("danger")
    this.showRunModal()
  }

  renderTerminalState(kind) {
    if (this.hasRunProgressBarTarget) {
      this.runProgressBarTarget.classList.remove("progress-bar-animated", "progress-bar-striped", "bg-danger", "bg-success")
      this.runProgressBarTarget.classList.add(kind === "success" ? "bg-success" : "bg-danger")
    }
    if (this.hasRunStatusMessageTarget) {
      this.runStatusMessageTarget.classList.remove("text-body-secondary", "text-danger", "text-success")
      this.runStatusMessageTarget.classList.add(kind === "success" ? "text-success" : "text-danger")
    }
  }

  setProgress(progress) {
    const normalizedProgress = Math.max(0, Math.min(Number.parseInt(progress, 10) || 0, 100))

    if (this.hasRunProgressTarget) {
      this.runProgressTarget.setAttribute("aria-valuenow", normalizedProgress.toString())
    }
    if (this.hasRunProgressBarTarget) {
      this.runProgressBarTarget.style.width = `${normalizedProgress}%`
      this.runProgressBarTarget.textContent = `${normalizedProgress}%`
    }
  }

  stopPolling() {
    if (this.pollTimeout) window.clearTimeout(this.pollTimeout)
    this.pollTimeout = null
  }

  toggleButtons(disabled) {
    this.resendButtons.forEach((button) => {
      button.disabled = disabled || button.dataset.employeeWelcomeResendInitiallyDisabled === "true"
    })
    if (this.hasConfirmButtonTarget) this.confirmButtonTarget.disabled = disabled
  }

  showRunModal() {
    if (!this.hasRunModalTarget || !window.bootstrap?.Modal) return

    window.bootstrap.Modal.getOrCreateInstance(this.runModalTarget).show()
  }

  hideConfirmModal() {
    if (!this.hasConfirmModalTarget || !window.bootstrap?.Modal) return

    window.bootstrap.Modal.getOrCreateInstance(this.confirmModalTarget).hide()
  }

  disposeModal() {
    if (!window.bootstrap?.Modal) return

    if (this.hasConfirmModalTarget) window.bootstrap.Modal.getInstance(this.confirmModalTarget)?.dispose()
    if (this.hasRunModalTarget) window.bootstrap.Modal.getInstance(this.runModalTarget)?.dispose()
  }

  async responseJson(response) {
    try {
      return await response.json()
    } catch (_error) {
      return {}
    }
  }

  get csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }
}
