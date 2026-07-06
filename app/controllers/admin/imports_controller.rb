class Admin::ImportsController < Admin::BaseController
  def new
  end

  def create
    redirect_to admin_employees_path, notice: t("admin.flash.import_started")
  end
end
