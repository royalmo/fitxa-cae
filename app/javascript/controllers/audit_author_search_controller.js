import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "author", "results", "clearButton"]
  static values = {
    url: String,
    autoSubmit: Boolean,
    useAuthorType: Boolean
  }

  connect() {
    this.abortController = null
    this.searchTimeout = null
    this.selectedLabel = this.inputTarget.value
    this.hide = this.hide.bind(this)
    this.closeFromOutsideClick = this.closeFromOutsideClick.bind(this)
    document.addEventListener("click", this.closeFromOutsideClick)
    document.addEventListener("turbo:before-cache", this.hide)
    this.updateClearButton()
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
      this.setAuthor("")
    }

    if (this.inputTarget.value.trim() === "") {
      this.hide()
      return
    }

    this.searchTimeout = setTimeout(() => this.fetchResults(), 180)
  }

  keydown(event) {
    if (event.key === "Escape") this.hide()
    if (event.key === "Enter") {
      if (!this.autoSubmitEnabled) event.preventDefault()
      this.selectFirstResult(event)
    }
  }

  select(event) {
    this.choose(event.params.id, event.params.label)
  }

  clear(event) {
    event.preventDefault()
    this.setAuthor("")
    this.inputTarget.value = ""
    this.selectedLabel = ""
    this.hide()
    this.inputTarget.focus()
    if (this.autoSubmitEnabled) this.inputTarget.form?.requestSubmit()
  }

  selectFirstResult(event) {
    if (this.inputTarget.value.trim() === "") return

    event.preventDefault()
    clearTimeout(this.searchTimeout)

    if (this.chooseFirstAvailableResult()) return

    this.fetchResults({ selectFirst: true })
  }

  chooseFirstAvailableResult() {
    const result = this.resultsTarget.querySelector(".admin-audit-author-search-result")
    if (!result) return false

    this.choose(result.dataset.auditAuthorSearchIdParam, result.dataset.auditAuthorSearchLabelParam)
    return true
  }

  choose(id, label) {
    this.setAuthor(id)
    this.inputTarget.value = label
    this.selectedLabel = label
    this.hide()
    if (this.autoSubmitEnabled) this.inputTarget.form?.requestSubmit()
  }

  setAuthor(id) {
    const previousId = this.authorTarget.value

    this.authorTarget.value = id
    this.updateClearButton()
    if (previousId !== id) {
      this.authorTarget.dispatchEvent(new Event("change", { bubbles: true }))
    }
  }

  fetchResults({ selectFirst = false } = {}) {
    this.abortController?.abort()
    this.abortController = new AbortController()

    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("q", this.inputTarget.value)
    if (this.authorTarget.value) {
      url.searchParams.set("selected_author", this.authorTarget.value)
    }
    if (this.authorType) {
      url.searchParams.set("author_type", this.authorType)
    }

    fetch(url, {
      headers: { Accept: "text/html" },
      signal: this.abortController.signal
    })
      .then((response) => {
        if (!response.ok) throw new Error(`Audit author search failed: ${response.status}`)
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

  updateClearButton() {
    if (this.hasClearButtonTarget) this.clearButtonTarget.disabled = this.authorTarget.value === ""
  }

  get authorType() {
    if (!this.useAuthorTypeEnabled) return ""

    return this.inputTarget.form?.querySelector("input[name='author_type']:checked")?.value || ""
  }

  get useAuthorTypeEnabled() {
    return this.hasUseAuthorTypeValue ? this.useAuthorTypeValue : true
  }

  get autoSubmitEnabled() {
    return this.hasAutoSubmitValue ? this.autoSubmitValue : true
  }
}
