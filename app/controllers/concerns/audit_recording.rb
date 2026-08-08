module AuditRecording
  extend ActiveSupport::Concern

  AUDIT_IGNORED_CHANGE_FIELDS = %w[id created_at updated_at password_digest].freeze

  private

  def record_audit_action!(author:, recipient:, kind:, extra_info: {})
    AuditAction.create!(
      author: author,
      recipient: recipient,
      kind: kind,
      extra_info: normalize_audit_extra_info(extra_info)
    )
  end

  def audit_saved_changes(record, fields: nil)
    fields = Array(fields).map(&:to_s) if fields
    changes = record.saved_changes.except(*AUDIT_IGNORED_CHANGE_FIELDS)
    changes = changes.slice(*fields) if fields

    changes.transform_values do |old_value, new_value|
      {
        "from" => audit_json_value(old_value),
        "to" => audit_json_value(new_value)
      }
    end
  end

  def audit_changed_fields(changes)
    changes.keys
  end

  def record_audit_update!(author:, recipient:, kind:, changes:, extra_info: {})
    return if changes.blank?

    record_audit_action!(
      author: author,
      recipient: recipient,
      kind: kind,
      extra_info: {
        changed_fields: audit_changed_fields(changes),
        changes: changes
      }.merge(extra_info)
    )
  end

  def audit_tag_change_details(before_tag_ids, after_tag_ids)
    before_tag_ids = Array(before_tag_ids).map(&:to_i)
    after_tag_ids = Array(after_tag_ids).map(&:to_i)
    added_ids = after_tag_ids - before_tag_ids
    removed_ids = before_tag_ids - after_tag_ids

    {
      "added_tag_ids" => added_ids,
      "removed_tag_ids" => removed_ids,
      "added_tags" => audit_tag_names(added_ids),
      "removed_tags" => audit_tag_names(removed_ids)
    }
  end

  def audit_correction_details(correction, extra_info: {})
    details = correction.details || {}
    requested_swipes = Array(details["requested_swipes"]).map do |requested_swipe|
      {
        "kind" => requested_swipe["kind"].to_s,
        "hour" => requested_swipe["hour"].to_s
      }
    end

    {
      correction_id: correction.id,
      day: correction.day&.iso8601,
      status: correction.status,
      invalidated_swipe_ids: Array(details["invalidated_swipe_ids"]).map(&:to_s),
      requested_swipes: requested_swipes,
      requested_swipe_count: requested_swipes.size,
      invalidated_swipe_count: Array(details["invalidated_swipe_ids"]).compact_blank.size
    }.merge(extra_info)
  end

  def audit_report_export_details(report_export, extra_info: {})
    {
      report_export_id: report_export.id,
      report_kind: report_export.kind,
      format: audit_report_export_format(report_export),
      filename: report_export.filename,
      parameters: report_export.parameters
    }.merge(audit_period_details(report_export.parameters)).merge(extra_info)
  end

  def audit_period_details(parameters)
    parameters = parameters.to_h.with_indifferent_access

    {
      month: parameters[:month],
      year: parameters[:year],
      period: audit_period_text(parameters[:month], parameters[:year])
    }.compact
  end

  def audit_period_text(month, year)
    month = Integer(month, exception: false)
    year = Integer(year, exception: false)
    return unless month&.between?(1, 12) && year

    I18n.l(Date.new(year, month, 1), format: :month_year)
  rescue Date::Error
    nil
  end

  def audit_report_export_format(report_export)
    return "pdf" if report_export.content_type.to_s.include?("pdf")
    return "zip" if report_export.content_type.to_s.include?("zip")

    report_export.filename.to_s.split(".").last.presence
  end

  def audit_bulk_action_details(run)
    summary = audit_bulk_action_parameter_summary(run.parameters).with_indifferent_access

    {
      employee_bulk_action_run_id: run.id,
      bulk_action_kind: run.kind
    }.merge(summary).merge(
      add_tags: audit_tag_names(summary["add_tag_ids"]),
      remove_tags: audit_tag_names(summary["remove_tag_ids"]),
      tags: audit_tag_names(summary["tag_ids"])
    ).then { |details| compact_audit_hash(details) }
  end

  def audit_bulk_action_parameter_summary(parameters)
    parameters = parameters.to_h.with_indifferent_access
    national_ids = Array(parameters[:national_ids])

    {
      action: parameters[:action],
      affected_national_id_count: national_ids.size,
      add_tag_ids: Array(parameters[:add_tag_ids]).map(&:to_i),
      remove_tag_ids: Array(parameters[:remove_tag_ids]).map(&:to_i),
      tag_ids: Array(parameters[:tag_ids]).map(&:to_i),
      include_inactive: parameters[:include_inactive],
      source: parameters[:source]
    }.then { |details| compact_audit_hash(details) }
  end

  def normalize_audit_extra_info(value)
    case value
    when ActionController::Parameters
      normalize_audit_extra_info(value.to_unsafe_h)
    when Hash
      value.each_with_object({}) do |(key, nested_value), details|
        details[key.to_s] = normalize_audit_extra_info(nested_value)
      end.then { |details| compact_audit_hash(details) }
    when Array
      value.map { |nested_value| normalize_audit_extra_info(nested_value) }
    when ActiveRecord::Base
      { "type" => value.class.name, "id" => value.id }
    when Date, Time, ActiveSupport::TimeWithZone
      value.iso8601
    else
      value
    end
  end

  def audit_json_value(value)
    case value
    when Date, Time, ActiveSupport::TimeWithZone
      value.iso8601
    else
      value
    end
  end

  def audit_tag_names(tag_ids)
    Tag.where(id: tag_ids).order(:name, :id).pluck(:name)
  end

  def compact_audit_hash(hash)
    hash.reject do |_key, value|
      value.nil? || value == "" || (value.respond_to?(:empty?) && value.empty?)
    end
  end
end
