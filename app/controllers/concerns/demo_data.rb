module DemoData
  extend ActiveSupport::Concern

  private

  def demo_current_employee
    {
      id: 12,
      code: "EMP-012",
      first_name: "Laia",
      name: "Laia Ferrer",
      role: "Producció",
      team: "Producció",
      email: "laia.ferrer@example.test",
      clocked_in: true,
      clocked_in_at: Time.zone.local(2026, 6, 25, 8, 4),
      work_center: "Nau 2"
    }
  end

  def demo_current_manager
    {
      id: 4,
      employee_id: 31,
      name: "Marta Puig",
      role: "Responsable de RRHH",
      email: "marta.puig@example.test"
    }
  end

  def demo_today_clockings
    [
      { time: "08:04", kind: :in, place: "Nau 2", source: :pwa },
      { time: "10:31", kind: :pause_start, place: "Nau 2", source: :pwa },
      { time: "10:47", kind: :pause_end, place: "Nau 2", source: :pwa }
    ]
  end

  def demo_clocking_days
    [
      { date: Date.new(2026, 6, 25), in: "08:04", out: nil, break: "0 h 16 min", hours: "2 h 28 min", status: :open },
      { date: Date.new(2026, 6, 24), in: "08:01", out: "16:10", break: "0 h 31 min", hours: "7 h 38 min", status: :complete },
      { date: Date.new(2026, 6, 23), in: "08:07", out: "16:02", break: "0 h 29 min", hours: "7 h 26 min", status: :complete },
      { date: Date.new(2026, 6, 22), in: "08:12", out: "15:58", break: "0 h 30 min", hours: "7 h 16 min", status: :corrected },
      { date: Date.new(2026, 6, 19), in: "08:03", out: "16:04", break: "0 h 34 min", hours: "7 h 27 min", status: :complete }
    ]
  end

  def demo_employee_corrections
    [
      {
        id: 101,
        date: Date.new(2026, 6, 22),
        title: "Sortida oblidada",
        requested: "Afegir sortida a les 15:58",
        status: :approved,
        answered_at: Date.new(2026, 6, 23)
      },
      {
        id: 102,
        date: Date.new(2026, 6, 18),
        title: "Entrada fora d'hora",
        requested: "Canviar entrada de 08:31 a 08:06",
        status: :pending,
        answered_at: nil
      }
    ]
  end

  def demo_admin_stats
    [
      { label: I18n.t("demo.stats.present"), value: "42", trend: "+6" },
      { label: I18n.t("demo.stats.pending_corrections"), value: "7", trend: "-2" },
      { label: I18n.t("demo.stats.month_hours"), value: "6.284", trend: "+4%" },
      { label: I18n.t("demo.stats.inactive"), value: "3", trend: "0" }
    ]
  end

  def demo_employees
    [
      { id: 12, code: "EMP-012", name: "Laia Ferrer", team: "Producció", status: :active, last_clocking: "08:04", month_hours: "142 h", email: "laia.ferrer@example.test" },
      { id: 18, code: "EMP-018", name: "Nil Serra", team: "Magatzem", status: :active, last_clocking: "07:02", month_hours: "151 h", email: "nil.serra@example.test" },
      { id: 21, code: "EMP-021", name: "Jana Soler", team: "Administració", status: :active, last_clocking: "09:01", month_hours: "133 h", email: "jana.soler@example.test" },
      { id: 27, code: "EMP-027", name: "Pau Roca", team: "Manteniment", status: :disabled, last_clocking: "Dilluns", month_hours: "88 h", email: "pau.roca@example.test" },
      { id: 31, code: "EMP-031", name: "Marta Puig", team: "RRHH", status: :active, last_clocking: "09:08", month_hours: "136 h", email: "marta.puig@example.test" }
    ]
  end

  def demo_admin_corrections
    [
      { id: 501, employee: "Nil Serra", date: Date.new(2026, 6, 25), request: "Afegir sortida de pausa a les 10:44", status: :pending, age: "12 min" },
      { id: 502, employee: "Jana Soler", date: Date.new(2026, 6, 24), request: "Canviar entrada de 09:32 a 09:02", status: :pending, age: "1 dia" },
      { id: 503, employee: "Pau Roca", date: Date.new(2026, 6, 20), request: "Eliminar fitxatge duplicat de sortida", status: :rejected, age: "5 dies" },
      { id: 504, employee: "Laia Ferrer", date: Date.new(2026, 6, 22), request: "Afegir sortida a les 15:58", status: :approved, age: "3 dies" }
    ]
  end

  def demo_report_rows
    [
      { employee: "Laia Ferrer", hours: "142 h", days: 19, corrections: 1 },
      { employee: "Nil Serra", hours: "151 h", days: 20, corrections: 2 },
      { employee: "Jana Soler", hours: "133 h", days: 18, corrections: 1 },
      { employee: "Pau Roca", hours: "88 h", days: 12, corrections: 0 }
    ]
  end
end
