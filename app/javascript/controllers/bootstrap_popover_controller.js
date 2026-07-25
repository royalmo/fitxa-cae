import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["trigger"]

  connect() {
    this.popovers = []
    this.closeFromOutsideClick = this.closeFromOutsideClick.bind(this)
    this.dispose = this.dispose.bind(this)

    this.initialize()
    document.addEventListener("click", this.closeFromOutsideClick)
    document.addEventListener("turbo:before-cache", this.dispose)
  }

  disconnect() {
    document.removeEventListener("click", this.closeFromOutsideClick)
    document.removeEventListener("turbo:before-cache", this.dispose)
    this.dispose()
  }

  initialize() {
    if (!window.bootstrap?.Popover) return

    this.popovers = this.triggerTargets.map((trigger) => {
      const popover = new window.bootstrap.Popover(trigger, {
        container: "body",
        html: true,
        sanitize: false,
        trigger: "click"
      })
      const showHandler = () => this.hideOthers(trigger)

      trigger.addEventListener("show.bs.popover", showHandler)
      return { trigger, popover, showHandler }
    })
  }

  hideOthers(activeTrigger) {
    this.popovers.forEach(({ trigger, popover }) => {
      if (trigger !== activeTrigger) popover.hide()
    })
  }

  closeFromOutsideClick(event) {
    if (this.element.contains(event.target) || event.target.closest(".popover")) return

    this.hideAll()
  }

  hideAll() {
    this.popovers.forEach(({ popover }) => popover.hide())
  }

  dispose() {
    this.popovers.forEach(({ trigger, popover, showHandler }) => {
      trigger.removeEventListener("show.bs.popover", showHandler)
      popover.dispose()
    })
    this.popovers = []
  }
}
