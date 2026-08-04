import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["field", "input", "results", "selections", "selectionTemplate"]
  static values = {
    url: String,
    removeLabel: String
  }

  connect() {
    this.abortController = null
    this.searchTimeout = null
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
    event.preventDefault()
    this.choose(event.params.id, event.params.label, event.params.style)
  }

  remove(event) {
    event.preventDefault()
    event.currentTarget.closest("[data-tag-multi-search-id]")?.remove()
    this.dispatchChange()
    this.inputTarget.focus()
    if (this.inputTarget.value.trim() !== "") this.fetchResults()
  }

  selectFirstResult(event) {
    if (this.inputTarget.value.trim() === "") return

    event.preventDefault()
    clearTimeout(this.searchTimeout)

    if (this.chooseFirstAvailableResult()) return

    this.fetchResults({ selectFirst: true })
  }

  chooseFirstAvailableResult() {
    const result = this.resultsTarget.querySelector(".admin-tag-search-result:not([disabled])")
    if (!result) return false

    this.choose(
      result.dataset.tagMultiSearchIdParam,
      result.dataset.tagMultiSearchLabelParam,
      result.dataset.tagMultiSearchStyleParam
    )
    return true
  }

  choose(id, label, style) {
    if (!id || this.selectedIds.includes(id.toString())) {
      this.clearSearch()
      return
    }

    const selection = this.selectionTemplateTarget.content.firstElementChild.cloneNode(true)
    const input = selection.querySelector("[data-tag-multi-search-selected-input]")
    const labelElement = selection.querySelector("[data-tag-multi-search-label]")
    const removeButton = selection.querySelector(".admin-tag-multi-search-remove")

    selection.dataset.tagMultiSearchId = id
    selection.setAttribute("style", style || "")
    input.value = id
    labelElement.textContent = label
    removeButton.title = this.removeLabel(label)
    removeButton.setAttribute("aria-label", this.removeLabel(label))

    this.selectionsTarget.append(selection)
    this.dispatchChange()
    this.clearSearch()
  }

  fetchResults({ selectFirst = false } = {}) {
    this.abortController?.abort()
    this.abortController = new AbortController()

    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("q", this.inputTarget.value)
    url.searchParams.set("multiple", "true")
    if (this.selectedIds.length > 0) {
      url.searchParams.set("selected_tag_ids", this.selectedIds.join(","))
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

  clearSearch() {
    this.inputTarget.value = ""
    this.hide()
    this.inputTarget.focus()
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

  dispatchChange() {
    this.element.dispatchEvent(new Event("change", { bubbles: true }))
  }

  removeLabel(label) {
    if (!this.hasRemoveLabelValue) return label

    return this.removeLabelValue.replace("%{name}", label)
  }

  get selectedIds() {
    return Array.from(this.selectionsTarget.querySelectorAll("[data-tag-multi-search-id]"))
      .map((selection) => selection.dataset.tagMultiSearchId)
      .filter(Boolean)
  }
}
