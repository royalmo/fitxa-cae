class Tag < ApplicationRecord
  has_and_belongs_to_many :employees

  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  validates :name, :color, presence: true
  validates :name, uniqueness: { case_sensitive: false }
  validates :active, inclusion: { in: [ true, false ] }
end
