require "test_helper"
require "rake"

class ManagersTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    Rake::Task["managers:create_first"].reenable
    ActionMailer::Base.deliveries.clear
  end

  teardown do
    %w[EMAIL FIRST_NAME LAST_NAME].each { |key| ENV.delete(key) }
  end

  test "creates first manager and sends password setup email" do
    ENV["EMAIL"] = " LAIA.RIERA@EXAMPLE.TEST "
    ENV["FIRST_NAME"] = "Laia"
    ENV["LAST_NAME"] = "Riera"

    _stdout, _stderr = capture_io do
      Rake::Task["managers:create_first"].invoke
    end

    manager = Manager.find_by!(email: "laia.riera@example.test")

    assert_equal "Laia", manager.first_name
    assert_equal "Riera", manager.last_name
    assert_predicate manager, :active?
    assert_nil manager.password_digest
    assert_equal [ "laia.riera@example.test" ], ActionMailer::Base.deliveries.last.to
  end

  test "refuses to run when another manager exists" do
    create_manager(email: "existing@example.test")
    ENV["EMAIL"] = "new@example.test"

    _stdout, stderr = capture_io do
      assert_raises(SystemExit) do
        Rake::Task["managers:create_first"].invoke
      end
    end

    assert_includes stderr, "A manager already exists"
    assert_nil Manager.find_by(email: "new@example.test")
  end
end
