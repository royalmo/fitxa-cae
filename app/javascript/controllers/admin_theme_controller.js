import { Controller } from "@hotwired/stimulus"

const ADMIN_THEME_COLOR = "#f5f5f5"

export default class extends Controller {
  connect() {
    const root = document.documentElement
    const themeColor = document.querySelector("meta[name='theme-color']")
    const colorScheme = document.querySelector("meta[name='color-scheme']")

    root.dataset.pwa = "admin"
    root.dataset.themePreference = "light"
    root.dataset.theme = "light"
    delete root.dataset.employeeSignedIn
    delete root.dataset.employeeThemePreference

    if (themeColor) themeColor.setAttribute("content", ADMIN_THEME_COLOR)
    if (colorScheme) colorScheme.setAttribute("content", "light")
  }
}
