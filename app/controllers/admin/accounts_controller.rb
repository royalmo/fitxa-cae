class Admin::AccountsController < Admin::BaseController
  def show
    @manager = current_manager
  end

  def update_profile
    @manager = current_manager

    if @manager.update(manager_profile_params)
      record_manager_self_email_change_audit(@manager) if @manager.saved_change_to_email?
      redirect_to admin_account_path, notice: t("admin.flash.account_updated")
    else
      @account_error_context = :profile
      render :show, status: :unprocessable_entity
    end
  end

  def update_password
    @manager = current_manager
    assign_password_change

    if @manager.errors.empty? && @manager.save
      record_manager_password_change_audit(@manager, origin: "profile_page")
      redirect_to admin_account_path, notice: t("admin.flash.account_updated")
    else
      @account_error_context = :password
      @password_panel_open = true
      render :show, status: :unprocessable_entity
    end
  end

  private

  def manager_profile_params
    params.require(:manager).permit(:email)
  end

  def account_password_params
    params.require(:manager).permit(:password, :password_confirmation)
  end

  def assign_password_change
    if account_password_params[:password].blank? && account_password_params[:password_confirmation].blank?
      @manager.errors.add(:base, t(".password_blank"))
      return
    end

    if account_password_params[:password] != account_password_params[:password_confirmation]
      @manager.errors.add(:base, t(".password_confirmation_invalid"))
      return
    end

    @manager.password = account_password_params[:password]
  end

  def record_manager_self_email_change_audit(manager)
    previous_email, email = manager.saved_change_to_email

    record_audit_action!(
      author: manager,
      recipient: manager,
      kind: "manager.self_email_changed",
      extra_info: {
        changed_fields: [ "email" ],
        changes: { email: { from: previous_email, to: email } },
        old_email: previous_email,
        new_email: email
      }
    )
  end

  def record_manager_password_change_audit(manager, origin:)
    record_audit_action!(
      author: manager,
      recipient: manager,
      kind: "manager.password_changed",
      extra_info: {
        changed_fields: [ "password" ],
        origin: origin
      }
    )
  end
end
