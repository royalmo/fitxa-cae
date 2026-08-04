class Admin::AuditAuthorSearchController < Admin::BaseController
  AUTHOR_SEARCH_LIMIT = 8

  def index
    render partial: "admin/shared/audit_author_search_results", locals: {
      authors: audit_author_search_results,
      selected_author_value: params[:selected_author].presence
    }
  end

  private

  def audit_author_search_results
    author_type = params[:author_type].to_s
    return employee_search_results if author_type == "Employee"
    return manager_search_results if author_type == "Manager"

    (employee_search_results + manager_search_results)
      .sort_by { |author| [ audit_author_label(author).downcase, audit_author_value(author) ] }
      .first(AUTHOR_SEARCH_LIMIT)
  end

  def employee_search_results
    employees = Employee.order(:last_name, :first_name, :id)
    query = params[:q].to_s.strip
    return employees.limit(blank_query_limit).to_a if query.blank?

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
      .limit(AUTHOR_SEARCH_LIMIT)
      .to_a
  end

  def manager_search_results
    managers = Manager.order(:last_name, :first_name, :email, :id)
    query = params[:q].to_s.strip
    return managers.limit(blank_query_limit).to_a if query.blank?

    normalized_query = query.downcase

    managers
      .where(
        <<~SQL.squish,
          LOWER(COALESCE(first_name, '')) LIKE :query
          OR LOWER(COALESCE(last_name, '')) LIKE :query
          OR LOWER(COALESCE(first_name, '') || ' ' || COALESCE(last_name, '')) LIKE :query
          OR LOWER(COALESCE(email, '')) LIKE :query
        SQL
        query: "%#{ActiveRecord::Base.sanitize_sql_like(normalized_query)}%"
      )
      .limit(AUTHOR_SEARCH_LIMIT)
      .to_a
  end

  def blank_query_limit
    params[:author_type].present? ? AUTHOR_SEARCH_LIMIT : AUTHOR_SEARCH_LIMIT / 2
  end

  def audit_author_value(author)
    "#{author.class.name}:#{author.id}"
  end

  def audit_author_label(author)
    helpers.admin_audit_subject_text(author)
  end
end
