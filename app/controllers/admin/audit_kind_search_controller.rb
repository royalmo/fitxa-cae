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
    kinds = translated_audit_action_kinds
    return kinds.first(KIND_SEARCH_LIMIT) if query.blank?

    kinds.select do |kind|
      kind.downcase.include?(query) || audit_kind_label(kind).downcase.include?(query)
    end.first(KIND_SEARCH_LIMIT)
  end

  def translated_audit_action_kinds
    translated_audit_action_kind_tree.flat_map do |namespace, entries|
      audit_kind_keys(namespace, entries)
    end.compact.sort
  end

  def translated_audit_action_kind_tree
    I18n.t("audit_actions_texts", default: {}).with_indifferent_access
  end

  def audit_kind_keys(namespace, entries)
    return [] unless entries.is_a?(Hash)

    entries.filter_map do |key, value|
      "#{namespace}.#{key}" if value.is_a?(Hash) && value.key?(:name)
    end
  end

  def audit_kind_label(kind)
    helpers.admin_audit_action_kind_text(kind)
  end
end
