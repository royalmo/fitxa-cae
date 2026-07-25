import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["year"]

  changeYear(event) {
    event.preventDefault()

    const nextYear = Number.parseInt(this.yearTarget.value, 10) + event.params.delta
    this.yearTarget.value = Math.min(Math.max(nextYear, 2000), 2100)
    this.element.requestSubmit()
  }
}
