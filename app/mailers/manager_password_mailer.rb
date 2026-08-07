class ManagerPasswordMailer < ApplicationMailer
  def password_setup(manager)
    @manager = manager
    @manager_name = manager.full_name.presence || manager.email
    @password_url = edit_admin_password_reset_url(manager.password_setup_token)

    mail to: manager.email, subject: t(".subject")
  end

  def password_reset(manager)
    @manager = manager
    @manager_name = manager.full_name.presence || manager.email
    @password_url = edit_admin_password_reset_url(manager.password_reset_token)

    mail to: manager.email, subject: t(".subject")
  end
end
