import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["personPanel", "categoryPanel", "modeInput", "categorySelect"]

  connect() {
    this.sync()
  }

  modeChanged(event) {
    this.sync()
    event.currentTarget.form?.requestSubmit()
  }

  categoryChanged(event) {
    event.currentTarget.form?.requestSubmit()
  }

  sync() {
    const categoryMode = this.selectedMode === "category"
    this.personPanelTarget.hidden = categoryMode
    this.categoryPanelTarget.hidden = !categoryMode
    this.setPanelDisabled(this.personPanelTarget, categoryMode)
    this.setPanelDisabled(this.categoryPanelTarget, !categoryMode)
  }

  setPanelDisabled(panel, disabled) {
    panel.querySelectorAll("input, select, textarea, button").forEach((field) => {
      field.disabled = disabled
    })
  }

  get selectedMode() {
    return this.modeInputTargets.find((input) => input.checked)?.value || "person"
  }
}
