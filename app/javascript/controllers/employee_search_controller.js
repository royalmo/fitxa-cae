import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "employeeId", "results"]
  static values = {
    url: String
  }

  connect() {
    this.abortController = null
    this.searchTimeout = null
    this.selectedLabel = this.inputTarget.value
    this.hide = this.hide.bind(this)
    this.closeFromOutsideClick = this.closeFromOutsideClick.bind(this)
    document.addEventListener("click", this.closeFromOutsideClick)
    document.addEventListener("turbo:before-cache", this.hide)
  }

  disconnect() {
    document.removeEventListener("click", this.closeFromOutsideClick)
    document.removeEventListener("turbo:before-cache", this.hide)
    this.abortController?.abort()
    clearTimeout(this.searchTimeout)
  }

  search() {
    clearTimeout(this.searchTimeout)

    if (this.inputTarget.value !== this.selectedLabel) {
      this.employeeIdTarget.value = ""
    }

    if (this.inputTarget.value.trim() === "") {
      this.hide()
      return
    }

    this.searchTimeout = setTimeout(() => this.fetchResults(), 180)
  }

  keydown(event) {
    if (event.key === "Escape") this.hide()
    if (event.key === "Enter") this.selectFirstResult(event)
  }

  select(event) {
    this.choose(event.params.id, event.params.label)
  }

  selectFirstResult(event) {
    if (this.inputTarget.value.trim() === "") return

    event.preventDefault()
    clearTimeout(this.searchTimeout)

    if (this.chooseFirstAvailableResult()) return

    this.fetchResults({ selectFirst: true })
  }

  chooseFirstAvailableResult() {
    const result = this.resultsTarget.querySelector(".admin-employee-search-result")
    if (!result) return false

    this.choose(result.dataset.employeeSearchIdParam, result.dataset.employeeSearchLabelParam)
    return true
  }

  choose(id, label) {
    this.employeeIdTarget.value = id
    this.inputTarget.value = label
    this.selectedLabel = label
    this.hide()
    this.inputTarget.form?.requestSubmit()
  }

  fetchResults({ selectFirst = false } = {}) {
    this.abortController?.abort()
    this.abortController = new AbortController()

    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("q", this.inputTarget.value)
    if (this.employeeIdTarget.value) {
      url.searchParams.set("selected_employee_id", this.employeeIdTarget.value)
    }

    fetch(url, {
      headers: { Accept: "text/html" },
      signal: this.abortController.signal
    })
      .then((response) => {
        if (!response.ok) throw new Error(`Employee search failed: ${response.status}`)
        return response.text()
      })
      .then((html) => {
        this.resultsTarget.innerHTML = html
        this.show()
        if (selectFirst) this.chooseFirstAvailableResult()
      })
      .catch((error) => {
        if (error.name !== "AbortError") this.hide()
      })
  }

  show() {
    this.resultsTarget.hidden = false
    this.inputTarget.setAttribute("aria-expanded", "true")
  }

  hide() {
    this.resultsTarget.hidden = true
    this.inputTarget.setAttribute("aria-expanded", "false")
  }

  closeFromOutsideClick(event) {
    if (!this.element.contains(event.target)) this.hide()
  }
}
