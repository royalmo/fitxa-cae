module EmployeeBulkActions
  class Tags < Base
    def self.from_params(params)
      bulk_tags = params[:bulk_tags].presence || {}

      new(
        national_ids: normalized_national_ids(params[:national_ids]),
        add_tag_ids: tag_ids(bulk_tags[:add_tag_ids]),
        remove_tag_ids: tag_ids(bulk_tags[:remove_tag_ids]),
        include_inactive: boolean(bulk_tags[:include_inactive])
      )
    end

    def self.from_parameters(parameters)
      new(
        national_ids: normalized_national_ids(parameters.fetch("national_ids")),
        add_tag_ids: tag_ids(parameters.fetch("add_tag_ids")),
        remove_tag_ids: tag_ids(parameters.fetch("remove_tag_ids")),
        include_inactive: boolean(parameters.fetch("include_inactive"))
      )
    end

    def initialize(national_ids:, add_tag_ids:, remove_tag_ids:, include_inactive:)
      @national_ids = national_ids
      @add_tag_ids = add_tag_ids
      @remove_tag_ids = remove_tag_ids
      @include_inactive = include_inactive
    end

    def parameters
      {
        national_ids: national_ids,
        add_tag_ids: add_tag_ids,
        remove_tag_ids: remove_tag_ids,
        include_inactive: include_inactive
      }
    end

    def simulation_payload
      simulation = simulation_data

      {
        total_count: simulation.fetch(:national_ids).size,
        found_count: simulation.fetch(:employee_ids).size,
        affected_count: simulation.fetch(:affected_employee_ids).size,
        tags: simulation.fetch(:selected_tags).map do |tag|
          {
            id: tag.id,
            count: simulation.fetch(:tag_counts_by_id).fetch(tag.id, 0),
            html: ApplicationController.render(partial: "admin/tags/label", formats: [ :html ], locals: { tag: tag })
          }
        end
      }
    end

    def validate_enqueue!
      raise Errors::NoAffectedEmployees if simulation_data.fetch(:affected_employee_ids).empty?
    end

    def perform(run)
      run.mark_running!(progress: 8)

      simulation = simulation_data
      affected_count = simulation.fetch(:affected_employee_ids).size
      raise Errors::NoAffectedEmployees if affected_count.zero?

      employees = Employee.where(id: simulation.fetch(:employee_ids)).includes(:tags).order(:id).to_a
      total_steps = employees.size * (add_tags.size + remove_tags.size)
      done_count = 0

      add_tags.each do |tag|
        employees.each do |employee|
          employee.tags << tag unless employee.tags.include?(tag)
          done_count += 1
          update_collection_progress(run, done_count, total_steps)
        end
      end

      remove_tags.each do |tag|
        employees.each do |employee|
          employee.tags.delete(tag) if employee.tags.include?(tag)
          done_count += 1
          update_collection_progress(run, done_count, total_steps)
        end
      end

      run.mark_completed!(I18n.t("admin.flash.employee_bulk_tags_updated", count: affected_count))
    end

    private

    attr_reader :national_ids, :add_tag_ids, :remove_tag_ids, :include_inactive

    def simulation_data
      raise Errors::InvalidBulkTags if add_tags.empty? && remove_tags.empty?
      raise Errors::ConflictingBulkTags if (add_tags.map(&:id) & remove_tags.map(&:id)).any?

      employees = Employee.where(national_id: national_ids)
      employees = employees.active unless include_inactive
      employee_ids = employees.order(:id).pluck(:id)
      selected_tags = (add_tags + remove_tags).uniq

      existing_add_counts_by_employee_id = existing_tag_counts_by_employee_id(employee_ids, add_tags.map(&:id))
      add_affected_employee_ids = add_tags.empty? ? [] : employee_ids.select do |employee_id|
        existing_add_counts_by_employee_id.fetch(employee_id, 0) < add_tags.size
      end
      remove_affected_employee_ids = tagged_employee_ids(employee_ids, remove_tags.map(&:id))

      {
        national_ids: national_ids,
        employee_ids: employee_ids,
        add_tags: add_tags,
        remove_tags: remove_tags,
        selected_tags: selected_tags,
        affected_employee_ids: (add_affected_employee_ids + remove_affected_employee_ids).uniq,
        tag_counts_by_id: tag_counts_by_id(employee_ids, selected_tags.map(&:id))
      }
    end

    def add_tags
      @add_tags ||= active_tags_for(add_tag_ids)
    end

    def remove_tags
      @remove_tags ||= active_tags_for(remove_tag_ids)
    end

    def active_tags_for(tag_ids)
      tags = Tag.active.where(id: tag_ids).order(:name, :id).to_a
      raise Errors::InvalidBulkTags if tags.size != tag_ids.size

      tags
    end

    def existing_tag_counts_by_employee_id(employee_ids, tag_ids)
      return {} if employee_ids.empty? || tag_ids.empty?

      Employee
        .joins(:tags)
        .where(id: employee_ids, tags: { id: tag_ids })
        .group("employees.id")
        .count
    end

    def tagged_employee_ids(employee_ids, tag_ids)
      return [] if employee_ids.empty? || tag_ids.empty?

      Employee
        .joins(:tags)
        .where(id: employee_ids, tags: { id: tag_ids })
        .distinct
        .pluck(:id)
    end

    def tag_counts_by_id(employee_ids, tag_ids)
      return {} if employee_ids.empty? || tag_ids.empty?

      Tag
        .joins(:employees)
        .where(id: tag_ids, employees: { id: employee_ids })
        .group("tags.id")
        .count
    end
  end
end
