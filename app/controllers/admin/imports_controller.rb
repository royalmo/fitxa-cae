require "csv"

class Admin::ImportsController < Admin::BaseController
  class InvalidImport < StandardError
    attr_reader :translation_key, :options

    def initialize(translation_key, **options)
      @translation_key = translation_key
      @options = options
      super()
    end
  end

  class InvalidImportTags < StandardError; end

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

  def new
  end

  def simulate
    render json: import_simulation_payload
  rescue InvalidImport => error
    render json: { error: import_error_message(error) }, status: :unprocessable_entity
  rescue InvalidImportTags
    render json: { error: t("admin.imports.errors.invalid_tags") }, status: :unprocessable_entity
  end

  def create
    simulation = import_simulation
    importable_records = simulation.fetch(:importable_records)
    raise InvalidImport.new(:no_importable_people) if simulation.fetch(:actionable_count).zero?

    apply_import!(simulation)

    redirect_to admin_employees_path, notice: import_completed_message(importable_records, simulation.fetch(:existing_tag_update_count))
  rescue InvalidImport => error
    redirect_to new_admin_import_path, alert: import_error_message(error)
  rescue InvalidImportTags
    redirect_to new_admin_import_path, alert: t("admin.imports.errors.invalid_tags")
  end

  private

  def import_simulation_payload
    simulation = import_simulation

    {
      total_count: simulation.fetch(:records).size,
      importable_count: simulation.fetch(:importable_records).size,
      existing_count: simulation.fetch(:existing_national_ids).size,
      existing_tag_update_count: simulation.fetch(:existing_tag_update_count),
      actionable_count: simulation.fetch(:actionable_count)
    }
  end

  def import_simulation
    records = import_records
    raise_duplicated_import_national_ids!(records)

    tags = import_tags
    existing_employees = Employee.where(national_id: records.map(&:national_id)).to_a
    existing_national_ids = existing_employees.map(&:national_id)
    importable_records = records.reject { |record| existing_national_ids.include?(record.national_id) }
    existing_tag_update_count = existing_tag_update_count(existing_employees, tags)

    {
      records: records,
      importable_records: importable_records,
      existing_national_ids: existing_national_ids,
      existing_tag_update_count: existing_tag_update_count,
      actionable_count: importable_records.size + existing_tag_update_count,
      tags: tags
    }
  end

  def import_records
    rows = parsed_import_rows
    raise InvalidImport.new(:empty_data) if rows.empty?

    rows.map.with_index(1) { |row, index| import_record_from_row(row, index) }
  end

  def import_record_from_row(row, index)
    expected_column_count = import_column_count
    raise InvalidImport.new(:invalid_columns, row: index, count: expected_column_count) unless row.size == expected_column_count

    first_name, last_name, national_id, email, phone = import_columns_from_row(row)
    normalized_national_id = Employee.normalize_national_id(national_id)

    raise InvalidImport.new(:blank_name, row: index) if first_name.blank?
    raise InvalidImport.new(:invalid_national_id, row: index, national_id: national_id) if invalid_national_id?(normalized_national_id)

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
    return columns unless import_second_surname?

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
    import_second_surname? ? SECOND_SURNAME_HEADER_KEYS.size : EXPECTED_HEADER_KEYS.size
  end

  def parsed_import_rows
    content = import_content.to_s.delete_prefix("\uFEFF")
    raise InvalidImport.new(:empty_data) if content.strip.blank?

    rows = CSV.parse(content, col_sep: import_col_sep(content), liberal_parsing: true).map do |row|
      Array(row).map { |value| value.to_s.strip }
    end
    rows.reject! { |row| row.all?(&:blank?) }
    rows.shift if rows.first && header_row?(rows.first)
    rows
  rescue CSV::MalformedCSVError => error
    raise InvalidImport.new(:malformed_csv, message: error.message)
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

    raise InvalidImport.new(:duplicate_national_id,
      national_id: duplicated_national_id,
      count: counts.fetch(duplicated_national_id))
  end

  def import_content
    return params[:content] if params.key?(:content)

    source = import_source
    return params.dig(:import, :pasted_data) if source == "paste"

    params.dig(:import, :file)&.read
  end

  def import_source
    params[:source].presence || params.dig(:import, :source).presence || "paste"
  end

  def import_second_surname?
    raw_value = params.key?(:allow_second_surname) ? params[:allow_second_surname] : params.dig(:import, :allow_second_surname)

    ActiveModel::Type::Boolean.new.cast(raw_value)
  end

  def import_tags
    tag_ids = import_tag_ids
    tags = Tag.active.where(id: tag_ids).order(:name, :id).to_a
    raise InvalidImportTags if tags.size != tag_ids.size

    tags
  end

  def import_tag_ids
    raw_tag_ids = params[:tag_ids].presence || params.dig(:import, :tag_ids)

    Array(raw_tag_ids).compact_blank.map(&:to_i).uniq
  end

  def existing_tag_update_count(existing_employees, tags)
    tag_ids = tags.map(&:id)
    return 0 if existing_employees.empty? || tag_ids.empty?

    existing_tag_counts_by_employee_id = Employee
      .joins(:tags)
      .where(id: existing_employees.map(&:id), tags: { id: tag_ids })
      .group("employees.id")
      .count

    existing_employees.count do |employee|
      existing_tag_counts_by_employee_id.fetch(employee.id, 0) < tag_ids.size
    end
  end

  def apply_import!(simulation)
    Employee.transaction do
      import_records!(simulation.fetch(:importable_records), simulation.fetch(:tags))
      apply_existing_import_tags!(simulation.fetch(:existing_national_ids), simulation.fetch(:tags))
    end
  end

  def import_records!(records, tags)
    records.each do |record|
      employee = Employee.create!(
        first_name: record.first_name,
        last_name: record.last_name,
        national_id: record.national_id,
        email: record.email,
        phone: record.phone,
        active: true
      )
      employee.tags = tags
    end
  end

  def apply_existing_import_tags!(national_ids, tags)
    return if national_ids.empty? || tags.empty?

    Employee.where(national_id: national_ids).includes(:tags).find_each do |employee|
      tags.each do |tag|
        employee.tags << tag unless employee.tags.include?(tag)
      end
    end
  end

  def import_completed_message(importable_records, existing_tag_update_count)
    imported_count = importable_records.size

    if imported_count.positive? && existing_tag_update_count.positive?
      return t("admin.flash.import_completed_with_existing_tags",
        created_count: imported_count,
        tagged_count: existing_tag_update_count)
    end

    return t("admin.flash.import_existing_tags_updated", count: existing_tag_update_count) if existing_tag_update_count.positive?

    t("admin.flash.import_completed", count: imported_count)
  end

  def import_error_message(error)
    t("admin.imports.errors.#{error.translation_key}", **error.options)
  end

  ImportRecord = Data.define(:first_name, :last_name, :national_id, :email, :phone)
end
