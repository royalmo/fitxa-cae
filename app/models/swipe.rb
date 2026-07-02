class Swipe < ApplicationRecord
  enum :kind, { entry: "entry", exit: "exit" }, validate: true

  belongs_to :employee

  scope :kept, -> { where(removed: false) }
  scope :chronological, -> { order(:swipe_at, :id) }
  scope :for_day, ->(day) { where(swipe_at: day.all_day) }

  validates :swipe_at, :kind, presence: true
  validates :removed, :forged, inclusion: { in: [ true, false ] }
end
