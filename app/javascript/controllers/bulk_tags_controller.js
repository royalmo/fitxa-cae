import { Controller } from "@hotwired/stimulus"
import AsyncProgress from "controllers/async_progress"

export default class extends Controller {
  static targets = [
    "textarea",
    "addTagSelector",
    "removeTagSelector",
    "includeInactive",
    "simulateButton",
    "simulateTooltip",
    "error",
    "errorText",
    "results",
    "foundRatio",
    "tagKpis",
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
    missingBothLabel: String,
    runRequiresSimulationLabel: String,
    runNoAffectedLabel: String,
    tagKpiPrefix: String,
    confirmBody: String
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

  tagsChanged() {
    this.invalidateSimulationIfChanged()
    this.updateSimulateButton()
  }

  includeInactiveChanged() {
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
    if (ids.length === 0 || !this.hasSelectedTags) return

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
        body: JSON.stringify({
          national_ids: ids,
          bulk_tags: this.bulkTagsPayload()
        })
      })

      if (!response.ok) throw new Error(await this.responseErrorMessage(response))

      this.simulation = await response.json()
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

    if (!this.currentSimulationReady) return

    this.populateHiddenIds()
    this.confirmBodyTarget.textContent = this.replaceCount(this.confirmBodyValue, this.simulation.affected_count)

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
      if (!this.progress.running && !this.progress.completedSuccessfully) this.updateRunButton()
    }
  }

  runModalHidden() {
    this.progress.modalHidden()
  }

  renderSimulation() {
    this.resultsTarget.classList.remove("is-disabled")
    this.resultsTarget.setAttribute("aria-disabled", "false")
    this.foundRatioTarget.textContent = `${this.simulation.found_count}/${this.simulation.total_count}`
    this.affectedCountTarget.textContent = this.simulation.affected_count
    this.renderTagKpis()
    this.updateRunButton()
  }

  renderTagKpis() {
    this.tagKpisTarget.replaceChildren()

    this.simulation.tags.forEach((tag) => {
      const row = document.createElement("div")
      const label = document.createElement("dt")
      const prefix = document.createElement("span")
      const count = document.createElement("dd")

      prefix.textContent = `${this.tagKpiPrefixValue} `
      label.append(prefix)
      label.insertAdjacentHTML("beforeend", tag.html)
      count.textContent = `${tag.count}/${this.simulation.found_count}`
      row.append(label, count)
      this.tagKpisTarget.append(row)
    })
  }

  clearSimulation() {
    this.simulation = null
    this.simulatedSignature = ""
    this.resetSimulationPanel()
    this.hiddenIdsTarget.replaceChildren()
    this.hideError()
    this.updateSimulateButton()
  }

  resetSimulationPanel() {
    if (!this.hasResultsTarget) return

    this.resultsTarget.classList.add("is-disabled")
    this.resultsTarget.setAttribute("aria-disabled", "true")
    this.foundRatioTarget.textContent = "0/0"
    this.tagKpisTarget.replaceChildren()
    this.affectedCountTarget.textContent = "0"
    this.runButtonTarget.disabled = true
    this.updateRunButtonTooltip()
  }

  updateRunButton() {
    this.runButtonTarget.disabled = !this.currentSimulationReady
    this.updateRunButtonTooltip()
  }

  bulkTagsPayload() {
    return {
      add_tag_ids: this.selectedTagIds(this.addTagSelectorTarget),
      remove_tag_ids: this.selectedTagIds(this.removeTagSelectorTarget),
      include_inactive: this.includeInactiveTarget.checked
    }
  }

  populateHiddenIds() {
    this.hiddenIdsTarget.replaceChildren()

    this.parsedNationalIds().forEach((id) => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = "national_ids[]"
      input.value = id
      this.hiddenIdsTarget.append(input)
    })
  }

  parsedNationalIds() {
    return this.textareaTarget.value
      .split(/[\s,]+/)
      .map((id) => id.trim().toUpperCase())
      .filter(Boolean)
  }

  selectedTagIds(selector) {
    return Array.from(selector.querySelectorAll("[data-tag-multi-search-selected-input]"))
      .map((input) => input.value)
      .filter(Boolean)
  }

  currentSimulationSignature() {
    return [
      this.textareaTarget.value,
      this.selectedTagIds(this.addTagSelectorTarget).join(","),
      this.selectedTagIds(this.removeTagSelectorTarget).join(","),
      this.includeInactiveTarget.checked ? "1" : "0"
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
    return {
      national_ids: this.parsedNationalIds(),
      bulk_tags: this.bulkTagsPayload()
    }
  }

  resetAfterSuccessfulRun() {
    this.textareaTarget.value = ""
    this.includeInactiveTarget.checked = false
    this.clearTagSelector(this.addTagSelectorTarget)
    this.clearTagSelector(this.removeTagSelectorTarget)
    this.clearSimulation()
  }

  clearTagSelector(selector) {
    selector.querySelectorAll("[data-tag-multi-search-id]").forEach((selection) => selection.remove())
    selector.querySelectorAll(".admin-tag-multi-search-input").forEach((input) => { input.value = "" })
    selector.dispatchEvent(new Event("change", { bubbles: true }))
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
    this.updateTooltip(this.simulateTooltipTarget, disabledReason, "simulateTooltipInstance")
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

  replaceCount(template, count) {
    return template.replace("%{count}", count)
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }

  get simulateDisabledReason() {
    const missingNationalIds = this.textareaTarget.value.trim().length <= 1
    const missingTags = !this.hasSelectedTags

    if (missingNationalIds && missingTags) return this.missingBothLabelValue
    if (missingNationalIds) return this.missingNationalIdsLabelValue
    if (missingTags) return this.missingTagsLabelValue

    return ""
  }

  get currentSimulationReady() {
    return !this.runDisabledReason
  }

  get runDisabledReason() {
    if (!this.simulation || this.simulatedSignature !== this.currentSimulationSignature()) {
      return this.runRequiresSimulationLabelValue
    }

    if (this.simulation.affected_count < 1) return this.runNoAffectedLabelValue

    return ""
  }

  get hasSelectedTags() {
    return this.selectedTagIds(this.addTagSelectorTarget).length + this.selectedTagIds(this.removeTagSelectorTarget).length > 0
  }

}
