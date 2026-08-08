require "csv"

module EmployeeBulkActions
  class Import < Base
    EXPECTED_HEADER_KEYS = %w[name surname dninie email phone].freeze
    SECOND_SURNAME_HEADER_KEYS = %w[name surname1 surname2 dninie email phone].freeze
    SUPPORTED_HEADER_KEYS = [
      EXPECTED_HEADER_KEYS,
      %w[nom cognoms dninie correu telefon],
      %w[nom cognoms dninie email telefon],
      SECOND_SURNAME_HEADER_KEYS,
      %w[nom primercognom segoncognom dninie correu telefon],
      %w[nom primercognom segoncognom dninie email telefon],
      %w[nom cognom1 cognom2 dninie correu telefon],
      %w[nom cognom1 cognom2 dninie email telefon]
    ].freeze

    def self.from_params(params)
      import_params = params[:import].presence || {}

      new(
        source: params[:source].presence || import_params[:source].presence || "paste",
        content: import_content_from(params, import_params),
        allow_second_surname: boolean(params.key?(:allow_second_surname) ? params[:allow_second_surname] : import_params[:allow_second_surname]),
        tag_ids: tag_ids(params[:tag_ids].presence || import_params[:tag_ids])
      )
    end

    def self.from_parameters(parameters)
      new(
        source: parameters.fetch("source"),
        content: parameters.fetch("content"),
        allow_second_surname: boolean(parameters.fetch("allow_second_surname")),
        tag_ids: tag_ids(parameters.fetch("tag_ids"))
      )
    end

    def self.import_content_from(params, import_params)
      return params[:content] if params.key?(:content)
      return import_params[:pasted_data] if (params[:source].presence || import_params[:source].presence || "paste") == "paste"

      import_params[:file]&.read
    end

    def initialize(source:, content:, allow_second_surname:, tag_ids:)
      @source = source
      @content = content
      @allow_second_surname = allow_second_surname
      @tag_ids = tag_ids
    end

    def parameters
      {
        source: source,
        content: content.to_s,
        allow_second_surname: allow_second_surname,
        tag_ids: tag_ids
      }
    end

    def simulation_payload
      simulation = simulation_data

      {
        total_count: simulation.fetch(:records).size,
        importable_count: simulation.fetch(:importable_records).size,
        existing_count: simulation.fetch(:existing_national_ids).size,
        existing_tag_update_count: simulation.fetch(:existing_tag_update_count),
        actionable_count: simulation.fetch(:actionable_count)
      }
    end

    def validate_enqueue!
      raise Errors::InvalidImport.new(:no_importable_people) if simulation_data.fetch(:actionable_count).zero?
    end

    def perform(run)
      run.mark_running!(progress: 8)

      simulation = simulation_data
      raise Errors::InvalidImport.new(:no_importable_people) if simulation.fetch(:actionable_count).zero?

      created_employees = apply_import!(simulation, run)
      run.update!(progress: 94)
      deliver_employee_welcome_emails(created_employees)
      run.mark_completed!(import_completed_message(simulation.fetch(:importable_records), simulation.fetch(:existing_tag_update_count)))
    end

    private

    attr_reader :source, :content, :allow_second_surname, :tag_ids

    def simulation_data
      records = import_records
      raise_duplicated_import_national_ids!(records)

      existing_employees = Employee.where(national_id: records.map(&:national_id)).to_a
      existing_national_ids = existing_employees.map(&:national_id)
      importable_records = records.reject { |record| existing_national_ids.include?(record.national_id) }
      existing_tag_update_count = existing_employees_requiring_tags(existing_employees, import_tags).size

      {
        records: records,
        importable_records: importable_records,
        existing_national_ids: existing_national_ids,
        existing_tag_update_count: existing_tag_update_count,
        actionable_count: importable_records.size + existing_tag_update_count,
        tags: import_tags
      }
    end

    def import_records
      rows = parsed_import_rows
      raise Errors::InvalidImport.new(:empty_data) if rows.empty?

      rows.map.with_index(1) { |row, index| import_record_from_row(row, index) }
    end

    def import_record_from_row(row, index)
      expected_column_count = import_column_count
      raise Errors::InvalidImport.new(:invalid_columns, row: index, count: expected_column_count) unless row.size == expected_column_count

      first_name, last_name, national_id, email, phone = import_columns_from_row(row)
      normalized_national_id = Employee.normalize_national_id(national_id)

      raise Errors::InvalidImport.new(:blank_name, row: index) if first_name.blank?
      raise Errors::InvalidImport.new(:invalid_national_id, row: index, national_id: national_id) if invalid_national_id?(normalized_national_id)

      ImportRecord.new(
        first_name: first_name,
        last_name: last_name.presence,
        national_id: normalized_national_id,
        email: email.presence,
        phone: phone.presence
      )
    end

    def import_columns_from_row(row)
      columns = row.map { |value| value.to_s.strip }
      return columns unless allow_second_surname

      first_name, first_last_name, second_last_name, national_id, email, phone = columns

      [
        first_name,
        [ first_last_name, second_last_name ].compact_blank.join(" "),
        national_id,
        email,
        phone
      ]
    end

    def import_column_count
      allow_second_surname ? SECOND_SURNAME_HEADER_KEYS.size : EXPECTED_HEADER_KEYS.size
    end

    def parsed_import_rows
      normalized_content = content.to_s.delete_prefix("\uFEFF")
      raise Errors::InvalidImport.new(:empty_data) if normalized_content.strip.blank?

      rows = CSV.parse(normalized_content, col_sep: import_col_sep(normalized_content), liberal_parsing: true).map do |row|
        Array(row).map { |value| value.to_s.strip }
      end
      rows.reject! { |row| row.all?(&:blank?) }
      rows.shift if rows.first && header_row?(rows.first)
      rows
    rescue CSV::MalformedCSVError => error
      raise Errors::InvalidImport.new(:malformed_csv, message: error.message)
    end

    def import_col_sep(content)
      first_data_line = content.each_line.find { |line| line.strip.present? }.to_s

      first_data_line.count("\t") > first_data_line.count(",") ? "\t" : ","
    end

    def header_row?(row)
      SUPPORTED_HEADER_KEYS.include?(row.map { |value| header_key(value) })
    end

    def header_key(value)
      value.to_s.downcase.gsub(/[^[:alnum:]]/, "").tr("èé", "ee").tr("òó", "oo")
    end

    def invalid_national_id?(national_id)
      national_id.blank? || !Employee.valid_national_id?(national_id)
    end

    def raise_duplicated_import_national_ids!(records)
      counts = records.map(&:national_id).tally
      duplicated_national_id = records.map(&:national_id).find { |national_id| counts.fetch(national_id) > 1 }

      return unless duplicated_national_id

      raise Errors::InvalidImport.new(:duplicate_national_id,
        national_id: duplicated_national_id,
        count: counts.fetch(duplicated_national_id))
    end

    def import_tags
      @import_tags ||= begin
        tags = Tag.active.where(id: tag_ids).order(:name, :id).to_a
        raise Errors::InvalidImportTags if tags.size != tag_ids.size

        tags
      end
    end

    def existing_employees_requiring_tags(existing_employees, tags)
      tag_ids = tags.map(&:id)
      return [] if existing_employees.empty? || tag_ids.empty?

      existing_tag_counts_by_employee_id = Employee
        .joins(:tags)
        .where(id: existing_employees.map(&:id), tags: { id: tag_ids })
        .group("employees.id")
        .count

      existing_employees.select do |employee|
        existing_tag_counts_by_employee_id.fetch(employee.id, 0) < tag_ids.size
      end
    end

    def apply_import!(simulation, run)
      created_employees = []
      total_steps = simulation.fetch(:actionable_count)
      done_count = 0

      simulation.fetch(:importable_records).each do |record|
        employee = import_record!(record, simulation.fetch(:tags))
        created_employees << employee
        done_count += 1
        update_collection_progress(run, done_count, total_steps)
      end

      existing_employees = Employee.where(national_id: simulation.fetch(:existing_national_ids)).includes(:tags).order(:id).to_a
      existing_employees_requiring_tags(existing_employees, simulation.fetch(:tags)).each do |employee|
        simulation.fetch(:tags).each do |tag|
          employee.tags << tag unless employee.tags.include?(tag)
        end
        done_count += 1
        update_collection_progress(run, done_count, total_steps)
      end

      created_employees
    end

    def import_record!(record, tags)
      Employee.create!(
        first_name: record.first_name,
        last_name: record.last_name,
        national_id: record.national_id,
        email: record.email,
        phone: record.phone,
        active: true
      ).tap do |employee|
        employee.tags = tags
      end
    end

    def deliver_employee_welcome_emails(employees)
      employee_ids = employees.filter_map { |employee| employee.id if employee.email.present? }
      EmployeeWelcomeDeliveryJob.perform_later(employee_ids) if employee_ids.any?
    end

    def import_completed_message(importable_records, existing_tag_update_count)
      imported_count = importable_records.size

      if imported_count.positive? && existing_tag_update_count.positive?
        return I18n.t("admin.flash.import_completed_with_existing_tags",
          created_count: imported_count,
          tagged_count: existing_tag_update_count)
      end

      if existing_tag_update_count.positive?
        return I18n.t("admin.flash.import_existing_tags_updated", count: existing_tag_update_count)
      end

      I18n.t("admin.flash.import_completed", count: imported_count)
    end

    ImportRecord = Data.define(:first_name, :last_name, :national_id, :email, :phone)
  end
end
