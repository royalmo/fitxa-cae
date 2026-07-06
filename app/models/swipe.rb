class Swipe < ApplicationRecord
  enum :kind, { entry: "entry", exit: "exit" }, validate: true

  belongs_to :employee

  scope :kept, -> { where(removed: false) }
  scope :chronological, -> { order(:swipe_at, :id) }
  scope :for_day, ->(day) { where(swipe_at: day.all_day) }

  validates :swipe_at, :kind, presence: true
  validates :removed, :forged, inclusion: { in: [ true, false ] }

  def self.paired_work_seconds(swipes)
    entry_at = nil
    total = 0

    swipes.each do |swipe|
      if swipe.entry?
        entry_at ||= swipe.swipe_at
      elsif swipe.exit? && entry_at
        total += [ swipe.swipe_at - entry_at, 0 ].max
        entry_at = nil
      end
    end

    total
  end
end
