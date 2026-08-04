class Admin::AuditKindSearchController < Admin::BaseController
  KIND_SEARCH_LIMIT = 8

  def index
    render partial: "admin/shared/audit_kind_search_results", locals: {
      kinds: audit_kind_search_results,
      selected_kind: params[:selected_kind].presence
    }
  end

  private

  def audit_kind_search_results
    query = params[:q].to_s.strip.downcase
    kinds = AuditAction.distinct.order(:kind).pluck(:kind)
    return kinds.first(KIND_SEARCH_LIMIT) if query.blank?

    kinds.select do |kind|
      kind.downcase.include?(query) || audit_kind_label(kind).downcase.include?(query)
    end.first(KIND_SEARCH_LIMIT)
  end

  def audit_kind_label(kind)
    helpers.admin_audit_action_kind_text(kind)
  end
end
