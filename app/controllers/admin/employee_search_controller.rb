class Admin::EmployeeSearchController < Admin::BaseController
  EMPLOYEE_SEARCH_LIMIT = 8

  def index
    render partial: "admin/shared/employee_search_results", locals: {
      employees: employee_search_results,
      selected_employee_id: params[:selected_employee_id].presence
    }
  end

  private

  def employee_search_results
    employees = Employee.order(:last_name, :first_name, :id)
    query = params[:q].to_s.strip
    return employees.limit(EMPLOYEE_SEARCH_LIMIT) if query.blank?

    normalized_query = query.downcase
    compact_query = normalized_query.gsub(/[ .\-()]/, "")
    national_id_query = Employee.normalize_national_id(query).downcase

    employees
      .where(
        <<~SQL.squish,
          LOWER(COALESCE(first_name, '')) LIKE :query
          OR LOWER(COALESCE(last_name, '')) LIKE :query
          OR LOWER(COALESCE(first_name, '') || ' ' || COALESCE(last_name, '')) LIKE :query
          OR LOWER(COALESCE(national_id, '')) LIKE :national_id_query
          OR LOWER(COALESCE(email, '')) LIKE :query
          OR LOWER(COALESCE(phone, '')) LIKE :query
          OR REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LOWER(COALESCE(phone, '')), ' ', ''), '-', ''), '.', ''), '(', ''), ')', '') LIKE :compact_query
        SQL
        query: "%#{ActiveRecord::Base.sanitize_sql_like(normalized_query)}%",
        national_id_query: "%#{ActiveRecord::Base.sanitize_sql_like(national_id_query)}%",
        compact_query: compact_query.present? ? "%#{ActiveRecord::Base.sanitize_sql_like(compact_query)}%" : ""
      )
      .limit(EMPLOYEE_SEARCH_LIMIT)
  end
end
