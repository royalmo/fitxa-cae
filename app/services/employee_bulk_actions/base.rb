module EmployeeBulkActions
  class Base
    BOOLEAN = ActiveModel::Type::Boolean.new

    class << self
      def normalized_national_ids(raw_national_ids)
        raise Errors::InvalidNationalIds unless raw_national_ids.is_a?(Array)
        raise Errors::InvalidNationalIds if raw_national_ids.empty?

        normalized_national_ids = raw_national_ids.map do |national_id|
          raise Errors::InvalidNationalIds.new(national_id.inspect) unless national_id.is_a?(String)

          normalized_national_id = Employee.normalize_national_id(national_id)
          invalid_national_id = normalized_national_id.blank? || !Employee.valid_national_id?(normalized_national_id)
          raise Errors::InvalidNationalIds.new(normalized_national_id || national_id) if invalid_national_id

          normalized_national_id
        end

        raise_duplicated_national_ids!(normalized_national_ids)

        normalized_national_ids
      end

      def tag_ids(raw_tag_ids)
        Array(raw_tag_ids).compact_blank.map(&:to_i).uniq
      end

      def boolean(raw_value)
        BOOLEAN.cast(raw_value)
      end

      private

      def raise_duplicated_national_ids!(national_ids)
        counts = national_ids.tally
        duplicated_national_id = national_ids.find { |national_id| counts.fetch(national_id) > 1 }

        return unless duplicated_national_id

        raise Errors::DuplicateNationalIds.new(duplicated_national_id, counts.fetch(duplicated_national_id))
      end
    end

    private

    def update_collection_progress(run, done_count, total_count, from: 15, to: 95)
      return if total_count.zero?

      progress = from + ((done_count.to_f / total_count) * (to - from)).round
      progress = [ [ progress, to ].min, from ].max
      run.update!(progress: progress) if progress > run.progress
    end
  end
end
