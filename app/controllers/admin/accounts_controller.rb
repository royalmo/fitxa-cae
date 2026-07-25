class Admin::AccountsController < Admin::BaseController
  def show
    @manager = current_manager
  end

  def update_profile
    @manager = current_manager

    if @manager.update(manager_profile_params)
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
      redirect_to admin_account_path, notice: t("admin.flash.account_updated")
    else
      @account_error_context = :password
      @password_panel_open = true
      render :show, status: :unprocessable_entity
    end
  end

  private

  def manager_profile_params
    params.require(:manager).permit(:first_name, :last_name, :email)
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
end
