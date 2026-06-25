import "@hotwired/turbo-rails"
import "controllers"

if ("serviceWorker" in navigator && document.documentElement.dataset.pwa === "employee") {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker.js")
  })
}
