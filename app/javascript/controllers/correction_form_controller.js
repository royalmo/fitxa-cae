import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "date",
    "existingSwipes",
    "existingEmpty",
    "requestedSwipes",
    "comment",
    "pendingNotice",
    "formContent",
    "emptyPrompt",
    "loadingPrompt"
  ]

  static values = {
    dayUrl: String,
    entryLabel: String,
    exitLabel: String,
    removeLabel: String,
    removeSwipeLabel: String,
    existingEmpty: String
  }

  loadDay() {
    const selectedDate = this.dateTarget.value

    if (!selectedDate) {
      this.clearDay()
      return
    }

    this.showLoading()

    const url = new URL(this.dayUrlValue, window.location.origin)
    url.searchParams.set("date", selectedDate)

    fetch(url, { headers: { Accept: "application/json" } })
      .then((response) => response.json())
      .then((data) => {
        if (this.dateTarget.value === selectedDate) {
          this.renderDay(data)
        }
      })
      .catch(() => {
        if (this.dateTarget.value === selectedDate) {
          this.clearDay()
        }
      })
  }

  addRequestedSwipe(event) {
    event.preventDefault()
    this.addRequestedSwipeRow({ kind: "entry", time: "" })
  }

  removeRequestedSwipe(event) {
    event.preventDefault()
    event.currentTarget.closest(".correction-requested-row")?.remove()
  }

  renderDay(data) {
    if (!data.day_allowed) {
      this.clearDay()
      return
    }

    const pendingCorrection = data.pending_correction

    this.formContentTarget.hidden = false
    this.emptyPromptTarget.hidden = true
    this.loadingPromptTarget.hidden = true
    this.renderExistingSwipes(data.swipes || [], pendingCorrection?.invalidated_swipe_ids || [])
    this.renderRequestedSwipes(pendingCorrection?.requested_swipes || [])
    this.commentTarget.value = pendingCorrection?.comment || ""
    this.pendingNoticeTarget.hidden = !pendingCorrection
  }

  showLoading() {
    this.formContentTarget.hidden = true
    this.emptyPromptTarget.hidden = true
    this.loadingPromptTarget.hidden = false
    this.pendingNoticeTarget.hidden = true
  }

  clearDay() {
    this.formContentTarget.hidden = true
    this.emptyPromptTarget.hidden = false
    this.loadingPromptTarget.hidden = true
    this.pendingNoticeTarget.hidden = true
    this.existingEmptyTarget.hidden = true
    this.existingSwipesTarget.replaceChildren()
    this.requestedSwipesTarget.replaceChildren()
    this.commentTarget.value = ""
  }

  renderExistingSwipes(swipes, invalidatedSwipeIds) {
    this.existingSwipesTarget.replaceChildren()
    this.existingEmptyTarget.hidden = swipes.length > 0

    swipes.forEach((swipe) => {
      const label = document.createElement("label")
      label.className = "correction-existing-swipe"
      label.innerHTML = `
        <input type="checkbox" name="invalidated_swipe_ids[]" value="${this.escapeAttribute(swipe.id)}" ${invalidatedSwipeIds.includes(String(swipe.id)) ? "checked" : ""}>
        <span>
          <span class="correction-existing-swipe-kind">${this.escapeHTML(swipe.kind_text)}</span>
          <span>${this.escapeHTML(swipe.time)}</span>
          <small>${this.escapeHTML(this.removeSwipeLabelValue)}</small>
        </span>
      `
      this.existingSwipesTarget.append(label)
    })
  }

  renderRequestedSwipes(requestedSwipes) {
    this.requestedSwipesTarget.replaceChildren()
    requestedSwipes.forEach((requestedSwipe) => this.addRequestedSwipeRow(requestedSwipe))
  }

  addRequestedSwipeRow(requestedSwipe) {
    const row = document.createElement("div")
    row.className = "correction-requested-row"
    row.innerHTML = `
      <select name="requested_swipes[][kind]">
        <option value="entry" ${requestedSwipe.kind === "entry" ? "selected" : ""}>${this.escapeHTML(this.entryLabelValue)}</option>
        <option value="exit" ${requestedSwipe.kind === "exit" ? "selected" : ""}>${this.escapeHTML(this.exitLabelValue)}</option>
      </select>
      <input type="time" name="requested_swipes[][time]" value="${this.escapeAttribute((requestedSwipe.time || "").slice(0, 5))}">
      <button type="button" class="correction-row-remove" data-action="correction-form#removeRequestedSwipe">
        ${this.escapeHTML(this.removeLabelValue)}
      </button>
    `
    this.requestedSwipesTarget.append(row)
  }

  escapeHTML(value) {
    return String(value || "").replace(/[&<>"']/g, (character) => ({
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#39;"
    })[character])
  }

  escapeAttribute(value) {
    return this.escapeHTML(value)
  }
}
