import { Controller } from "@hotwired/stimulus"

const MOBILE_MEDIA_QUERY = "(max-width: 980px)"
const FOCUSABLE_SELECTOR = [
  "a[href]",
  "button:not([disabled])",
  "input:not([disabled])",
  "select:not([disabled])",
  "textarea:not([disabled])",
  "[tabindex]:not([tabindex='-1'])"
].join(", ")

export default class extends Controller {
  static targets = ["button", "sidebar"]
  static classes = ["open"]

  connect() {
    this.mediaQueryList = window.matchMedia(MOBILE_MEDIA_QUERY)
    this.boundSync = this.sync.bind(this)
    this.boundKeydown = this.keydown.bind(this)
    this.boundBeforeCache = () => this.close({ restoreFocus: false })

    this.addMediaListener()
    document.addEventListener("keydown", this.boundKeydown)
    document.addEventListener("turbo:before-cache", this.boundBeforeCache)
    this.sync()
  }

  disconnect() {
    this.removeMediaListener()
    document.removeEventListener("keydown", this.boundKeydown)
    document.removeEventListener("turbo:before-cache", this.boundBeforeCache)
    this.unlockScroll()
  }

  toggle(event) {
    event.preventDefault()

    if (this.isOpen) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    if (!this.mobile) return

    this.previouslyFocusedElement = document.activeElement
    this.element.classList.add(this.openClass)
    document.documentElement.classList.add(this.openClass)
    this.updateExpanded(true)
    this.enableSidebar()
    this.lockScroll()
    this.focusFirstSidebarControl()
  }

  close(eventOrOptions = {}) {
    if (eventOrOptions.currentTarget?.classList?.contains("admin-nav") && !eventOrOptions.target.closest("a")) return

    this.element.classList.remove(this.openClass)
    document.documentElement.classList.remove(this.openClass)
    this.updateExpanded(false)
    this.unlockScroll()

    if (this.mobile) {
      this.disableSidebar()
    } else {
      this.enableSidebar()
    }

    if (this.shouldRestoreFocus(eventOrOptions)) this.restoreFocus()
  }

  keydown(event) {
    if (!this.mobile || !this.isOpen) return

    if (event.key === "Escape") {
      event.preventDefault()
      this.close({ restoreFocus: true })
    } else if (event.key === "Tab") {
      this.trapFocus(event)
    }
  }

  sync() {
    if (this.mobile) {
      this.updateExpanded(this.isOpen)

      if (this.isOpen) {
        this.enableSidebar()
        this.lockScroll()
      } else {
        this.disableSidebar()
        this.unlockScroll()
      }
    } else {
      this.element.classList.remove(this.openClass)
      document.documentElement.classList.remove(this.openClass)
      this.updateExpanded(false)
      this.enableSidebar()
      this.unlockScroll()
    }
  }

  updateExpanded(expanded) {
    if (this.hasButtonTarget) {
      this.buttonTarget.setAttribute("aria-expanded", expanded.toString())
    }
  }

  disableSidebar() {
    if (!this.hasSidebarTarget) return

    this.sidebarTarget.setAttribute("aria-hidden", "true")
    this.sidebarTarget.setAttribute("inert", "")
    this.sidebarTarget.inert = true
  }

  enableSidebar() {
    if (!this.hasSidebarTarget) return

    this.sidebarTarget.removeAttribute("aria-hidden")
    this.sidebarTarget.removeAttribute("inert")
    this.sidebarTarget.inert = false
  }

  lockScroll() {
    document.documentElement.style.overflow = "hidden"
  }

  unlockScroll() {
    document.documentElement.style.overflow = ""
  }

  focusFirstSidebarControl() {
    this.sidebarFocusableElements[0]?.focus()
  }

  restoreFocus() {
    if (this.hasButtonTarget && this.buttonTarget.offsetParent !== null) {
      this.buttonTarget.focus()
    } else {
      this.previouslyFocusedElement?.focus?.()
    }
  }

  trapFocus(event) {
    const focusableElements = this.sidebarFocusableElements
    if (focusableElements.length === 0) return

    const firstElement = focusableElements[0]
    const lastElement = focusableElements[focusableElements.length - 1]

    if (!this.sidebarTarget.contains(document.activeElement)) {
      event.preventDefault()
      firstElement.focus()
    } else if (event.shiftKey && document.activeElement === firstElement) {
      event.preventDefault()
      lastElement.focus()
    } else if (!event.shiftKey && document.activeElement === lastElement) {
      event.preventDefault()
      firstElement.focus()
    }
  }

  shouldRestoreFocus(eventOrOptions) {
    if (eventOrOptions.restoreFocus !== undefined) return eventOrOptions.restoreFocus

    return !eventOrOptions.target?.closest?.(".admin-nav")
  }

  addMediaListener() {
    if (this.mediaQueryList.addEventListener) {
      this.mediaQueryList.addEventListener("change", this.boundSync)
    } else {
      this.mediaQueryList.addListener(this.boundSync)
    }
  }

  removeMediaListener() {
    if (this.mediaQueryList.addEventListener) {
      this.mediaQueryList.removeEventListener("change", this.boundSync)
    } else {
      this.mediaQueryList.removeListener(this.boundSync)
    }
  }

  get mobile() {
    return this.mediaQueryList.matches
  }

  get isOpen() {
    return this.element.classList.contains(this.openClass)
  }

  get sidebarFocusableElements() {
    if (!this.hasSidebarTarget) return []

    return Array.from(this.sidebarTarget.querySelectorAll(FOCUSABLE_SELECTOR)).filter((element) => {
      return element.offsetParent !== null || element === document.activeElement
    })
  }
}
