class Swipe < ApplicationRecord
  enum :kind, { entry: "entry", exit: "exit" }, validate: true

  belongs_to :employee

  validates :swipe_at, :kind, presence: true
  validates :removed, :forged, inclusion: { in: [ true, false ] }
end
