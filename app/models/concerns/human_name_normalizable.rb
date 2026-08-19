module HumanNameNormalizable
  extend ActiveSupport::Concern

  included do
    before_validation :normalize_human_name_attributes
  end

  class_methods do
    def normalize_human_name(value)
      normalized_value = value.to_s.squish
      return nil if normalized_value.blank?

      normalized_value.downcase.gsub(/\p{L}+/) do |word|
        word.sub(/\A\p{L}/) { |first_letter| first_letter.upcase }
      end
    end
  end

  private

  def normalize_human_name_attributes
    normalize_human_name_attribute(:first_name)
    normalize_human_name_attribute(:last_name)
  end

  def normalize_human_name_attribute(attribute)
    return unless has_attribute?(attribute)
    return unless new_record? || will_save_change_to_attribute?(attribute)

    self[attribute] = self.class.normalize_human_name(self[attribute])
  end
end
