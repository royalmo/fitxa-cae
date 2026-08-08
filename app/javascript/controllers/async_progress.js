export default class AsyncProgress {
  constructor(controller, {
    modalTargetName = "modal",
    progressTargetName = "progress",
    progressBarTargetName = "progressBar",
    statusMessageTargetName = "statusMessage",
    startErrorLabel,
    pollErrorLabel,
    isFinished,
    isSuccess,
    onReset,
    onStatus,
    onSuccessClosed
  } = {}) {
    this.controller = controller
    this.targetNames = {
      modal: modalTargetName,
      progress: progressTargetName,
      progressBar: progressBarTargetName,
      statusMessage: statusMessageTargetName
    }
    this.startErrorLabel = startErrorLabel
    this.pollErrorLabel = pollErrorLabel
    this.isFinished = isFinished || ((data) => ["completed", "failed", "expired"].includes(data.status))
    this.isSuccess = isSuccess || ((data) => data.status === "completed")
    this.onReset = onReset
    this.onStatus = onStatus
    this.onSuccessClosed = onSuccessClosed
    this.pollTimeout = null
    this.running = false
    this.hiddenWhileRunning = false
    this.completedSuccessfully = false
  }

  disconnect() {
    this.stopPolling()
  }

  async start(url, payload) {
    if (this.running) return

    this.stopPolling()
    this.running = true
    this.hiddenWhileRunning = false
    this.completedSuccessfully = false
    this.resetModal()
    this.showModal()

    try {
      const response = await fetch(url, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify(payload)
      })
      const data = await this.responseJson(response)

      if (!response.ok) throw new Error(data.error || this.startErrorLabel)

      this.renderStatus(data)
      this.advance(data)
    } catch (error) {
      this.renderError(error.message || this.startErrorLabel)
      throw error
    }
  }

  modalHidden() {
    if (this.running) {
      this.hiddenWhileRunning = true
      return
    }

    if (!this.completedSuccessfully) return

    this.completedSuccessfully = false
    this.onSuccessClosed?.()
  }

  schedulePoll(statusUrl) {
    if (!statusUrl) return

    this.pollTimeout = window.setTimeout(() => this.poll(statusUrl), 2000)
  }

  async poll(statusUrl) {
    try {
      const response = await fetch(statusUrl, { headers: { Accept: "application/json" } })
      const data = await this.responseJson(response)

      if (!response.ok) throw new Error(data.error || this.pollErrorLabel)

      this.renderStatus(data)
      this.advance(data)
    } catch (error) {
      this.renderError(error.message || this.pollErrorLabel)
    }
  }

  advance(data) {
    if (this.isFinished(data)) {
      this.running = false
      this.completedSuccessfully = this.isSuccess(data)
      this.showModalIfHidden()
      return
    }

    this.schedulePoll(data.status_url)
  }

  stopPolling() {
    if (this.pollTimeout) window.clearTimeout(this.pollTimeout)
    this.pollTimeout = null
  }

  resetModal() {
    this.setProgress(0)
    if (this.hasTarget("statusMessage")) {
      this.target("statusMessage").textContent = ""
      this.target("statusMessage").classList.add("text-body-secondary")
      this.target("statusMessage").classList.remove("text-danger", "text-success")
    }
    if (this.hasTarget("progressBar")) {
      this.target("progressBar").classList.add("progress-bar-animated", "progress-bar-striped")
      this.target("progressBar").classList.remove("bg-danger", "bg-success")
    }
    this.onReset?.()
  }

  renderStatus(data) {
    this.setProgress(data.progress || 0)
    if (this.hasTarget("statusMessage")) this.target("statusMessage").textContent = data.message || ""
    this.onStatus?.(data)

    if (this.isFinished(data)) {
      this.renderTerminalState(this.isSuccess(data) ? "success" : "danger")
    }
  }

  renderError(message) {
    this.stopPolling()
    this.running = false
    this.completedSuccessfully = false
    this.setProgress(100)
    if (this.hasTarget("statusMessage")) this.target("statusMessage").textContent = message
    this.renderTerminalState("danger")
    this.showModalIfHidden()
  }

  renderTerminalState(kind) {
    if (this.hasTarget("progressBar")) {
      this.target("progressBar").classList.remove("progress-bar-animated", "progress-bar-striped", "bg-danger", "bg-success")
      this.target("progressBar").classList.add(kind === "success" ? "bg-success" : "bg-danger")
    }
    if (this.hasTarget("statusMessage")) {
      this.target("statusMessage").classList.remove("text-body-secondary", "text-danger", "text-success")
      this.target("statusMessage").classList.add(kind === "success" ? "text-success" : "text-danger")
    }
  }

  setProgress(progress) {
    const normalizedProgress = Math.max(0, Math.min(Number.parseInt(progress, 10) || 0, 100))

    if (this.hasTarget("progress")) {
      this.target("progress").setAttribute("aria-valuenow", normalizedProgress.toString())
    }
    if (this.hasTarget("progressBar")) {
      this.target("progressBar").style.width = `${normalizedProgress}%`
      this.target("progressBar").textContent = `${normalizedProgress}%`
    }
  }

  showModalIfHidden() {
    if (this.hiddenWhileRunning) this.showModal()
  }

  showModal() {
    if (!this.hasTarget("modal") || !window.bootstrap?.Modal) return

    this.hiddenWhileRunning = false
    window.bootstrap.Modal.getOrCreateInstance(this.target("modal")).show()
  }

  hasTarget(kind) {
    return Boolean(this.controller[this.hasTargetProperty(kind)])
  }

  target(kind) {
    return this.controller[this.targetProperty(kind)]
  }

  hasTargetProperty(kind) {
    return `has${this.classifiedTargetName(kind)}Target`
  }

  targetProperty(kind) {
    return `${this.targetNames[kind]}Target`
  }

  classifiedTargetName(kind) {
    const targetName = this.targetNames[kind]

    return targetName.charAt(0).toUpperCase() + targetName.slice(1)
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
