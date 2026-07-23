import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "date",
    "existingSwipes",
    "comment",
    "pendingNotice",
    "formContent",
    "emptyPrompt",
    "loadingPrompt",
    "deleteAction",
    "deleteLink"
  ]

  static values = {
    dayUrl: String,
    entriesLabel: String,
    exitsLabel: String,
    requestEntryLabel: String,
    requestExitLabel: String,
    existingSwipesLabel: String,
    entryIcon: String,
    exitIcon: String,
    keepSwipeLabel: String,
    removeSwipeLabel: String,
    removeRequestedSwipeLabel: String,
    keepSwipeIcon: String,
    removeSwipeIcon: String,
    requestedRemoveIcon: String,
    addIcon: String
  }

  connect() {
    this.sortSwipeColumns()
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

  dismissErrors() {
    this.element
      .closest(".correction-form-section")
      ?.querySelectorAll(".error-summary")
      .forEach((summary) => summary.remove())
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
    this.renderSwipeTable(
      data.swipes || [],
      pendingCorrection?.invalidated_swipe_ids || [],
      pendingCorrection?.requested_swipes || []
    )
    this.commentTarget.value = pendingCorrection?.comment || ""
    this.pendingNoticeTarget.hidden = !pendingCorrection
    this.renderDeleteAction(pendingCorrection)
  }

  showLoading() {
    this.formContentTarget.hidden = true
    this.emptyPromptTarget.hidden = true
    this.loadingPromptTarget.hidden = false
    this.pendingNoticeTarget.hidden = true
    this.renderDeleteAction(null)
  }

  clearDay() {
    this.formContentTarget.hidden = true
    this.emptyPromptTarget.hidden = false
    this.loadingPromptTarget.hidden = true
    this.pendingNoticeTarget.hidden = true
    this.renderDeleteAction(null)
    this.existingSwipesTarget.replaceChildren()
    this.commentTarget.value = ""
  }

  renderDeleteAction(pendingCorrection) {
    if (pendingCorrection?.delete_url) {
      this.deleteLinkTarget.href = pendingCorrection.delete_url
      this.deleteActionTarget.hidden = false
    } else {
      this.deleteActionTarget.hidden = true
      this.deleteLinkTarget.href = "#"
    }
  }

  addRequestedSwipe(event) {
    const button = event.currentTarget
    const kind = button.dataset.kind
    const list = button.closest(".correction-swipe-column")?.querySelector(".correction-swipe-column-list")

    if (!list || !["entry", "exit"].includes(kind)) return

    const cell = this.requestedSwipeCell(kind)
    list.append(cell)
    cell.querySelector("input[type='time']")?.focus()
    this.dismissErrors()
  }

  removeRequestedSwipe(event) {
    event.currentTarget.closest(".correction-swipe-request-cell")?.remove()
    this.dismissErrors()
  }

  sortRequestedSwipeColumn(event) {
    if (!event.target.matches(".correction-requested-swipe input[type='time']")) return

    const list = event.target.closest(".correction-swipe-column-list")

    if (list) this.sortSwipeColumnList(list)
  }

  renderSwipeTable(swipes, invalidatedSwipeIds, requestedSwipes) {
    this.existingSwipesTarget.replaceChildren()

    const table = document.createElement("div")
    table.className = "correction-swipe-table"
    table.setAttribute("role", "group")
    table.setAttribute("aria-label", this.existingSwipesLabelValue)
    table.append(this.swipeColumn("entry", swipes, invalidatedSwipeIds, requestedSwipes))
    table.append(this.swipeColumn("exit", swipes, invalidatedSwipeIds, requestedSwipes))
    this.existingSwipesTarget.append(table)
    this.sortSwipeColumns()
  }

  swipeColumn(kind, swipes, invalidatedSwipeIds, requestedSwipes) {
    const column = document.createElement("div")
    const header = document.createElement("div")
    const list = document.createElement("div")
    const columnSwipes = swipes.filter((swipe) => swipe.kind === kind)

    column.className = "correction-swipe-column"
    column.dataset.kind = kind
    header.className = "correction-swipe-column-header"
    header.textContent = kind === "entry" ? this.entriesLabelValue : this.exitsLabelValue
    list.className = "correction-swipe-column-list"

    if (columnSwipes.length) {
      columnSwipes.forEach((swipe) => list.append(this.swipeCell(swipe, invalidatedSwipeIds)))
    }

    requestedSwipes
      .filter((swipe) => swipe.kind === kind)
      .forEach((swipe) => list.append(this.requestedSwipeCell(kind, swipe)))

    column.append(header, list, this.requestedSwipeAddButton(kind))

    return column
  }

  swipeCell(swipe, invalidatedSwipeIds) {
    const cell = document.createElement("div")
    cell.className = "correction-swipe-table-cell"

    const label = document.createElement("label")
    label.className = "correction-existing-swipe"
    label.dataset.kind = swipe.kind
    label.innerHTML = `
        <input type="checkbox" name="invalidated_swipe_ids[]" value="${this.escapeAttribute(swipe.id)}" class="sr-only" ${invalidatedSwipeIds.includes(String(swipe.id)) ? "checked" : ""}>
        <span class="correction-existing-swipe-main">
          ${this.swipeKindIcon(swipe.kind)}
          <span class="correction-existing-swipe-copy">
            <strong>${this.escapeHTML(swipe.time)}</strong>
          </span>
        </span>
        <span class="correction-existing-swipe-state">
          <span class="correction-existing-swipe-keep" title="${this.escapeAttribute(this.removeSwipeLabelValue)}" aria-label="${this.escapeAttribute(this.removeSwipeLabelValue)}">
            ${this.removeSwipeIconValue}
          </span>
          <span class="correction-existing-swipe-remove" title="${this.escapeAttribute(this.keepSwipeLabelValue)}" aria-label="${this.escapeAttribute(this.keepSwipeLabelValue)}">
            ${this.keepSwipeIconValue}
          </span>
        </span>
      `
    cell.append(label)
    return cell
  }

  requestedSwipeCell(kind, requestedSwipe = {}) {
    const cell = document.createElement("div")
    const wrapper = document.createElement("div")
    const requestLabel = kind === "entry" ? this.requestEntryLabelValue : this.requestExitLabelValue

    cell.className = "correction-swipe-table-cell correction-swipe-request-cell"
    wrapper.className = "correction-existing-swipe correction-requested-swipe"
    wrapper.dataset.kind = kind
    wrapper.innerHTML = `
      <span class="correction-existing-swipe-main">
        ${this.swipeKindIcon(kind)}
        <span class="correction-existing-swipe-copy">
          <input type="hidden" name="requested_swipes[][kind]" value="${this.escapeAttribute(kind)}">
          <input type="time" name="requested_swipes[][time]" value="${this.escapeAttribute((requestedSwipe?.time || "").slice(0, 5))}" aria-label="${this.escapeAttribute(requestLabel)}">
        </span>
      </span>
      <button type="button" class="correction-existing-swipe-state correction-requested-swipe-remove" title="${this.escapeAttribute(this.removeRequestedSwipeLabelValue)}" aria-label="${this.escapeAttribute(this.removeRequestedSwipeLabelValue)}" data-action="correction-form#removeRequestedSwipe">
        ${this.requestedRemoveIconValue}
      </button>
    `
    cell.append(wrapper)
    return cell
  }

  requestedSwipeAddButton(kind) {
    const button = document.createElement("button")
    const requestLabel = kind === "entry" ? this.requestEntryLabelValue : this.requestExitLabelValue

    button.type = "button"
    button.className = "correction-requested-swipe-add"
    button.dataset.action = "correction-form#addRequestedSwipe"
    button.dataset.kind = kind
    button.innerHTML = `
      ${this.addIconValue}
      <span>${this.escapeHTML(requestLabel)}</span>
    `

    return button
  }

  sortSwipeColumnList(list) {
    Array.from(list.children)
      .filter((child) => child.classList.contains("correction-swipe-table-cell"))
      .map((cell, index) => ({
        cell,
        index,
        minutes: this.swipeCellMinutes(cell)
      }))
      .sort((left, right) => (left.minutes - right.minutes) || (left.index - right.index))
      .forEach(({ cell }) => list.append(cell))
  }

  sortSwipeColumns() {
    this.existingSwipesTarget
      .querySelectorAll(".correction-swipe-column-list")
      .forEach((list) => this.sortSwipeColumnList(list))
  }

  swipeCellMinutes(cell) {
    const value =
      cell.querySelector(".correction-requested-swipe input[type='time']")?.value ||
      cell.querySelector(".correction-existing-swipe-copy strong")?.textContent ||
      ""
    const match = value.trim().match(/^(\d{1,2}):(\d{2})/)

    if (!match) return Number.POSITIVE_INFINITY

    return (Number(match[1]) * 60) + Number(match[2])
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

  swipeKindIcon(kind) {
    return kind === "exit" ? this.exitIconValue : this.entryIconValue
  }
}
