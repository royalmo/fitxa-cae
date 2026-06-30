class Tag < ApplicationRecord
  has_and_belongs_to_many :employees

  validates :name, :color, presence: true
  validates :active, inclusion: { in: [ true, false ] }
end
