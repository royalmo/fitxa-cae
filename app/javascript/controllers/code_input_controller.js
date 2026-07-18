import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["digit", "hidden", "submit"]
  static values = { submittingLabel: String }

  connect() {
    this.updateHidden()
  }

  input(event) {
    const input = event.currentTarget
    const index = this.digitTargets.indexOf(input)
    const digits = this.digitsFrom(input.value)

    if (digits.length > 1) {
      this.fillDigits(digits, index, { submitFullCode: this.fullCodeEntry(digits, index) })
      return
    }

    input.value = digits
    this.updateHidden()

    if (digits) {
      this.focusDigit(index + 1)
    }

    if (digits && this.lastDigitIndex(index)) {
      this.submitIfReady()
    }
  }

  keydown(event) {
    const index = this.digitTargets.indexOf(event.currentTarget)

    if (event.key === "Backspace" && event.currentTarget.value === "") {
      this.focusDigit(index - 1)
    } else if (event.key === "ArrowLeft") {
      event.preventDefault()
      this.focusDigit(index - 1)
    } else if (event.key === "ArrowRight") {
      event.preventDefault()
      this.focusDigit(index + 1)
    }
  }

  paste(event) {
    event.preventDefault()

    const input = event.currentTarget
    const index = this.digitTargets.indexOf(input)
    const digits = this.digitsFrom(event.clipboardData.getData("text"))

    this.fillDigits(digits, index, { submitFullCode: this.fullCodeEntry(digits, index) })
  }

  fillDigits(digits, startIndex, { submitFullCode = false } = {}) {
    Array.from(digits).slice(0, this.digitTargets.length - startIndex).forEach((digit, offset) => {
      this.digitTargets[startIndex + offset].value = digit
    })

    this.updateHidden()
    this.focusDigit(Math.min(startIndex + digits.length, this.digitTargets.length - 1))

    if (submitFullCode) {
      this.submitIfReady()
    }
  }

  focusDigit(index) {
    const input = this.digitTargets[index]

    if (input) {
      input.focus()
      input.select()
    }
  }

  updateHidden() {
    this.hiddenTarget.value = this.digitTargets.map((input) => input.value).join("")
  }

  submitIfReady() {
    if (this.submitted || !this.validChecksum(this.hiddenTarget.value)) return

    this.submitted = true
    this.submitTarget.value = this.submittingLabelValue || this.submitTarget.value
    this.submitTarget.setAttribute("aria-busy", "true")

    if (this.element.requestSubmit) {
      this.element.requestSubmit(this.submitTarget)
    } else {
      this.submitTarget.click()
    }
  }

  fullCodeEntry(digits, startIndex) {
    return startIndex === 0 && digits.length >= this.digitTargets.length
  }

  lastDigitIndex(index) {
    return index === this.digitTargets.length - 1
  }

  validChecksum(code) {
    return code.length === this.digitTargets.length &&
      this.weightedChecksumSum(code) % 10 === 0
  }

  weightedChecksumSum(code) {
    return code.split("").reduce((sum, digit, index) => {
      const weight = index % 2 === 0 ? 2 : 1

      return sum + Number(digit) * weight
    }, 0)
  }

  digitsFrom(value) {
    return value.replace(/\D/g, "").slice(0, this.digitTargets.length)
  }
}
