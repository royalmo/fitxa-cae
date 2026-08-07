# Preview all emails at http://localhost:3000/rails/mailers/manager_password_mailer
class ManagerPasswordMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/manager_password_mailer/password_setup
  def password_setup
    ManagerPasswordMailer.password_setup(preview_manager)
  end

  # Preview this email at http://localhost:3000/rails/mailers/manager_password_mailer/password_reset
  def password_reset
    ManagerPasswordMailer.password_reset(preview_manager)
  end

  private

  def preview_manager
    Manager.first || Manager.create!(
      first_name: "Laia",
      last_name: "Riera",
      email: "laia.riera@example.test"
    )
  end
end
