import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["installedField"]

  connect() {
    const installed =
      window.matchMedia("(display-mode: standalone)").matches ||
      window.navigator.standalone === true

    this.installedFieldTargets.forEach((field) => {
      field.value = installed ? "1" : "0"
    })
  }
}
