# Preview all emails at http://localhost:3000/rails/mailers/employee_welcome_mailer
class EmployeeWelcomeMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/employee_welcome_mailer/welcome
  def welcome
    EmployeeWelcomeMailer.welcome(preview_employee)
  end

  private

  def preview_employee
    Employee.where(password_digest: nil).first || Employee.create!(
      first_name: "Ada",
      last_name: "Soler",
      national_id: "12345678Z",
      email: "ada.soler@example.test"
    )
  end
end
