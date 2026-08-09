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
    include ActiveSupport::Testing::TimeHelpers

    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    setup do
      clear_test_rate_limit_stores
    end

    # Add more helper methods to be used by all tests here...
    def clear_test_rate_limit_stores
      stores = [
        Employee::SessionsController::CODE_REQUEST_RATE_LIMIT_STORE,
        Admin::SessionsController::PASSWORD_LOGIN_RATE_LIMIT_STORE,
        Admin::PasswordResetsController::PASSWORD_RESET_RATE_LIMIT_STORE
      ]

      stores.each { |store| store.clear if store.respond_to?(:clear) }
    end

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
      @manager_email_sequence = @manager_email_sequence.to_i + 1

      Manager.create!({
        first_name: "Laia",
        last_name: "Riera",
        email: "manager#{@manager_email_sequence}@example.test",
        password: "12345678"
      }.merge(attributes))
    end

    def log_in_employee(employee = create_employee(password: "1234"))
      post login_path, params: {
        national_id: employee.national_id,
        password: "1234"
      }
    end

    def log_in_manager(manager = create_manager)
      post admin_login_path, params: {
        email: manager.email,
        password: "12345678"
      }
    end

    def correction_server_updated_at(employee, day)
      SwipeCorrection.day_server_updated_at(employee: employee, day: day)
    end

    def assert_model_error(record, attribute, error)
      error_codes = record.errors.details.fetch(attribute).map { |detail| detail.fetch(:error) }

      assert_includes error_codes, error
    end

    def with_secure_random_number(value)
      singleton = class << SecureRandom
        self
      end
      original_method = SecureRandom.method(:random_number)

      singleton.define_method(:random_number) { |_limit = nil| value }
      yield
    ensure
      singleton.define_method(:random_number, original_method) if original_method
    end

    def with_error_notifications
      singleton = class << ErrorNotifier
        self
      end
      original_method = ErrorNotifier.method(:notify)
      notifications = []

      singleton.define_method(:notify) do |error, data: {}|
        notifications << { error: error, data: data }
      end
      yield notifications
    ensure
      singleton.define_method(:notify, original_method) if original_method
    end

    def with_app_brand(
      name:,
      slug:,
      legal_notice_url: Rails.configuration.x.legal_notice_url,
      brand_suffix_image: Rails.configuration.x.app_brand_suffix_image,
      favicon: Rails.configuration.x.app_favicon,
      icon_png: Rails.configuration.x.app_icon_png,
      icon_svg: Rails.configuration.x.app_icon_svg
    )
      previous_name = Rails.configuration.x.app_name
      previous_slug = Rails.configuration.x.app_slug
      previous_legal_notice_url = Rails.configuration.x.legal_notice_url
      previous_brand_suffix_image = Rails.configuration.x.app_brand_suffix_image
      previous_favicon = Rails.configuration.x.app_favicon
      previous_icon_png = Rails.configuration.x.app_icon_png
      previous_icon_svg = Rails.configuration.x.app_icon_svg

      Rails.configuration.x.app_name = name
      Rails.configuration.x.app_slug = slug
      Rails.configuration.x.legal_notice_url = legal_notice_url
      Rails.configuration.x.app_brand_suffix_image = brand_suffix_image
      Rails.configuration.x.app_favicon = favicon
      Rails.configuration.x.app_icon_png = icon_png
      Rails.configuration.x.app_icon_svg = icon_svg
      yield
    ensure
      Rails.configuration.x.app_name = previous_name
      Rails.configuration.x.app_slug = previous_slug
      Rails.configuration.x.legal_notice_url = previous_legal_notice_url
      Rails.configuration.x.app_brand_suffix_image = previous_brand_suffix_image
      Rails.configuration.x.app_favicon = previous_favicon
      Rails.configuration.x.app_icon_png = previous_icon_png
      Rails.configuration.x.app_icon_svg = previous_icon_svg
    end
  end
end
