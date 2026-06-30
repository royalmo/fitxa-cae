ENV["RAILS_ENV"] ||= "test"

require "simplecov"

test_env_number = ENV["TEST_ENV_NUMBER"]
test_worker_suffix = test_env_number.nil? || test_env_number.empty? ? nil : test_env_number
SimpleCov.command_name [ "rails-test", test_worker_suffix ].compact.join("-")
SimpleCov.start "rails" do
  enable_coverage :branch
end

require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    def valid_dni(number = 12_345_678)
      digits = number % 100_000_000
      "#{digits.to_s.rjust(8, "0")}#{Employee::NATIONAL_ID_LETTERS[digits % Employee::NATIONAL_ID_LETTERS.length]}"
    end

    def valid_nie(prefix = "X", number = 1_234_567)
      body = (number % 10_000_000).to_s.rjust(7, "0")
      translated_prefix = { "X" => "0", "Y" => "1", "Z" => "2" }.fetch(prefix)
      numeric_value = "#{translated_prefix}#{body}".to_i

      "#{prefix}#{body}#{Employee::NATIONAL_ID_LETTERS[numeric_value % Employee::NATIONAL_ID_LETTERS.length]}"
    end

    def build_employee(**attributes)
      Employee.new({
        first_name: "Ada",
        last_name: "Soler",
        national_id: valid_dni
      }.merge(attributes))
    end

    def create_employee(**attributes)
      build_employee(**attributes).tap(&:save!)
    end

    def create_manager(**attributes)
      Manager.create!({
        first_name: "Laia",
        last_name: "Riera",
        email: "laia.riera@example.test"
      }.merge(attributes))
    end

    def assert_model_error(record, attribute, error)
      error_codes = record.errors.details.fetch(attribute).map { |detail| detail.fetch(:error) }

      assert_includes error_codes, error
    end
  end
end
