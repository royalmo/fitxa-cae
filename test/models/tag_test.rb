require "test_helper"

class TagTest < ActiveSupport::TestCase
  test "requires name and color and defaults to inactive" do
    tag = Tag.create!(name: "office", color: "#2563eb")

    assert_not tag.active?

    invalid_tag = Tag.new
    assert_not invalid_tag.valid?
    assert_model_error invalid_tag, :name, :blank
    assert_model_error invalid_tag, :color, :blank
  end

  test "can be assigned to many employees" do
    tag = Tag.create!(name: "wharehouse", color: "#16a34a")
    employees = [
      create_employee(first_name: "Ada", national_id: valid_dni(12_345_678)),
      create_employee(first_name: "Laia", national_id: valid_dni(87_654_321))
    ]

    tag.employees = employees

    assert_equal employees.sort, tag.employees.reload.sort
  end

  test "requires active to be boolean when explicitly assigned" do
    tag = Tag.new(name: "off-shore", color: "#6b7280", active: nil)

    assert_not tag.valid?
    assert_model_error tag, :active, :inclusion
  end
end
