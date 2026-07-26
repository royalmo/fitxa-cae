class Tag < ApplicationRecord
  has_and_belongs_to_many :employees

  validates :name, :color, presence: true
  validates :name, uniqueness: { case_sensitive: false }
  validates :active, inclusion: { in: [ true, false ] }
end
