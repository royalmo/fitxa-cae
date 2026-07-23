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
    keepSwipeIcon: String,
    removeSwipeIcon: String
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

  renderSwipeTable(swipes, invalidatedSwipeIds, requestedSwipes) {
    this.existingSwipesTarget.replaceChildren()

    const table = document.createElement("div")
    table.className = "correction-swipe-table"
    table.setAttribute("role", "table")
    table.setAttribute("aria-label", this.existingSwipesLabelValue)
    table.innerHTML = `
      <div class="correction-swipe-table-header" role="row">
        <span role="columnheader">${this.escapeHTML(this.entriesLabelValue)}</span>
        <span role="columnheader">${this.escapeHTML(this.exitsLabelValue)}</span>
      </div>
    `

    this.swipeRows(swipes).forEach((swipeRow) => {
      const row = document.createElement("div")
      row.className = "correction-swipe-table-row"
      row.setAttribute("role", "row")
      row.append(this.swipeCell(swipeRow.entry, invalidatedSwipeIds))
      row.append(this.swipeCell(swipeRow.exit, invalidatedSwipeIds))
      table.append(row)
    })

    table.append(this.requestedSwipeRow(requestedSwipes))
    this.existingSwipesTarget.append(table)
  }

  swipeCell(swipe, invalidatedSwipeIds) {
    const cell = document.createElement("div")
    cell.className = "correction-swipe-table-cell"
    cell.setAttribute("role", "cell")

    if (!swipe) {
      cell.innerHTML = '<span class="correction-swipe-empty-slot" aria-hidden="true">—</span>'
      return cell
    }

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

  swipeRows(swipes) {
    const rows = []
    let currentRow = null

    swipes.forEach((swipe) => {
      if (swipe.kind === "entry") {
        currentRow = { entry: swipe, exit: null }
        rows.push(currentRow)
      } else if (currentRow && !currentRow.exit) {
        currentRow.exit = swipe
      } else {
        currentRow = { entry: null, exit: swipe }
        rows.push(currentRow)
      }
    })

    return rows
  }

  requestedSwipeRow(requestedSwipes) {
    const row = document.createElement("div")
    row.className = "correction-swipe-table-row correction-swipe-request-row"
    row.setAttribute("role", "row")
    row.append(this.requestedSwipeCell("entry", requestedSwipes))
    row.append(this.requestedSwipeCell("exit", requestedSwipes))

    return row
  }

  requestedSwipeCell(kind, requestedSwipes) {
    const cell = document.createElement("div")
    const label = document.createElement("label")
    const requestLabel = kind === "entry" ? this.requestEntryLabelValue : this.requestExitLabelValue
    const requestedSwipe = requestedSwipes.find((swipe) => swipe.kind === kind)

    cell.className = "correction-swipe-table-cell"
    cell.setAttribute("role", "cell")
    label.className = "correction-requested-swipe"
    label.dataset.kind = kind
    label.innerHTML = `
      ${this.requestedSwipeIcon(kind)}
      <input type="hidden" name="requested_swipes[][kind]" value="${this.escapeAttribute(kind)}">
      <input type="time" name="requested_swipes[][time]" value="${this.escapeAttribute((requestedSwipe?.time || "").slice(0, 5))}" aria-label="${this.escapeAttribute(requestLabel)}">
    `
    cell.append(label)
    return cell
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

  requestedSwipeIcon(kind) {
    return this.swipeKindIcon(kind).replace("correction-existing-swipe-kind-icon", "correction-requested-swipe-icon")
  }
}
