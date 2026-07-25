module Admin::ManagersHelper
  def admin_manager_status(manager)
    manager.active? ? :active : :disabled
  end
end
