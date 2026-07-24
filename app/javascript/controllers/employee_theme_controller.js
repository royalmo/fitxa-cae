import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "fitxa-cae.employee.theme"
const LIGHT_THEME_COLOR = "#e30613"
const DARK_THEME_COLOR = "#121214"
const PREFERENCES = ["light", "dark", "system"]

export default class extends Controller {
  static values = {
    preference: String,
    signedIn: Boolean
  }

  connect() {
    this.previewPreference = null
    this.systemThemeQuery = window.matchMedia ? window.matchMedia("(prefers-color-scheme: dark)") : null
    this.systemThemeChanged = this.systemThemeChanged.bind(this)
    this.resetBeforeCache = this.resetBeforeCache.bind(this)
    this.addSystemThemeListener()
    document.addEventListener("turbo:before-cache", this.resetBeforeCache)
    this.apply()
  }

  disconnect() {
    this.removeSystemThemeListener()
    document.removeEventListener("turbo:before-cache", this.resetBeforeCache)
  }

  choose(event) {
    if (!this.validPreference(event.target.value)) return

    this.previewPreference = event.target.value
    this.apply({ store: false })
  }

  apply({ store = true } = {}) {
    const preference = this.currentPreference()

    if (store) this.storePreference(preference)
    this.applyPreference(preference)
  }

  currentPreference() {
    const preference = this.previewPreference || this.preferenceValue

    if (this.signedInValue) return this.normalizedPreference(preference)

    return this.storedPreference() || this.normalizedPreference(preference)
  }

  normalizedPreference(preference) {
    return this.validPreference(preference) ? preference : "system"
  }

  storedPreference() {
    try {
      const preference = localStorage.getItem(STORAGE_KEY)

      return this.validPreference(preference) ? preference : null
    } catch (_error) {
      return null
    }
  }

  storePreference(preference) {
    if (!this.signedInValue) return

    try {
      localStorage.setItem(STORAGE_KEY, preference)
    } catch (_error) {}
  }

  applyPreference(preference) {
    const theme = this.resolvedTheme(preference)
    const themeColor = document.querySelector("meta[name='theme-color']")

    document.documentElement.dataset.employeeThemePreference = preference
    document.documentElement.dataset.themePreference = preference
    document.documentElement.dataset.theme = theme

    if (themeColor) {
      themeColor.setAttribute("content", theme === "dark" ? DARK_THEME_COLOR : LIGHT_THEME_COLOR)
    }
  }

  resolvedTheme(preference) {
    if (preference === "dark") return "dark"
    if (preference === "light") return "light"

    return this.systemThemeQuery&.matches ? "dark" : "light"
  }

  validPreference(preference) {
    return PREFERENCES.includes(preference)
  }

  systemThemeChanged() {
    if (this.currentPreference() === "system") this.apply()
  }

  resetBeforeCache() {
    this.previewPreference = null

    const preference = this.signedInValue ? this.normalizedPreference(this.preferenceValue) : this.currentPreference()
    this.applyPreference(preference)
  }

  addSystemThemeListener() {
    if (!this.systemThemeQuery) return

    if (this.systemThemeQuery.addEventListener) {
      this.systemThemeQuery.addEventListener("change", this.systemThemeChanged)
    } else {
      this.systemThemeQuery.addListener(this.systemThemeChanged)
    }
  }

  removeSystemThemeListener() {
    if (!this.systemThemeQuery) return

    if (this.systemThemeQuery.addEventListener) {
      this.systemThemeQuery.removeEventListener("change", this.systemThemeChanged)
    } else {
      this.systemThemeQuery.removeListener(this.systemThemeChanged)
    }
  }
}
