require "test_helper"

class Reports::MonthlySummaryReportTest < ActiveSupport::TestCase
  test "sets row notes with one-message priority" do
    no_swipes_employee = nil
    paired_employee = nil
    pending_correction_employee = nil
    odd_swipes_employee = nil
    odd_swipes_with_pending_correction_employee = nil

    travel_to Time.zone.local(2026, 8, 1, 8, 0) do
      no_swipes_employee = create_employee(first_name: "Aina", last_name: "Sense fitxatges", national_id: valid_dni(47_100_001))
      paired_employee = create_employee(first_name: "Clara", last_name: "Parell", national_id: valid_dni(47_100_002))
      pending_correction_employee = create_employee(first_name: "Berta", last_name: "Correccio", national_id: valid_dni(47_100_003))
      odd_swipes_employee = create_employee(first_name: "Jana", last_name: "Imparell", national_id: valid_dni(47_100_004))
      odd_swipes_with_pending_correction_employee = create_employee(first_name: "Ona", last_name: "Prioritat", national_id: valid_dni(47_100_005))
    end

    paired_employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 8, 10, 9, 0))
    paired_employee.swipes.create!(kind: :exit, swipe_at: Time.zone.local(2026, 8, 10, 17, 0))
    pending_correction_employee.swipe_corrections.create!(
      requester: pending_correction_employee,
      status: :pending,
      day: Date.new(2026, 8, 12)
    )
    odd_swipes_employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 8, 15, 9, 0))
    odd_swipes_employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 8, 17, 9, 0))
    odd_swipes_employee.swipes.create!(kind: :exit, swipe_at: Time.zone.local(2026, 8, 17, 17, 0))
    odd_swipes_with_pending_correction_employee.swipes.create!(kind: :entry, swipe_at: Time.zone.local(2026, 8, 15, 9, 0))
    odd_swipes_with_pending_correction_employee.swipe_corrections.create!(
      requester: odd_swipes_with_pending_correction_employee,
      status: :pending,
      day: Date.new(2026, 8, 15)
    )

    rows = Reports::MonthlySummaryReport.new(month: 8, year: 2026).to_h.fetch(:rows)
    rows_by_employee_id = rows.index_by { |row| row.fetch(:employee).id }

    assert_equal false, rows_by_employee_id.fetch(no_swipes_employee.id).fetch(:odd_swipes)
    assert_equal :no_swipes, rows_by_employee_id.fetch(no_swipes_employee.id).fetch(:note_key)
    assert_equal false, rows_by_employee_id.fetch(paired_employee.id).fetch(:odd_swipes)
    assert_nil rows_by_employee_id.fetch(paired_employee.id).fetch(:note_key)
    assert_equal true, rows_by_employee_id.fetch(pending_correction_employee.id).fetch(:pending_corrections)
    assert_equal :pending_corrections, rows_by_employee_id.fetch(pending_correction_employee.id).fetch(:note_key)
    assert_equal true, rows_by_employee_id.fetch(odd_swipes_employee.id).fetch(:odd_swipes)
    assert_equal :erroneous_swipes, rows_by_employee_id.fetch(odd_swipes_employee.id).fetch(:note_key)
    assert_equal true, rows_by_employee_id.fetch(odd_swipes_with_pending_correction_employee.id).fetch(:odd_swipes)
    assert_equal true, rows_by_employee_id.fetch(odd_swipes_with_pending_correction_employee.id).fetch(:pending_corrections)
    assert_equal :erroneous_swipes, rows_by_employee_id.fetch(odd_swipes_with_pending_correction_employee.id).fetch(:note_key)
  end
end
