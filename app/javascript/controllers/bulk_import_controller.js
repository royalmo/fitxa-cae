import { Controller } from "@hotwired/stimulus"
import AsyncProgress from "controllers/async_progress"

export default class extends Controller {
  static targets = [
    "source",
    "pastedData",
    "fileInput",
    "allowSecondSurname",
    "tagSelector",
    "templateLink",
    "formatText",
    "simulateButton",
    "simulateTooltip",
    "error",
    "errorText",
    "results",
    "importableRatio",
    "existingCount",
    "affectedCount",
    "runButton",
    "runTooltip",
    "confirmRunButton",
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
    missingDataLabel: String,
    runRequiresSimulationLabel: String,
    runNoAffectedLabel: String,
    confirmCreatedBody: String,
    confirmCreatedAndExistingTagsBody: String,
    confirmExistingTagsBody: String,
    formatLabel: String,
    secondSurnameFormatLabel: String,
    pastedDataPlaceholder: String,
    secondSurnamePastedDataPlaceholder: String,
    templateContent: String,
    secondSurnameTemplateContent: String
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
    this.updateSecondSurnameDependentContent()
    this.input()
    document.addEventListener("turbo:before-cache", this.disposeTooltips)
  }

  disconnect() {
    document.removeEventListener("turbo:before-cache", this.disposeTooltips)
    this.disposeTooltips()
    this.progress.disconnect()
    this.revokeTemplateLink()
  }

  selectSource(event) {
    this.sourceTarget.value = event.params.source
    this.input()
  }

  input() {
    this.invalidateSimulationIfChanged()
    this.updateSimulateButton()
  }

  tagsChanged() {
    this.invalidateSimulationIfChanged()
    this.updateSimulateButton()
  }

  secondSurnameChanged() {
    this.updateSecondSurnameDependentContent()
    this.input()
  }

  dismissError(event) {
    event.preventDefault()
    this.hideError()
  }

  async simulate(event) {
    event.preventDefault()

    if (!this.contentPresent) return

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
          source: this.source,
          content: await this.importContent(),
          allow_second_surname: this.allowSecondSurname,
          tag_ids: this.selectedTagIds()
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

    this.confirmBodyTarget.textContent = this.confirmMessage()

    const modalElement = document.getElementById(this.confirmModalIdValue)
    const Modal = window.bootstrap?.Modal
    if (modalElement && Modal) Modal.getOrCreateInstance(modalElement).show()
  }

  async startRun(event) {
    event.preventDefault()
    if (!this.currentSimulationReady) return

    this.setConfirmLoading(true)
    this.disableRunButton()
    this.hideError()
    let submitted = false

    try {
      const payload = await this.runPayload()
      this.hideConfirmModal()
      submitted = true
      await this.progress.start(this.runUrlValue, payload)
    } catch (error) {
      if (!submitted) this.showError(error.message || this.runRequestErrorLabelValue)
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
    this.importableRatioTarget.textContent = `${this.simulation.importable_count}/${this.simulation.total_count}`
    this.existingCountTarget.textContent = this.simulation.existing_count
    this.affectedCountTarget.textContent = this.simulation.importable_count
    this.updateRunButton()
  }

  clearSimulation() {
    this.simulation = null
    this.simulatedSignature = ""
    this.resetSimulationPanel()
    this.hideError()
    this.updateSimulateButton()
  }

  resetSimulationPanel() {
    if (!this.hasResultsTarget) return

    this.resultsTarget.classList.add("is-disabled")
    this.resultsTarget.setAttribute("aria-disabled", "true")
    this.importableRatioTarget.textContent = "0/0"
    this.existingCountTarget.textContent = "0"
    this.affectedCountTarget.textContent = "0"
    this.runButtonTarget.disabled = true
    this.updateRunButtonTooltip()
  }

  updateRunButton() {
    this.runButtonTarget.disabled = !this.currentSimulationReady
    this.updateRunButtonTooltip()
  }

  async importContent() {
    if (this.source === "file") return this.selectedFile?.text() || ""

    return this.pastedDataTarget.value
  }

  selectedTagIds() {
    return Array.from(this.tagSelectorTarget.querySelectorAll("[data-tag-multi-search-selected-input]"))
      .map((input) => input.value)
      .filter(Boolean)
  }

  currentSimulationSignature() {
    return [
      this.source,
      this.allowSecondSurname,
      this.source === "file" ? this.fileSignature : this.pastedDataTarget.value,
      this.selectedTagIds().join(",")
    ].join("|")
  }

  updateSecondSurnameDependentContent() {
    if (this.hasPastedDataTarget) {
      this.pastedDataTarget.placeholder = this.allowSecondSurname
        ? this.secondSurnamePastedDataPlaceholderValue
        : this.pastedDataPlaceholderValue
    }

    if (this.hasFormatTextTarget) {
      this.formatTextTarget.textContent = this.allowSecondSurname
        ? this.secondSurnameFormatLabelValue
        : this.formatLabelValue
    }

    this.createTemplateLink()
  }

  invalidateSimulationIfChanged() {
    if (this.simulation && this.simulatedSignature !== this.currentSimulationSignature()) {
      this.clearSimulation()
    }
  }

  createTemplateLink() {
    if (!this.hasTemplateLinkTarget) return

    this.revokeTemplateLink()

    const blob = new Blob([this.templateContent], { type: "text/csv;charset=utf-8" })
    this.templateUrl = URL.createObjectURL(blob)
    this.templateLinkTarget.href = this.templateUrl
  }

  revokeTemplateLink() {
    if (!this.templateUrl) return

    URL.revokeObjectURL(this.templateUrl)
    this.templateUrl = null
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

  async runPayload() {
    return {
      source: this.source,
      content: await this.importContent(),
      allow_second_surname: this.allowSecondSurname,
      tag_ids: this.selectedTagIds()
    }
  }

  resetAfterSuccessfulRun() {
    this.element.querySelector("form")?.reset()
    this.sourceTarget.value = "paste"
    this.clearTagSelector(this.tagSelectorTarget)
    this.updateSecondSurnameDependentContent()
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

  confirmMessage() {
    const createdCount = this.simulation.importable_count
    const existingTagUpdateCount = this.simulation.existing_tag_update_count

    if (createdCount > 0 && existingTagUpdateCount > 0) {
      return this.replacePlaceholders(this.confirmCreatedAndExistingTagsBodyValue, {
        created_count: createdCount,
        tagged_count: existingTagUpdateCount
      })
    }

    if (existingTagUpdateCount > 0) {
      return this.replacePlaceholders(this.confirmExistingTagsBodyValue, {
        tagged_count: existingTagUpdateCount
      })
    }

    return this.replacePlaceholders(this.confirmCreatedBodyValue, { count: createdCount })
  }

  replacePlaceholders(template, values) {
    return Object.entries(values).reduce(
      (message, [key, value]) => message.replace(`%{${key}}`, value),
      template
    )
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }

  get simulateDisabledReason() {
    return this.contentPresent ? "" : this.missingDataLabelValue
  }

  get currentSimulationReady() {
    return !this.runDisabledReason
  }

  get runDisabledReason() {
    if (!this.simulation || this.simulatedSignature !== this.currentSimulationSignature()) {
      return this.runRequiresSimulationLabelValue
    }

    if (this.simulation.actionable_count < 1) return this.runNoAffectedLabelValue

    return ""
  }

  get contentPresent() {
    if (this.source === "file") return Boolean(this.selectedFile)

    return this.pastedDataTarget.value.trim().length > 1
  }

  get selectedFile() {
    return this.fileInputTarget.files?.[0]
  }

  get allowSecondSurname() {
    return this.hasAllowSecondSurnameTarget && this.allowSecondSurnameTarget.checked
  }

  get templateContent() {
    return this.allowSecondSurname ? this.secondSurnameTemplateContentValue : this.templateContentValue
  }

  get fileSignature() {
    const file = this.selectedFile
    if (!file) return ""

    return [file.name, file.size, file.lastModified].join(":")
  }

  get source() {
    return this.sourceTarget.value
  }
}
