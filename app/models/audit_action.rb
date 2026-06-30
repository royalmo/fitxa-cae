class AuditAction < ApplicationRecord
  belongs_to :author, polymorphic: true
  belongs_to :recipient, polymorphic: true

  validates :kind, presence: true
end
