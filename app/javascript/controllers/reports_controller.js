import { Controller } from "@hotwired/stimulus"
import AsyncProgress from "controllers/async_progress"

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
    summaryCsvUrl: String,
    startErrorLabel: String,
    pollErrorLabel: String
  }

  connect() {
    this.downloadedExportIds = new Set()
    this.progress = new AsyncProgress(this, {
      startErrorLabel: this.startErrorLabelValue,
      pollErrorLabel: this.pollErrorLabelValue,
      isFinished: (data) => this.exportFinished(data),
      isSuccess: (data) => data.status === "completed" && Boolean(data.download_url),
      onReset: () => this.resetDownloadLink(),
      onStatus: (data) => this.handleExportStatus(data)
    })
    this.update()
  }

  disconnect() {
    this.progress.disconnect()
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
    try {
      await this.progress.start(this.exportUrlValue, payload)
    } catch (_error) {
      // The progress modal renders request and polling errors.
    }
  }

  exportFinished(data) {
    return (data.status === "completed" && Boolean(data.download_url)) ||
      data.status === "failed" ||
      data.status === "expired"
  }

  handleExportStatus(data) {
    if (data.status !== "completed" || !data.download_url) return

    this.enableDownload(data.download_url)
    this.triggerDownload(data)
  }

  resetDownloadLink() {
    if (!this.hasDownloadLinkTarget) return

    this.downloadLinkTarget.removeAttribute("href")
    this.downloadLinkTarget.classList.add("disabled")
    this.downloadLinkTarget.setAttribute("aria-disabled", "true")
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

}
