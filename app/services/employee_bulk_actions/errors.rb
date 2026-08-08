module EmployeeBulkActions
  module Errors
    class InvalidNationalIds < StandardError
      attr_reader :national_id

      def initialize(national_id = nil)
        @national_id = national_id
        super()
      end
    end

    class DuplicateNationalIds < StandardError
      attr_reader :national_id, :count

      def initialize(national_id, count)
        @national_id = national_id
        @count = count
        super()
      end
    end

    class NoAffectedEmployees < StandardError; end

    class InvalidRequest < StandardError; end

    class InvalidBulkTags < StandardError; end

    class ConflictingBulkTags < StandardError; end

    class InvalidImport < StandardError
      attr_reader :translation_key, :options

      def initialize(translation_key, **options)
        @translation_key = translation_key
        @options = options
        super()
      end
    end

    class InvalidImportTags < StandardError; end
  end
end
