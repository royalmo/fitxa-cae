import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "scope",
    "month",
    "year",
    "employeeField",
    "employeeId",
    "employeeQuery",
    "tagField",
    "tagId",
    "tagQuery",
    "personButton",
    "personButtonLabel",
    "summaryButton",
    "summaryCsvLink",
    "modal",
    "progress",
    "progressBar",
    "statusMessage",
    "downloadLink"
  ]
  static values = {
    exportUrl: String,
    summaryCsvUrl: String
  }

  connect() {
    this.pollTimeout = null
    this.downloadedExportIds = new Set()
    this.update()
  }

  disconnect() {
    this.stopPolling()
  }

  update() {
    const scope = this.selectedScope

    if (this.hasEmployeeFieldTarget) this.employeeFieldTarget.hidden = scope !== "person"
    if (this.hasTagFieldTarget) this.tagFieldTarget.hidden = scope !== "tag"

    if (this.hasPersonButtonTarget) this.personButtonTarget.disabled = !this.personReportReady(scope)
    if (this.hasPersonButtonLabelTarget) this.personButtonLabelTarget.textContent = this.personButtonLabel(scope)
    if (this.hasSummaryButtonTarget) this.summaryButtonTarget.disabled = !this.periodReady
    if (this.hasSummaryCsvLinkTarget) this.updateSummaryCsvLink()
  }

  personReportReady(scope) {
    if (!this.periodReady) return false
    if (scope === "company") return true
    if (scope === "tag") return this.tagReportReady

    return this.employeeReportReady
  }

  get employeeReportReady() {
    return this.hasEmployeeIdTarget &&
      this.employeeIdTarget.value.trim() !== "" &&
      this.hasEmployeeQueryTarget &&
      this.employeeQueryTarget.value.trim() !== ""
  }

  get tagReportReady() {
    return this.hasTagIdTarget &&
      this.tagIdTarget.value.trim() !== "" &&
      this.hasTagQueryTarget &&
      this.tagQueryTarget.value.trim() !== ""
  }

  get selectedScope() {
    return this.scopeTargets.find((scope) => scope.checked)?.value || "person"
  }

  personButtonLabel(scope) {
    if (!this.hasPersonButtonTarget) return ""

    return scope === "person" ?
      this.personButtonTarget.dataset.reportsDownloadPdfLabel :
      this.personButtonTarget.dataset.reportsDownloadZipLabel
  }

  get periodReady() {
    return this.hasMonthTarget && this.hasYearTarget && this.monthTarget.value !== "" && this.yearTarget.value !== ""
  }

  startPersonReport(event) {
    event.preventDefault()
    if (this.hasPersonButtonTarget && this.personButtonTarget.disabled) return

    const scope = this.selectedScope
    const payload = this.basePayload()

    if (scope === "person") {
      payload.kind = "person_pdf"
      payload.employee_id = this.employeeIdTarget.value
    } else if (scope === "tag") {
      payload.kind = "tag_zip"
      payload.tag_id = this.tagIdTarget.value
    } else {
      payload.kind = "company_zip"
    }

    this.startExport(payload)
  }

  startSummaryReport(event) {
    event.preventDefault()
    if (this.hasSummaryButtonTarget && this.summaryButtonTarget.disabled) return

    this.startExport({
      ...this.basePayload(),
      kind: "monthly_summary_pdf"
    })
  }

  updateSummaryCsvLink() {
    if (!this.periodReady) {
      this.summaryCsvLinkTarget.removeAttribute("href")
      this.summaryCsvLinkTarget.classList.add("disabled")
      this.summaryCsvLinkTarget.setAttribute("aria-disabled", "true")
      return
    }

    const url = new URL(this.summaryCsvUrlValue, window.location.origin)
    url.searchParams.set("month", this.monthTarget.value)
    url.searchParams.set("year", this.yearTarget.value)

    this.summaryCsvLinkTarget.href = `${url.pathname}${url.search}`
    this.summaryCsvLinkTarget.classList.remove("disabled")
    this.summaryCsvLinkTarget.removeAttribute("aria-disabled")
  }

  basePayload() {
    return {
      month: this.monthTarget.value,
      year: this.yearTarget.value
    }
  }

  async startExport(payload) {
    this.stopPolling()
    this.resetModal()
    this.showModal()

    try {
      const response = await fetch(this.exportUrlValue, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify(payload)
      })
      const data = await response.json()

      if (!response.ok) throw new Error(data.error || "No s'ha pogut iniciar l'informe.")

      this.renderExportStatus(data)
      this.schedulePoll(data.status_url)
    } catch (error) {
      this.renderExportError(error.message)
    }
  }

  schedulePoll(statusUrl) {
    if (!statusUrl) return

    this.pollTimeout = window.setTimeout(() => this.poll(statusUrl), 2000)
  }

  async poll(statusUrl) {
    try {
      const response = await fetch(statusUrl, { headers: { Accept: "application/json" } })
      const data = await response.json()

      if (!response.ok) throw new Error(data.error || "No s'ha pogut consultar l'informe.")

      this.renderExportStatus(data)
      if (data.status === "completed" && data.download_url) {
        this.enableDownload(data.download_url)
        this.triggerDownload(data)
      } else if (data.status !== "failed" && data.status !== "expired") {
        this.schedulePoll(data.status_url)
      }
    } catch (error) {
      this.renderExportError(error.message)
    }
  }

  stopPolling() {
    if (this.pollTimeout) window.clearTimeout(this.pollTimeout)
    this.pollTimeout = null
  }

  resetModal() {
    this.setProgress(0)
    if (this.hasStatusMessageTarget) this.statusMessageTarget.textContent = ""
    if (this.hasProgressBarTarget) {
      this.progressBarTarget.classList.add("progress-bar-animated", "progress-bar-striped")
      this.progressBarTarget.classList.remove("bg-danger", "bg-success")
    }
    if (this.hasDownloadLinkTarget) {
      this.downloadLinkTarget.removeAttribute("href")
      this.downloadLinkTarget.classList.add("disabled")
      this.downloadLinkTarget.setAttribute("aria-disabled", "true")
    }
  }

  renderExportStatus(data) {
    this.setProgress(data.progress || 0)
    if (this.hasStatusMessageTarget) this.statusMessageTarget.textContent = data.message || ""

    if (data.status === "completed" && this.hasProgressBarTarget) {
      this.progressBarTarget.classList.remove("progress-bar-animated", "progress-bar-striped", "bg-danger")
      this.progressBarTarget.classList.add("bg-success")
    } else if ((data.status === "failed" || data.status === "expired") && this.hasProgressBarTarget) {
      this.progressBarTarget.classList.remove("progress-bar-animated", "progress-bar-striped", "bg-success")
      this.progressBarTarget.classList.add("bg-danger")
    }
  }

  renderExportError(message) {
    this.stopPolling()
    this.setProgress(100)
    if (this.hasStatusMessageTarget) this.statusMessageTarget.textContent = message
    if (this.hasProgressBarTarget) {
      this.progressBarTarget.classList.remove("progress-bar-animated", "progress-bar-striped", "bg-success")
      this.progressBarTarget.classList.add("bg-danger")
    }
  }

  setProgress(progress) {
    const normalizedProgress = Math.max(0, Math.min(Number.parseInt(progress, 10) || 0, 100))

    if (this.hasProgressTarget) {
      this.progressTarget.setAttribute("aria-valuenow", normalizedProgress.toString())
    }
    if (this.hasProgressBarTarget) {
      this.progressBarTarget.style.width = `${normalizedProgress}%`
      this.progressBarTarget.textContent = `${normalizedProgress}%`
    }
  }

  enableDownload(downloadUrl) {
    if (!this.hasDownloadLinkTarget) return

    this.downloadLinkTarget.href = downloadUrl
    this.downloadLinkTarget.classList.remove("disabled")
    this.downloadLinkTarget.removeAttribute("aria-disabled")
  }

  triggerDownload(data) {
    if (this.downloadedExportIds.has(data.id)) return

    this.downloadedExportIds.add(data.id)
    window.location.href = data.download_url
  }

  showModal() {
    if (!this.hasModalTarget || !window.bootstrap?.Modal) return

    window.bootstrap.Modal.getOrCreateInstance(this.modalTarget).show()
  }

  get csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }
}
