import { Controller } from "@hotwired/stimulus"
import AsyncProgress from "controllers/async_progress"

export default class extends Controller {
  static targets = [
    "textarea",
    "selectionModeInput",
    "modeTab",
    "modePanel",
    "includeTagSelector",
    "excludeTagSelector",
    "includeInactive",
    "simulateButton",
    "simulateTooltip",
    "action",
    "error",
    "errorText",
    "results",
    "foundLabel",
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
    missingTagsLabel: String,
    missingActionLabel: String,
    missingBothLabel: String,
    missingTagsAndActionLabel: String,
    confirmActivate: String,
    confirmDeactivate: String,
    confirmMessages: Object,
    runRequiresSimulationLabel: String,
    runNoAffectedLabel: String,
    foundNationalIdsLabel: String,
    foundTagsLabel: String
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

  tagsChanged() {
    this.invalidateSimulationIfChanged()
    this.updateSimulateButton()
  }

  includeInactiveChanged() {
    this.invalidateSimulationIfChanged()
    this.updateSimulateButton()
  }

  selectMode(event) {
    event.preventDefault()
    const mode = event.params.mode
    if (!mode || mode === this.selectionMode) return

    this.selectionModeInputTarget.value = mode

    this.modeTabTargets.forEach((tab) => {
      const active = tab.dataset.bulkNationalIdsModeParam === mode
      tab.classList.toggle("active", active)
      tab.setAttribute("aria-selected", active ? "true" : "false")
    })

    this.modePanelTargets.forEach((panel) => {
      panel.hidden = panel.dataset.bulkNationalIdsMode !== mode
    })

    this.invalidateSimulationIfChanged()
    if (!this.simulation) this.resetSimulationPanel()
    this.updateSimulateButton()
  }

  dismissError(event) {
    event.preventDefault()
    this.hideError()
  }

  async simulate(event) {
    event.preventDefault()

    if (this.simulateDisabledReason) return

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
        body: JSON.stringify(this.simulationPayload())
      })

      if (!response.ok) throw new Error(await this.responseErrorMessage(response))

      this.simulation = this.summary(await response.json())
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
    this.foundLabelTarget.textContent = this.selectionMode === "tags" ? this.foundTagsLabelValue : this.foundNationalIdsLabelValue
    this.foundRatioTarget.textContent = `${this.simulation.foundCount}/${this.simulation.totalCount}`
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

  summary(payload) {
    if (this.selectionMode === "tags") {
      return {
        mode: "tags",
        ids: [],
        activeCount: payload.active_count,
        inactiveCount: payload.inactive_count,
        foundCount: payload.found_count,
        totalCount: payload.total_count
      }
    }

    const ids = this.parsedNationalIds()
    const statusEntries = ids.map((id) => payload[id]).filter((value) => typeof value === "boolean")

    return {
      mode: "national_ids",
      ids,
      activeCount: statusEntries.filter(Boolean).length,
      inactiveCount: statusEntries.filter((active) => !active).length,
      foundCount: statusEntries.length,
      totalCount: ids.length
    }
  }

  affectedCount(action) {
    if (this.trueActions.includes(action)) return this.simulation.inactiveCount
    if (this.falseActions.includes(action)) return this.simulation.activeCount

    return 0
  }

  confirmationText() {
    const action = this.selectedAction
    const template = this.confirmMessagesValue[action] ||
      (action === "activate" ? this.confirmActivateValue : this.confirmDeactivateValue)

    return this.replaceCount(template, this.affectedCount(action))
  }

  populateHiddenIds() {
    this.hiddenIdsTarget.replaceChildren()

    if (this.selectionMode === "national_ids") {
      this.simulation.ids.forEach((id) => {
        const input = document.createElement("input")
        input.type = "hidden"
        input.name = "national_ids[]"
        input.value = id
        this.hiddenIdsTarget.append(input)
      })
    }
  }

  parsedNationalIds() {
    const ids = this.textareaTarget.value
      .split(/[\s,]+/)
      .map((id) => id.trim().toUpperCase())
      .filter(Boolean)

    return ids
  }

  currentSimulationSignature() {
    if (this.selectionMode === "tags") {
      return [
        this.selectedAction,
        this.selectionMode,
        this.selectedTagIds(this.includeTagSelectorTarget).join(","),
        this.selectedTagIds(this.excludeTagSelectorTarget).join(","),
        this.includeInactive ? "1" : "0"
      ].join("|")
    }

    return [
      this.selectedAction,
      this.selectionMode,
      this.textareaTarget.value,
      this.includeInactive ? "1" : "0"
    ].join("|")
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
    if (this.selectionMode === "tags") {
      return {
        bulk_action: {
          action: this.selectedAction,
          selection_mode: "tags",
          include_tag_ids: this.selectedTagIds(this.includeTagSelectorTarget),
          exclude_tag_ids: this.selectedTagIds(this.excludeTagSelectorTarget),
          include_inactive: this.includeInactive
        }
      }
    }

    return {
      national_ids: this.simulation?.ids || this.parsedNationalIds(),
      bulk_action: {
        action: this.selectedAction,
        selection_mode: "national_ids",
        include_inactive: this.includeInactive
      }
    }
  }

  resetAfterSuccessfulRun() {
    this.textareaTarget.value = ""
    this.actionTargets.forEach((action) => { action.checked = false })
    if (this.hasIncludeInactiveTarget) this.includeInactiveTarget.checked = false
    this.clearTagSelector(this.includeTagSelectorTarget)
    this.clearTagSelector(this.excludeTagSelectorTarget)
    this.clearSimulation()
  }

  simulationPayload() {
    if (this.selectionMode === "tags") {
      return {
        bulk_action: {
          selection_mode: "tags",
          include_tag_ids: this.selectedTagIds(this.includeTagSelectorTarget),
          exclude_tag_ids: this.selectedTagIds(this.excludeTagSelectorTarget),
          include_inactive: this.includeInactive
        }
      }
    }

    return {
      national_ids: this.parsedNationalIds(),
      bulk_action: {
        include_inactive: this.includeInactive
      }
    }
  }

  selectedTagIds(selector) {
    return Array.from(selector.querySelectorAll("[data-tag-multi-search-selected-input]"))
      .map((input) => input.value)
      .filter(Boolean)
  }

  clearTagSelector(selector) {
    selector.querySelectorAll("[data-tag-multi-search-id]").forEach((selection) => selection.remove())
    selector.querySelectorAll(".admin-tag-multi-search-input").forEach((input) => { input.value = "" })
    selector.dispatchEvent(new Event("change", { bubbles: true }))
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
    this.foundLabelTarget.textContent = this.selectionMode === "tags" ? this.foundTagsLabelValue : this.foundNationalIdsLabelValue
    this.foundRatioTarget.textContent = "0/0"
    this.activeRatioTarget.textContent = "0/0"
    this.affectedCountTarget.textContent = "0"
    this.runButtonTarget.disabled = true
    this.updateRunButtonTooltip()
  }

  get simulateDisabledReason() {
    const missingAction = !this.selectedAction

    if (this.selectionMode === "tags") {
      const missingTags = !this.hasSelectedTags

      if (missingTags && missingAction) return this.missingTagsAndActionLabelValue
      if (missingTags) return this.missingTagsLabelValue
      if (missingAction) return this.missingActionLabelValue

      return ""
    }

    const missingNationalIds = this.textareaTarget.value.trim().length <= 1

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

  get selectionMode() {
    return this.selectionModeInputTarget.value || "national_ids"
  }

  get hasSelectedTags() {
    return this.selectedTagIds(this.includeTagSelectorTarget).length > 0
  }

  get includeInactive() {
    return this.hasIncludeInactiveTarget && this.includeInactiveTarget.checked
  }

  get trueActions() {
    return ["activate", "allow"]
  }

  get falseActions() {
    return ["deactivate", "disallow"]
  }
}
