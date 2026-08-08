require "test_helper"

class Reports::MonthlyEmployeeScopeTest < ActiveSupport::TestCase
  test "includes employees active during the month or with kept swipes in the month" do
    active_in_month = create_employee(
      first_name: "Aina",
      last_name: "Historica",
      national_id: valid_dni(47_000_001),
      active: false
    )
    active_in_month.employment_periods.create!(
      started_at: Time.zone.local(2026, 6, 20),
      ended_at: Time.zone.local(2026, 7, 10)
    )
    swiped_in_month = create_employee(
      first_name: "Clara",
      last_name: "Fitxada",
      national_id: valid_dni(47_000_002),
      active: false
    )
    swiped_in_month.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 5, 9, 0))
    active_after_month = create_employee(
      first_name: "Ona",
      last_name: "Agost",
      national_id: valid_dni(47_000_003),
      active: false
    )
    active_after_month.employment_periods.create!(
      started_at: Time.zone.local(2026, 8, 1),
      ended_at: Time.zone.local(2026, 8, 10)
    )
    removed_swipe = create_employee(
      first_name: "Nil",
      last_name: "Eliminat",
      national_id: valid_dni(47_000_004),
      active: false
    )
    removed_swipe.swipes.create!(
      kind: :entry,
      swipe_at: Time.zone.local(2026, 7, 5, 9, 0),
      removed: true
    )

    employees = Reports::MonthlyEmployeeScope.resolve(month: 7, year: 2026)
    employee_ids = employees.map(&:id)

    assert_includes employee_ids, active_in_month.id
    assert_includes employee_ids, swiped_in_month.id
    assert_not_includes employee_ids, active_after_month.id
    assert_not_includes employee_ids, removed_swipe.id
  end

  test "tag scope uses current tag membership after monthly activity is selected" do
    tag = Tag.create!(name: "Obra", color: "#0f766e", active: true)
    tagged_active_in_month = create_employee(
      first_name: "Aina",
      last_name: "Obra",
      national_id: valid_dni(47_000_005),
      active: false
    )
    tagged_active_in_month.employment_periods.create!(
      started_at: Time.zone.local(2026, 7, 1),
      ended_at: Time.zone.local(2026, 7, 15)
    )
    untagged_active_in_month = create_employee(
      first_name: "Clara",
      last_name: "Sense etiqueta",
      national_id: valid_dni(47_000_006),
      active: false
    )
    untagged_active_in_month.employment_periods.create!(
      started_at: Time.zone.local(2026, 7, 1),
      ended_at: Time.zone.local(2026, 7, 15)
    )
    tagged_swiped_in_month = create_employee(
      first_name: "Ona",
      last_name: "Fitxada",
      national_id: valid_dni(47_000_007),
      active: false
    )
    tagged_swiped_in_month.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 7, 5, 9, 0))
    tagged_active_in_month.tags << tag
    tagged_swiped_in_month.tags << tag

    employees = Reports::MonthlyEmployeeScope.resolve(month: 7, year: 2026, tag: tag)
    employee_ids = employees.map(&:id)

    assert_includes employee_ids, tagged_active_in_month.id
    assert_includes employee_ids, tagged_swiped_in_month.id
    assert_not_includes employee_ids, untagged_active_in_month.id
  end
end
