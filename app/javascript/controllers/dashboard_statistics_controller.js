import { Controller } from "@hotwired/stimulus"

let chartLoader
let chartRegistered = false

export default class extends Controller {
  static targets = ["panel"]
  static values = {
    url: String
  }

  connect() {
    this.charts = new Map()
    this.loadActivePanel = this.loadActivePanel.bind(this)
    this.destroyCharts = this.destroyCharts.bind(this)
    this.tabButtons = Array.from(this.element.querySelectorAll("[data-bs-toggle='tab']"))

    this.tabButtons.forEach((button) => button.addEventListener("shown.bs.tab", this.loadActivePanel))
    document.addEventListener("turbo:before-cache", this.destroyCharts)
    this.loadActivePanel()
  }

  disconnect() {
    this.tabButtons?.forEach((button) => button.removeEventListener("shown.bs.tab", this.loadActivePanel))
    document.removeEventListener("turbo:before-cache", this.destroyCharts)
    this.destroyCharts()
  }

  changePeriod(event) {
    const panel = event.target.closest("[data-dashboard-statistics-target~='panel']")
    if (!panel) return

    this.loadPanel(panel, { force: true })
  }

  loadActivePanel() {
    const panel = this.panelTargets.find((target) => target.classList.contains("active"))
    if (panel) this.loadPanel(panel)
  }

  async loadPanel(panel, { force = false } = {}) {
    const metric = panel.dataset.dashboardStatisticsMetric
    if (!metric) return

    const period = this.selectedPeriod(panel)
    if (!force && panel.dataset.dashboardStatisticsLoadedPeriod === period) return

    const requestId = `${Date.now()}-${this.nextRequestId()}`
    panel.dataset.dashboardStatisticsRequestId = requestId
    this.showLoading(panel)

    try {
      const data = await this.chartData(panel, metric, period, force)
      if (panel.dataset.dashboardStatisticsRequestId !== requestId) return

      await this.renderChart(panel, data)
      panel.dataset.dashboardStatisticsLoadedPeriod = period
    } catch (_error) {
      if (panel.dataset.dashboardStatisticsRequestId !== requestId) return

      this.showEmpty(panel, panel.dataset.dashboardStatisticsErrorMessage)
    } finally {
      if (panel.dataset.dashboardStatisticsRequestId === requestId) this.hideLoading(panel)
    }
  }

  async chartData(panel, metric, period, force) {
    if (!force && panel.dataset.dashboardStatisticsPreloaded) {
      const data = JSON.parse(panel.dataset.dashboardStatisticsPreloaded)
      delete panel.dataset.dashboardStatisticsPreloaded
      return data
    }

    const url = new URL(this.urlValue, window.location.href)
    url.searchParams.set("metric", metric)
    url.searchParams.set("period", period)

    const response = await fetch(url, {
      headers: {
        Accept: "application/json"
      }
    })

    if (!response.ok) throw new Error(`Statistics request failed: ${response.status}`)

    return response.json()
  }

  async renderChart(panel, data) {
    const canvas = this.canvas(panel)
    const values = Array.isArray(data.values) ? data.values : []

    this.destroyChart(panel)

    if (!canvas || values.length === 0) {
      this.showEmpty(panel, panel.dataset.dashboardStatisticsEmptyMessage)
      return
    }

    this.hideEmpty(panel)
    canvas.hidden = false

    const Chart = await this.chartClass()
    const color = data.color || "#0d6efd"
    const chart = new Chart(canvas, {
      type: "line",
      data: {
        labels: data.labels || [],
        datasets: [
          {
            label: data.label,
            data: values,
            borderColor: color,
            backgroundColor: this.transparentColor(color),
            borderWidth: 2,
            fill: true,
            pointRadius: values.length > 90 ? 0 : 3,
            pointHoverRadius: 5,
            tension: 0.25
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          intersect: false,
          mode: "index"
        },
        plugins: {
          legend: {
            display: false
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            ticks: {
              precision: 0
            }
          }
        }
      }
    })

    this.charts.set(panel.id, chart)
  }

  async chartClass() {
    chartLoader ||= import("chart.js").then((module) => {
      if (!chartRegistered) {
        module.Chart.register(...module.registerables)
        chartRegistered = true
      }

      return module.Chart
    })

    return chartLoader
  }

  selectedPeriod(panel) {
    return panel.querySelector("input[type='radio']:checked")?.value || "60d"
  }

  showLoading(panel) {
    const spinner = this.spinner(panel)
    if (spinner) spinner.hidden = false
    panel.setAttribute("aria-busy", "true")
  }

  hideLoading(panel) {
    const spinner = this.spinner(panel)
    if (spinner) spinner.hidden = true
    panel.removeAttribute("aria-busy")
  }

  showEmpty(panel, message) {
    const empty = this.empty(panel)
    const canvas = this.canvas(panel)

    if (canvas) canvas.hidden = true
    if (!empty) return

    empty.textContent = message || panel.dataset.dashboardStatisticsEmptyMessage || ""
    empty.hidden = false
  }

  hideEmpty(panel) {
    const empty = this.empty(panel)
    if (empty) empty.hidden = true
  }

  destroyCharts() {
    this.charts?.forEach((chart) => chart.destroy())
    this.charts?.clear()
  }

  destroyChart(panel) {
    const chart = this.charts.get(panel.id)
    if (!chart) return

    chart.destroy()
    this.charts.delete(panel.id)
  }

  canvas(panel) {
    return panel.querySelector("[data-dashboard-statistics-target~='canvas']")
  }

  spinner(panel) {
    return panel.querySelector("[data-dashboard-statistics-target~='spinner']")
  }

  empty(panel) {
    return panel.querySelector("[data-dashboard-statistics-target~='empty']")
  }

  transparentColor(color) {
    if (!color.startsWith("#") || color.length !== 7) return "rgba(13, 110, 253, 0.12)"

    const red = parseInt(color.slice(1, 3), 16)
    const green = parseInt(color.slice(3, 5), 16)
    const blue = parseInt(color.slice(5, 7), 16)

    return `rgba(${red}, ${green}, ${blue}, 0.12)`
  }

  nextRequestId() {
    this.requestCounter = (this.requestCounter || 0) + 1
    return this.requestCounter
  }
}
