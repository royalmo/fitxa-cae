import { Controller } from "@hotwired/stimulus"
import AsyncProgress from "controllers/async_progress"

export default class extends Controller {
  static targets = [
    "textarea",
    "simulateButton",
    "simulateTooltip",
    "action",
    "error",
    "errorText",
    "results",
    "foundRatio",
    "activeRatio",
    "affectedCount",
    "runButton",
    "runTooltip",
    "confirmRunButton",
    "hiddenIds",
    "confirmBody",
    "runModal",
    "runProgress",
    "runProgressBar",
    "runStatusMessage"
  ]

  static values = {
    simulateUrl: String,
    runUrl: String,
    confirmModalId: String,
    requestErrorLabel: String,
    runRequestErrorLabel: String,
    runPollErrorLabel: String,
    missingNationalIdsLabel: String,
    missingActionLabel: String,
    missingBothLabel: String,
    confirmActivate: String,
    confirmDeactivate: String,
    runRequiresSimulationLabel: String,
    runNoAffectedLabel: String
  }

  connect() {
    this.simulation = null
    this.simulatedSignature = ""
    this.disposeTooltips = this.disposeTooltips.bind(this)
    this.progress = new AsyncProgress(this, {
      modalTargetName: "runModal",
      progressTargetName: "runProgress",
      progressBarTargetName: "runProgressBar",
      statusMessageTargetName: "runStatusMessage",
      startErrorLabel: this.runRequestErrorLabelValue,
      pollErrorLabel: this.runPollErrorLabelValue,
      onSuccessClosed: () => this.resetAfterSuccessfulRun()
    })
    this.resetSimulationPanel()
    this.input()
    document.addEventListener("turbo:before-cache", this.disposeTooltips)
  }

  disconnect() {
    document.removeEventListener("turbo:before-cache", this.disposeTooltips)
    this.disposeTooltips()
    this.progress.disconnect()
  }

  input() {
    this.invalidateSimulationIfChanged()
    this.updateSimulateButton()
  }

  actionChanged() {
    this.invalidateSimulationIfChanged()
    this.updateSimulateButton()
  }

  dismissError(event) {
    event.preventDefault()
    this.hideError()
  }

  async simulate(event) {
    event.preventDefault()

    const ids = this.parsedNationalIds()
    if (ids.length === 0 || !this.selectedAction) return

    this.showLoading()
    this.hideError()

    try {
      const response = await fetch(this.simulateUrlValue, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken()
        },
        body: JSON.stringify({ national_ids: ids })
      })

      if (!response.ok) throw new Error(await this.responseErrorMessage(response))

      const statuses = await response.json()
      this.simulation = this.summary(ids, statuses)
      this.simulatedSignature = this.currentSimulationSignature()
      this.renderSimulation()
    } catch (error) {
      this.clearSimulation()
      this.showError(error.message || this.requestErrorLabelValue)
    } finally {
      this.hideLoading()
    }
  }

  openConfirm(event) {
    event.preventDefault()

    if (!this.simulation || !this.selectedAction) return

    this.populateHiddenIds()
    this.confirmBodyTarget.textContent = this.confirmationText()

    const modalElement = document.getElementById(this.confirmModalIdValue)
    const Modal = window.bootstrap?.Modal
    if (modalElement && Modal) Modal.getOrCreateInstance(modalElement).show()
  }

  async startRun(event) {
    event.preventDefault()
    if (!this.currentSimulationReady) return

    this.setConfirmLoading(true)
    this.disableRunButton()
    this.hideConfirmModal()
    this.hideError()

    try {
      await this.progress.start(this.runUrlValue, this.runPayload())
    } catch (_error) {
      // The progress modal renders request and polling errors.
    } finally {
      this.setConfirmLoading(false)
      if (!this.progress.running && !this.progress.completedSuccessfully) this.renderAffectedCount()
    }
  }

  runModalHidden() {
    this.progress.modalHidden()
  }

  renderSimulation() {
    this.resultsTarget.classList.remove("is-disabled")
    this.resultsTarget.setAttribute("aria-disabled", "false")
    this.foundRatioTarget.textContent = `${this.simulation.foundCount}/${this.simulation.ids.length}`
    this.activeRatioTarget.textContent = `${this.simulation.activeCount}/${this.simulation.foundCount}`
    this.renderAffectedCount()
  }

  renderAffectedCount() {
    if (!this.simulation) return

    const action = this.selectedAction
    this.runButtonTarget.disabled = !this.currentSimulationReady
    this.updateRunButtonTooltip()
    this.affectedCountTarget.textContent = this.affectedCount(action)
  }

  clearSimulation() {
    this.simulation = null
    this.simulatedSignature = ""
    this.resetSimulationPanel()
    this.hiddenIdsTarget.replaceChildren()
    this.hideError()
    this.updateSimulateButton()
  }

  summary(ids, statuses) {
    const statusEntries = ids.map((id) => statuses[id]).filter((value) => typeof value === "boolean")

    return {
      ids,
      activeCount: statusEntries.filter(Boolean).length,
      inactiveCount: statusEntries.filter((active) => !active).length,
      foundCount: statusEntries.length
    }
  }

  affectedCount(action) {
    if (action === "activate") return this.simulation.inactiveCount
    if (action === "deactivate") return this.simulation.activeCount

    return 0
  }

  confirmationText() {
    const action = this.selectedAction
    const template = action === "activate" ? this.confirmActivateValue : this.confirmDeactivateValue

    return this.replaceCount(template, this.affectedCount(action))
  }

  populateHiddenIds() {
    this.hiddenIdsTarget.replaceChildren()

    this.simulation.ids.forEach((id) => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = "national_ids[]"
      input.value = id
      this.hiddenIdsTarget.append(input)
    })
  }

  parsedNationalIds() {
    const ids = this.textareaTarget.value
      .split(/[\s,]+/)
      .map((id) => id.trim().toUpperCase())
      .filter(Boolean)

    return ids
  }

  currentSimulationSignature() {
    return [this.selectedAction, this.textareaTarget.value].join("|")
  }

  invalidateSimulationIfChanged() {
    if (this.simulation && this.simulatedSignature !== this.currentSimulationSignature()) {
      this.clearSimulation()
    }
  }

  showLoading() {
    this.simulateButtonTarget.disabled = true
    this.simulateButtonTarget.setAttribute("aria-busy", "true")
  }

  hideLoading() {
    this.simulateButtonTarget.removeAttribute("aria-busy")
    this.updateSimulateButton()
  }

  showError(message) {
    this.errorTextTarget.textContent = message
    this.errorTarget.hidden = false
  }

  hideError() {
    this.errorTarget.hidden = true
    this.errorTextTarget.textContent = ""
  }

  setConfirmLoading(loading) {
    if (!this.hasConfirmRunButtonTarget) return

    this.confirmRunButtonTarget.disabled = loading
    this.confirmRunButtonTarget.toggleAttribute("aria-busy", loading)
  }

  disableRunButton() {
    this.runButtonTarget.disabled = true
    this.updateRunButtonTooltip()
  }

  hideConfirmModal() {
    const modalElement = document.getElementById(this.confirmModalIdValue)
    if (!modalElement || !window.bootstrap?.Modal) return

    window.bootstrap.Modal.getOrCreateInstance(modalElement).hide()
  }

  runPayload() {
    return {
      national_ids: this.simulation?.ids || [],
      bulk_action: {
        action: this.selectedAction
      }
    }
  }

  resetAfterSuccessfulRun() {
    this.textareaTarget.value = ""
    this.actionTargets.forEach((action) => { action.checked = false })
    this.clearSimulation()
  }

  replaceCount(template, count) {
    return template.replace("%{count}", count)
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }

  async responseErrorMessage(response) {
    try {
      const body = await response.json()
      return body.error || this.requestErrorLabelValue
    } catch (_error) {
      return this.requestErrorLabelValue
    }
  }

  updateSimulateButton() {
    const disabledReason = this.simulateDisabledReason

    this.simulateButtonTarget.disabled = Boolean(disabledReason)
    this.updateSimulateTooltip(disabledReason)
  }

  updateSimulateTooltip(message) {
    this.updateTooltip(this.simulateTooltipTarget, message, "simulateTooltipInstance")
  }

  updateRunButtonTooltip() {
    const message = this.runButtonTarget.disabled ? this.runDisabledReason : ""

    this.runTooltipTarget.classList.toggle("is-disabled", Boolean(message))
    this.updateTooltip(this.runTooltipTarget, message, "runTooltipInstance")
  }

  updateTooltip(tooltipElement, message, instanceProperty) {
    if (!message) {
      tooltipElement.removeAttribute("title")
      tooltipElement.removeAttribute("data-bs-original-title")
      tooltipElement.removeAttribute("tabindex")
      this.disposeTooltipInstance(instanceProperty)
      return
    }

    tooltipElement.setAttribute("title", message)
    tooltipElement.setAttribute("data-bs-original-title", message)
    tooltipElement.setAttribute("tabindex", "0")
    this[instanceProperty]?.setContent?.({ ".tooltip-inner": message })

    if (!this[instanceProperty] && window.bootstrap?.Tooltip) {
      this[instanceProperty] = window.bootstrap.Tooltip.getOrCreateInstance(tooltipElement, {
        container: "body",
        trigger: "hover focus"
      })
    }
  }

  disposeTooltipInstance(instanceProperty) {
    this[instanceProperty]?.dispose()
    this[instanceProperty] = null
  }

  disposeTooltips() {
    this.disposeTooltipInstance("simulateTooltipInstance")
    this.disposeTooltipInstance("runTooltipInstance")
  }

  resetSimulationPanel() {
    if (!this.hasResultsTarget) return

    this.resultsTarget.classList.add("is-disabled")
    this.resultsTarget.setAttribute("aria-disabled", "true")
    this.foundRatioTarget.textContent = "0/0"
    this.activeRatioTarget.textContent = "0/0"
    this.affectedCountTarget.textContent = "0"
    this.runButtonTarget.disabled = true
    this.updateRunButtonTooltip()
  }

  get simulateDisabledReason() {
    const missingNationalIds = this.textareaTarget.value.trim().length <= 1
    const missingAction = !this.selectedAction

    if (missingNationalIds && missingAction) return this.missingBothLabelValue
    if (missingNationalIds) return this.missingNationalIdsLabelValue
    if (missingAction) return this.missingActionLabelValue

    return ""
  }

  get currentSimulationReady() {
    return !this.runDisabledReason
  }

  get runDisabledReason() {
    if (!this.simulation || this.simulatedSignature !== this.currentSimulationSignature()) {
      return this.runRequiresSimulationLabelValue
    }

    if (!this.selectedAction) return this.runRequiresSimulationLabelValue
    if (this.affectedCount(this.selectedAction) < 1) return this.runNoAffectedLabelValue

    return ""
  }

  get selectedAction() {
    return this.actionTargets.find((action) => action.checked)?.value || ""
  }
}
