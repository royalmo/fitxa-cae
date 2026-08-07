class Admin::EmployeesController < Admin::BaseController
  EMPLOYEES_PER_PAGE = 20

  def index
    @selected_tag = selected_tag
    @employees = paginate_admin_relation(
      filtered_employees.order(:last_name, :first_name, :id),
      per_page: EMPLOYEES_PER_PAGE
    ).includes(:tags).to_a
    employee_ids = @employees.map(&:id)
    @last_swipes_by_employee_id = last_swipes_by_employee_id(employee_ids)
  end

  def new
    @employee = Employee.new(active: true)
    load_tags
  end

  def create
    @employee = Employee.new(employee_params)
    @employee.active = true
    @employee.tag_ids = selected_tag_ids

    if @employee.save
      deliver_employee_welcome(@employee)
      redirect_to admin_employees_path, notice: t("admin.flash.employee_created")
    else
      load_tags
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @employee = Employee.find(params[:id])
    load_tags
  end

  def update
    @employee = Employee.find(params[:id])
    @employee.assign_attributes(employee_params)
    @employee.tag_ids = selected_tag_ids

    if @employee.save
      redirect_to admin_employees_path, notice: t("admin.flash.employee_updated")
    else
      load_tags
      render :edit, status: :unprocessable_entity
    end
  end

  def activation
    @employee = Employee.find(params[:id])
    target_active = ActiveModel::Type::Boolean.new.cast(employee_activation_params[:active])

    if @employee.update(active: target_active)
      redirect_back fallback_location: admin_employees_path,
        notice: t(target_active ? "admin.flash.employee_activated" : "admin.flash.employee_deactivated")
    else
      redirect_back fallback_location: admin_employees_path, alert: t("admin.flash.employee_activation_failed")
    end
  end

  private

  def filtered_employees
    employees = Employee.all
    employees = employees.where(active: true) if params[:status] == "active"
    employees = employees.where(active: false) if params[:status] == "disabled"
    employees = employees.joins(:tags).where(tags: { id: @selected_tag.id }) if @selected_tag

    if params[:q].present?
      query = "%#{params[:q].to_s.downcase}%"
      employees = employees.where(
        "LOWER(first_name) LIKE :query OR LOWER(last_name) LIKE :query OR LOWER(email) LIKE :query OR LOWER(national_id) LIKE :query",
        query: query
      )
    end

    employees.distinct
  end

  def selected_tag
    Tag.find_by(id: params[:tag_id].presence) if params[:tag_id].present?
  end

  def employee_params
    attributes = params.require(:employee).permit(:first_name, :last_name, :national_id, :email, :phone, :active, :password)
    attributes.delete(:password) if attributes[:password].blank?
    attributes
  end

  def employee_activation_params
    params.require(:employee).permit(:active)
  end

  def selected_tag_ids
    params.dig(:employee, :tag_ids).to_a.compact_blank
  end

  def load_tags
    @tags = Tag.order(:name)
  end

  def deliver_employee_welcome(employee)
    EmployeeWelcomeMailer.welcome(employee).deliver_later if employee.email.present?
  end

  def last_swipes_by_employee_id(employee_ids)
    Swipe.kept
      .where(employee_id: employee_ids)
      .order(swipe_at: :desc, id: :desc)
      .group_by(&:employee_id)
      .transform_values(&:first)
  end
end
