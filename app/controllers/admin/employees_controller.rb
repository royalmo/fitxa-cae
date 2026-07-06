class Admin::EmployeesController < Admin::BaseController
  def index
    @tags = Tag.order(:name)
    @employees = filtered_employees.includes(:tags).order(:last_name, :first_name, :id)
    employee_ids = @employees.map(&:id)
    @last_swipes_by_employee_id = last_swipes_by_employee_id(employee_ids)
    @month_work_seconds_by_employee_id = month_work_seconds_by_employee_id(employee_ids)
  end

  def new
    @employee = Employee.new(active: true)
    load_tags
  end

  def create
    @employee = Employee.new(employee_params)
    @employee.tag_ids = selected_tag_ids

    if @employee.save
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

  private

  def filtered_employees
    employees = Employee.all
    employees = employees.where(active: true) if params[:status] == "active"
    employees = employees.where(active: false) if params[:status] == "disabled"
    employees = employees.joins(:tags).where(tags: { id: params[:tag_id] }) if params[:tag_id].present?

    if params[:q].present?
      query = "%#{params[:q].to_s.downcase}%"
      employees = employees.where(
        "LOWER(first_name) LIKE :query OR LOWER(last_name) LIKE :query OR LOWER(email) LIKE :query OR LOWER(national_id) LIKE :query",
        query: query
      )
    end

    employees.distinct
  end

  def employee_params
    attributes = params.require(:employee).permit(:first_name, :last_name, :national_id, :email, :phone, :active, :password)
    attributes.delete(:password) if attributes[:password].blank?
    attributes
  end

  def selected_tag_ids
    params.dig(:employee, :tag_ids).to_a.compact_blank
  end

  def load_tags
    @tags = Tag.order(:name)
  end

  def last_swipes_by_employee_id(employee_ids)
    Swipe.kept
      .where(employee_id: employee_ids)
      .order(swipe_at: :desc, id: :desc)
      .group_by(&:employee_id)
      .transform_values(&:first)
  end

  def month_work_seconds_by_employee_id(employee_ids)
    range = Time.zone.today.beginning_of_month.beginning_of_day..Time.zone.today.end_of_month.end_of_day

    Swipe.kept
      .where(employee_id: employee_ids, swipe_at: range)
      .chronological
      .group_by { |swipe| [ swipe.employee_id, swipe.swipe_at.to_date ] }
      .each_with_object(Hash.new(0)) do |((employee_id, _day), swipes), totals|
        totals[employee_id] += Swipe.paired_work_seconds(swipes)
      end
  end
end
