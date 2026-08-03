import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "date",
    "employeeId",
    "existingSwipes",
    "comment",
    "pendingNotice",
    "formContent",
    "emptyPrompt",
    "loadingPrompt",
    "existingCorrectionPrompt",
    "submitActions",
    "reviewConfirmationBody",
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
    addIcon: String,
    updateUrl: Boolean,
    invalidatedSwipeName: String,
    requestedKindName: String,
    requestedTimeName: String,
    initialInvalidatedSwipeIds: String,
    initialRequestedSwipes: String,
    modifiedReviewMessage: String,
    unmodifiedReviewMessage: String,
    reviewConfirmationModalId: String
  }

  connect() {
    this.sortSwipeColumns()
  }

  loadDay(event) {
    event?.preventDefault()
    const selectedDate = this.dateTarget.value
    const selectedEmployeeId = this.hasEmployeeIdTarget ? this.employeeIdTarget.value : ""

    this.updateBrowserUrl(selectedEmployeeId, selectedDate)

    if (!selectedDate || (this.hasEmployeeIdTarget && !selectedEmployeeId)) {
      this.clearDay()
      return
    }

    this.showLoading()

    const url = new URL(this.dayUrlValue, window.location.origin)
    url.searchParams.set("date", selectedDate)
    if (selectedEmployeeId) url.searchParams.set("employee_id", selectedEmployeeId)

    fetch(url, { headers: { Accept: "application/json" } })
      .then((response) => response.json())
      .then((data) => {
        const sameEmployee = !this.hasEmployeeIdTarget || this.employeeIdTarget.value === selectedEmployeeId

        if (this.dateTarget.value === selectedDate && sameEmployee) {
          this.renderDay(data)
        }
      })
      .catch(() => {
        const sameEmployee = !this.hasEmployeeIdTarget || this.employeeIdTarget.value === selectedEmployeeId

        if (this.dateTarget.value === selectedDate && sameEmployee) {
          this.clearDay()
        }
      })
  }

  dismissErrors() {
    const container = this.element.closest(".correction-form-section") || this.element.closest("form")

    container
      ?.querySelectorAll(".error-summary")
      .forEach((summary) => summary.remove())
  }

  prepareReviewConfirmation() {
    if (!this.hasReviewConfirmationBodyTarget) return

    this.reviewConfirmationBodyTarget.textContent = this.reviewConfirmationMessage()
  }

  confirmReviewSubmission(event) {
    if (!this.hasReviewConfirmationBodyTarget) return
    if (event.submitter?.dataset.correctionFormConfirmed === "true") return

    event.preventDefault()
    this.prepareReviewConfirmation()
    this.showReviewConfirmationModal()
  }

  renderDay(data) {
    if (!data.day_allowed) {
      this.clearDay()
      return
    }

    const pendingCorrection = data.pending_correction
    const existingCorrectionHtml = data.existing_correction_html

    if (existingCorrectionHtml && data.existing_correction_blocks_form) {
      this.showBlockingExistingCorrection(existingCorrectionHtml)
      return
    }

    this.showFormContent()
    if (this.hasEmptyPromptTarget) this.emptyPromptTarget.hidden = true
    if (this.hasLoadingPromptTarget) this.loadingPromptTarget.hidden = true
    if (existingCorrectionHtml) {
      this.renderExistingCorrection(existingCorrectionHtml)
    } else {
      this.hideExistingCorrection()
    }
    this.renderSwipeTable(
      data.swipes || [],
      pendingCorrection?.invalidated_swipe_ids || [],
      pendingCorrection?.requested_swipes || []
    )
    if (this.hasCommentTarget) this.commentTarget.value = pendingCorrection?.comment || ""
    if (this.hasPendingNoticeTarget) this.pendingNoticeTarget.hidden = !pendingCorrection
    this.renderDeleteAction(pendingCorrection)
  }

  showLoading() {
    this.hideFormContent()
    if (this.hasEmptyPromptTarget) this.emptyPromptTarget.hidden = true
    if (this.hasLoadingPromptTarget) this.loadingPromptTarget.hidden = false
    this.hideExistingCorrection()
    if (this.hasPendingNoticeTarget) this.pendingNoticeTarget.hidden = true
    this.renderDeleteAction(null)
  }

  clearDay() {
    this.hideFormContent()
    if (this.hasEmptyPromptTarget) this.emptyPromptTarget.hidden = false
    if (this.hasLoadingPromptTarget) this.loadingPromptTarget.hidden = true
    this.hideExistingCorrection()
    if (this.hasPendingNoticeTarget) this.pendingNoticeTarget.hidden = true
    this.renderDeleteAction(null)
    if (this.hasExistingSwipesTarget) this.existingSwipesTarget.replaceChildren()
    if (this.hasCommentTarget) this.commentTarget.value = ""
  }

  renderDeleteAction(pendingCorrection) {
    if (!this.hasDeleteActionTarget || !this.hasDeleteLinkTarget) return

    if (pendingCorrection?.delete_url) {
      this.deleteLinkTarget.href = pendingCorrection.delete_url
      this.deleteActionTarget.hidden = false
    } else {
      this.deleteActionTarget.hidden = true
      this.deleteLinkTarget.href = "#"
    }
  }

  updateBrowserUrl(employeeId, day) {
    if (!this.updateUrlValue || !window.history?.replaceState) return

    const url = new URL(window.location.href)

    if (employeeId) {
      url.searchParams.set("employee_id", employeeId)
    } else {
      url.searchParams.delete("employee_id")
    }

    if (day) {
      url.searchParams.set("day", day)
    } else {
      url.searchParams.delete("day")
    }

    url.searchParams.delete("date")

    const currentUrl = `${window.location.pathname}${window.location.search}${window.location.hash}`
    const nextUrl = `${url.pathname}${url.search}${url.hash}`

    if (nextUrl !== currentUrl) {
      window.history.replaceState(window.history.state, "", nextUrl)
    }
  }

  showBlockingExistingCorrection(html) {
    this.hideFormContent()
    if (this.hasEmptyPromptTarget) this.emptyPromptTarget.hidden = true
    if (this.hasLoadingPromptTarget) this.loadingPromptTarget.hidden = true
    if (this.hasPendingNoticeTarget) this.pendingNoticeTarget.hidden = true
    if (this.hasExistingSwipesTarget) this.existingSwipesTarget.replaceChildren()
    if (this.hasCommentTarget) this.commentTarget.value = ""
    this.renderDeleteAction(null)

    this.renderExistingCorrection(html)
  }

  renderExistingCorrection(html) {
    if (this.hasExistingCorrectionPromptTarget) {
      this.existingCorrectionPromptTarget.innerHTML = html
      this.existingCorrectionPromptTarget.hidden = false
    }
  }

  hideExistingCorrection() {
    if (this.hasExistingCorrectionPromptTarget) {
      this.existingCorrectionPromptTarget.hidden = true
      this.existingCorrectionPromptTarget.replaceChildren()
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
    if (!this.hasExistingSwipesTarget) return

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
        <input type="checkbox" name="${this.escapeAttribute(this.invalidatedSwipeName)}" value="${this.escapeAttribute(swipe.id)}" class="visually-hidden sr-only" ${invalidatedSwipeIds.includes(String(swipe.id)) ? "checked" : ""}>
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
    const requestedTime = requestedSwipe?.time || requestedSwipe?.hour || ""
    wrapper.innerHTML = `
      <span class="correction-existing-swipe-main">
        ${this.swipeKindIcon(kind)}
        <span class="correction-existing-swipe-copy">
          <input type="hidden" name="${this.escapeAttribute(this.requestedKindName)}" value="${this.escapeAttribute(kind)}">
          <input type="time" name="${this.escapeAttribute(this.requestedTimeName)}" value="${this.escapeAttribute(requestedTime.slice(0, 5))}" aria-label="${this.escapeAttribute(requestLabel)}">
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
    if (!this.hasExistingSwipesTarget) return

    this.existingSwipesTarget
      .querySelectorAll(".correction-swipe-column-list")
      .forEach((list) => this.sortSwipeColumnList(list))
  }

  reviewConfirmationMessage() {
    if (this.swipeDetailsChanged()) return this.modifiedReviewMessageValue

    return this.unmodifiedReviewMessageValue
  }

  swipeDetailsChanged() {
    return this.serializedCurrentInvalidatedSwipeIds() !== this.serializedInitialInvalidatedSwipeIds() ||
      this.serializedCurrentRequestedSwipes() !== this.serializedInitialRequestedSwipes()
  }

  serializedInitialInvalidatedSwipeIds() {
    return JSON.stringify(this.normalizedSwipeIds(this.parsedJSONValue(this.initialInvalidatedSwipeIdsValue)))
  }

  serializedCurrentInvalidatedSwipeIds() {
    const checkedBoxes = this.element.querySelectorAll(`input[name="${this.invalidatedSwipeNameValue}"]:checked`)
    const ids = Array.from(checkedBoxes).map((checkbox) => checkbox.value)

    return JSON.stringify(this.normalizedSwipeIds(ids))
  }

  normalizedSwipeIds(ids) {
    return Array.from(ids || []).map((id) => String(id)).filter(Boolean).sort()
  }

  serializedInitialRequestedSwipes() {
    return JSON.stringify(this.normalizedRequestedSwipes(this.parsedJSONValue(this.initialRequestedSwipesValue)))
  }

  serializedCurrentRequestedSwipes() {
    const requestedSwipes = Array.from(this.element.querySelectorAll(".correction-requested-swipe")).map((wrapper) => {
      const kind = wrapper.querySelector(`input[name="${this.requestedKindNameValue}"]`)?.value || ""
      const hour = wrapper.querySelector(`input[name="${this.requestedTimeNameValue}"]`)?.value || ""

      return { kind, hour }
    })

    return JSON.stringify(this.normalizedRequestedSwipes(requestedSwipes))
  }

  normalizedRequestedSwipes(requestedSwipes) {
    return Array.from(requestedSwipes || [])
      .map((requestedSwipe) => ({
        kind: String(requestedSwipe.kind || requestedSwipe["kind"] || ""),
        hour: String(requestedSwipe.hour || requestedSwipe["hour"] || "").slice(0, 5)
      }))
      .filter((requestedSwipe) => requestedSwipe.kind || requestedSwipe.hour)
      .sort((left, right) => `${left.hour}|${left.kind}`.localeCompare(`${right.hour}|${right.kind}`))
  }

  parsedJSONValue(value) {
    try {
      return JSON.parse(value || "[]")
    } catch {
      return []
    }
  }

  showReviewConfirmationModal() {
    if (!this.hasReviewConfirmationModalIdValue) return

    const modalElement = document.getElementById(this.reviewConfirmationModalIdValue)
    const Modal = window.bootstrap?.Modal

    if (modalElement && Modal) Modal.getOrCreateInstance(modalElement).show()
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

  showFormContent() {
    if (this.hasFormContentTarget) this.formContentTarget.hidden = false
    if (this.hasSubmitActionsTarget) this.submitActionsTarget.hidden = false
  }

  hideFormContent() {
    if (this.hasFormContentTarget) this.formContentTarget.hidden = true
    if (this.hasSubmitActionsTarget) this.submitActionsTarget.hidden = true
  }

  get invalidatedSwipeName() {
    return this.hasInvalidatedSwipeNameValue ? this.invalidatedSwipeNameValue : "invalidated_swipe_ids[]"
  }

  get requestedKindName() {
    return this.hasRequestedKindNameValue ? this.requestedKindNameValue : "requested_swipes[][kind]"
  }

  get requestedTimeName() {
    return this.hasRequestedTimeNameValue ? this.requestedTimeNameValue : "requested_swipes[][time]"
  }
}
