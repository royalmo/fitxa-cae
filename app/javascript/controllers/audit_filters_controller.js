import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["author", "authorInput"]

  clearAuthor() {
    if (this.hasAuthorTarget) this.authorTarget.value = ""
    if (this.hasAuthorInputTarget) this.authorInputTarget.value = ""
  }
}
