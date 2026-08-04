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
    "summaryButton"
  ]

  connect() {
    this.update()
  }

  update() {
    const scope = this.selectedScope

    if (this.hasEmployeeFieldTarget) this.employeeFieldTarget.hidden = scope !== "person"
    if (this.hasTagFieldTarget) this.tagFieldTarget.hidden = scope !== "tag"

    if (this.hasPersonButtonTarget) this.personButtonTarget.disabled = !this.personReportReady(scope)
    if (this.hasPersonButtonLabelTarget) this.personButtonLabelTarget.textContent = this.personButtonLabel(scope)
    if (this.hasSummaryButtonTarget) this.summaryButtonTarget.disabled = !this.periodReady
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
}
