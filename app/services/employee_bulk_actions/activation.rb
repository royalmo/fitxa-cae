module EmployeeBulkActions
  class Activation < Base
    ACTIONS = {
      "activate" => true,
      "deactivate" => false
    }.freeze
    SELECTION_MODES = %w[national_ids tags].freeze

    def self.from_params(params)
      bulk_action = params[:bulk_action].presence || {}
      selection_mode = selection_mode_from(bulk_action[:selection_mode])

      new(
        action: action_from(bulk_action[:action]),
        selection_mode: selection_mode,
        national_ids: selection_mode == "national_ids" ? normalized_national_ids(params[:national_ids]) : [],
        include_tag_ids: tag_ids(bulk_action[:include_tag_ids]),
        exclude_tag_ids: tag_ids(bulk_action[:exclude_tag_ids])
      )
    end

    def self.from_simulation_params(params)
      bulk_action = params[:bulk_action].presence || {}
      selection_mode = selection_mode_from(bulk_action[:selection_mode])

      new(
        action: nil,
        selection_mode: selection_mode,
        national_ids: selection_mode == "national_ids" ? normalized_national_ids(params[:national_ids]) : [],
        include_tag_ids: tag_ids(bulk_action[:include_tag_ids]),
        exclude_tag_ids: tag_ids(bulk_action[:exclude_tag_ids])
      )
    end

    def self.from_parameters(parameters)
      selection_mode = selection_mode_from(parameters.fetch("selection_mode", "national_ids"))

      new(
        action: action_from(parameters.fetch("action")),
        selection_mode: selection_mode,
        national_ids: selection_mode == "national_ids" ? normalized_national_ids(parameters.fetch("national_ids")) : [],
        include_tag_ids: tag_ids(parameters.fetch("include_tag_ids", [])),
        exclude_tag_ids: tag_ids(parameters.fetch("exclude_tag_ids", []))
      )
    end

    def self.action_from(raw_action)
      action = raw_action.to_s
      raise Errors::InvalidRequest unless ACTIONS.key?(action)

      action
    end

    def self.selection_mode_from(raw_selection_mode)
      selection_mode = raw_selection_mode.to_s.presence || "national_ids"
      raise Errors::InvalidRequest unless SELECTION_MODES.include?(selection_mode)

      selection_mode
    end

    def initialize(action:, selection_mode:, national_ids:, include_tag_ids:, exclude_tag_ids:)
      @action = action
      @selection_mode = selection_mode
      @national_ids = national_ids
      @include_tag_ids = include_tag_ids
      @exclude_tag_ids = exclude_tag_ids
    end

    def parameters
      base_parameters = {
        action: action,
        selection_mode: selection_mode
      }

      if national_ids_selection?
        base_parameters.merge(national_ids: national_ids)
      else
        base_parameters.merge(include_tag_ids: include_tag_ids, exclude_tag_ids: exclude_tag_ids)
      end
    end

    def simulation_payload
      return national_ids_simulation_payload if national_ids_selection?

      tag_selection_simulation_payload
    end

    def validate_enqueue!
      raise Errors::NoAffectedEmployees if affected_count.zero?
    end

    def perform(run)
      run.mark_running!(progress: 8)

      affected_employees = affected_scope.to_a
      raise Errors::NoAffectedEmployees if affected_employees.empty?

      affected_employees.each_with_index do |employee, index|
        employee.update!(active: target_active)
        update_collection_progress(run, index + 1, affected_employees.size)
      end

      run.mark_completed!(completed_message(affected_employees.size))
    end

    private

    attr_reader :action, :selection_mode, :national_ids, :include_tag_ids, :exclude_tag_ids

    def national_ids_simulation_payload
      Employee
        .where(national_id: national_ids)
        .pluck(:national_id, :active)
        .to_h
    end

    def tag_selection_simulation_payload
      counts = tag_selection_scope.group(:active).count

      {
        total_count: Employee.count,
        found_count: counts.values.sum,
        active_count: counts.fetch(true, 0),
        inactive_count: counts.fetch(false, 0)
      }
    end

    def affected_count
      affected_scope.count
    end

    def affected_scope
      selection_scope
        .where(active: !target_active)
        .order(:id)
    end

    def selection_scope
      return Employee.where(national_id: national_ids) if national_ids_selection?

      tag_selection_scope
    end

    def tag_selection_scope
      validate_tag_selection!

      scope = Employee.where(id: employee_ids_with_all_tags(include_tags.map(&:id)))
      excluded_employee_ids = employee_ids_with_any_tags(exclude_tags.map(&:id))
      scope = scope.where.not(id: excluded_employee_ids) if excluded_employee_ids.any?
      scope
    end

    def validate_tag_selection!
      raise Errors::InvalidBulkTags if include_tags.empty?
      raise Errors::ConflictingBulkTags if (include_tags.map(&:id) & exclude_tags.map(&:id)).any?
    end

    def include_tags
      @include_tags ||= active_tags_for(include_tag_ids)
    end

    def exclude_tags
      @exclude_tags ||= active_tags_for(exclude_tag_ids)
    end

    def active_tags_for(tag_ids)
      tags = Tag.active.where(id: tag_ids).order(:name, :id).to_a
      raise Errors::InvalidBulkTags if tags.size != tag_ids.size

      tags
    end

    def employee_ids_with_all_tags(tag_ids)
      return [] if tag_ids.empty?

      Employee
        .joins(:tags)
        .where(tags: { id: tag_ids })
        .group("employees.id")
        .having("COUNT(DISTINCT tags.id) = ?", tag_ids.size)
        .pluck(:id)
    end

    def employee_ids_with_any_tags(tag_ids)
      return [] if tag_ids.empty?

      Employee
        .joins(:tags)
        .where(tags: { id: tag_ids })
        .distinct
        .pluck(:id)
    end

    def national_ids_selection?
      selection_mode == "national_ids"
    end

    def target_active
      ACTIONS.fetch(action)
    end

    def completed_message(count)
      flash_key = target_active ? "admin.flash.employee_bulk_activated" : "admin.flash.employee_bulk_deactivated"

      I18n.t(flash_key, count: count)
    end
  end
end
