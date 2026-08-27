import { Controller } from "@hotwired/stimulus"

const DEFAULT_MAX_VIEWPORT_RATIO = 0.9

export default class extends Controller {
  static values = {
    maxViewportRatio: Number
  }

  connect() {
    this.connected = true
    this.frame = null
    this.pendingImages = []
    this.scheduleFit = this.scheduleFit.bind(this)
    this.fit = this.fit.bind(this)
    this.brands = Array.from(this.element.querySelectorAll(".auth-header .brand-mark"))

    window.addEventListener("resize", this.scheduleFit)

    if (document.fonts) {
      document.fonts.ready.then(this.scheduleFit)
    }

    this.brands.forEach((brand) => {
      brand.querySelectorAll("img").forEach((image) => {
        if (image.complete) return

        image.addEventListener("load", this.scheduleFit, { once: true })
        this.pendingImages.push(image)
      })
    })

    this.scheduleFit()
  }

  disconnect() {
    this.connected = false
    window.removeEventListener("resize", this.scheduleFit)
    this.pendingImages.forEach((image) => image.removeEventListener("load", this.scheduleFit))

    if (this.frame) {
      cancelAnimationFrame(this.frame)
    }
  }

  scheduleFit() {
    if (!this.connected) return

    if (this.frame) {
      cancelAnimationFrame(this.frame)
    }

    this.frame = requestAnimationFrame(this.fit)
  }

  fit() {
    this.frame = null
    this.brands.forEach((brand) => this.fitBrand(brand))
  }

  fitBrand(brand) {
    this.clearCurrentSizes(brand)

    const naturalWidth = brand.scrollWidth
    const availableWidth = this.availableWidth(brand)

    if (!naturalWidth || !availableWidth || naturalWidth <= availableWidth) return

    const scale = Math.max(0, Math.min(1, availableWidth / naturalWidth))

    this.setScaledSize(brand, "--auth-brand-current-text-size", ".brand-fitxa", "fontSize", scale)
    this.setScaledSize(brand, "--auth-brand-current-logo-height", ".brand-logo", "height", scale)
  }

  clearCurrentSizes(brand) {
    brand.style.removeProperty("--auth-brand-current-text-size")
    brand.style.removeProperty("--auth-brand-current-logo-height")
  }

  availableWidth(brand) {
    const parentWidth = brand.parentElement?.clientWidth || brand.clientWidth
    const viewportWidth = window.innerWidth * this.maxViewportRatio

    return Math.floor(Math.min(parentWidth || viewportWidth, viewportWidth))
  }

  setScaledSize(brand, property, selector, styleName, scale) {
    const target = brand.querySelector(selector)
    if (!target) return

    const size = parseFloat(getComputedStyle(target)[styleName])
    if (!Number.isFinite(size)) return

    brand.style.setProperty(property, `${size * scale}px`)
  }

  get maxViewportRatio() {
    return this.hasMaxViewportRatioValue ? this.maxViewportRatioValue : DEFAULT_MAX_VIEWPORT_RATIO
  }
}
