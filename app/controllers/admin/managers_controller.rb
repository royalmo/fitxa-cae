class Admin::ManagersController < Admin::BaseController
  MANAGERS_PER_PAGE = 20

  def index
    @managers = paginate_admin_relation(
      filtered_managers.order(:last_name, :first_name, :email, :id),
      per_page: MANAGERS_PER_PAGE
    ).includes(:employee).to_a
  end

  def new
    @manager = Manager.new(active: true)
    load_employees
  end

  def create
    @manager = Manager.new(manager_params)

    if @manager.save
      redirect_to admin_managers_path, notice: t("admin.flash.manager_created")
    else
      load_employees
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @manager = Manager.find(params[:id])
    load_employees
  end

  def update
    @manager = Manager.find(params[:id])

    if @manager.update(manager_params)
      redirect_to admin_managers_path, notice: t("admin.flash.manager_updated")
    else
      load_employees
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def filtered_managers
    managers = Manager.all
    managers = managers.where(active: true) if params[:status] == "active"
    managers = managers.where(active: false) if params[:status] == "disabled"

    if params[:q].present?
      query = "%#{params[:q].to_s.downcase}%"
      managers = managers.where(
        "LOWER(first_name) LIKE :query OR LOWER(last_name) LIKE :query OR LOWER(email) LIKE :query",
        query: query
      )
    end

    managers
  end

  def manager_params
    attributes = params.require(:manager).permit(:first_name, :last_name, :email, :employee_id, :active, :password)
    attributes[:employee_id] = nil if attributes[:employee_id].blank?
    attributes.delete(:password) if attributes[:password].blank?
    attributes
  end

  def load_employees
    @employees = Employee.order(:last_name, :first_name, :id)
  end
end
