import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "tagId", "results", "field", "selection", "selectionLabel"]
  static values = {
    url: String,
    autoSubmit: Boolean
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
      this.setTagId("")
      this.hideSelection()
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
    this.choose(event.params.id, event.params.label, event.params.style)
  }

  clear(event) {
    event.preventDefault()
    this.setTagId("")
    this.inputTarget.value = ""
    this.selectedLabel = ""
    this.hideSelection()
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
    const result = this.resultsTarget.querySelector(".admin-tag-search-result")
    if (!result) return false

    this.choose(
      result.dataset.tagSearchIdParam,
      result.dataset.tagSearchLabelParam,
      result.dataset.tagSearchStyleParam
    )
    return true
  }

  choose(id, label, style) {
    this.setTagId(id)
    this.inputTarget.value = label
    this.selectedLabel = label
    this.showSelection(label, style)
    this.hide()
    if (this.autoSubmitEnabled) this.inputTarget.form?.requestSubmit()
  }

  setTagId(id) {
    const previousId = this.tagIdTarget.value

    this.tagIdTarget.value = id
    if (previousId !== id) {
      this.tagIdTarget.dispatchEvent(new Event("change", { bubbles: true }))
    }
  }

  fetchResults({ selectFirst = false } = {}) {
    this.abortController?.abort()
    this.abortController = new AbortController()

    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("q", this.inputTarget.value)
    if (this.tagIdTarget.value) {
      url.searchParams.set("selected_tag_id", this.tagIdTarget.value)
    }

    fetch(url, {
      headers: { Accept: "text/html" },
      signal: this.abortController.signal
    })
      .then((response) => {
        if (!response.ok) throw new Error(`Tag search failed: ${response.status}`)
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

  showSelection(label, style) {
    if (!this.hasSelectionTarget || !this.hasSelectionLabelTarget) return

    this.selectionLabelTarget.textContent = label
    this.selectionTarget.setAttribute("style", style || "")
    this.selectionTarget.hidden = false
    if (this.hasFieldTarget) this.fieldTarget.classList.add("has-selected-tag")
  }

  hideSelection() {
    if (this.hasSelectionTarget) {
      this.selectionTarget.hidden = true
      this.selectionTarget.removeAttribute("style")
    }
    if (this.hasSelectionLabelTarget) this.selectionLabelTarget.textContent = ""
    if (this.hasFieldTarget) this.fieldTarget.classList.remove("has-selected-tag")
  }

  closeFromOutsideClick(event) {
    if (!this.element.contains(event.target)) this.hide()
  }

  get autoSubmitEnabled() {
    return this.hasAutoSubmitValue ? this.autoSubmitValue : true
  }
}
