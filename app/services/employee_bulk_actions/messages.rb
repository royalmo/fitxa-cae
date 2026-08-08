module EmployeeBulkActions
  module Messages
    EXPECTED_ERROR_CLASSES = [
      Errors::InvalidNationalIds,
      Errors::DuplicateNationalIds,
      Errors::NoAffectedEmployees,
      Errors::InvalidRequest,
      Errors::InvalidBulkTags,
      Errors::ConflictingBulkTags,
      Errors::InvalidImport,
      Errors::InvalidImportTags
    ].freeze

    module_function

    def error_message(error)
      case error
      when Errors::InvalidNationalIds
        invalid_national_ids_error(error)
      when Errors::DuplicateNationalIds
        I18n.t("admin.employee_bulk_actions.errors.duplicate_national_id",
          national_id: error.national_id,
          count: error.count)
      when Errors::NoAffectedEmployees
        I18n.t("admin.employee_bulk_actions.errors.no_affected_employees")
      when Errors::InvalidRequest
        I18n.t("admin.employee_bulk_actions.errors.invalid_request")
      when Errors::InvalidBulkTags
        I18n.t("admin.employee_bulk_actions.errors.invalid_tags")
      when Errors::ConflictingBulkTags
        I18n.t("admin.employee_bulk_actions.errors.conflicting_tags")
      when Errors::InvalidImport
        I18n.t("admin.imports.errors.#{error.translation_key}", **error.options)
      when Errors::InvalidImportTags
        I18n.t("admin.imports.errors.invalid_tags")
      else
        error.message.to_s.presence || I18n.t("admin.employee_bulk_action_runs.errors.generic")
      end
    end

    def expected_error?(error)
      EXPECTED_ERROR_CLASSES.any? { |error_class| error.is_a?(error_class) }
    end

    def invalid_national_ids_error(error)
      return I18n.t("admin.employee_bulk_actions.errors.invalid_national_ids") if error.national_id.blank?

      I18n.t("admin.employee_bulk_actions.errors.invalid_national_id", national_id: error.national_id)
    end
  end
end
