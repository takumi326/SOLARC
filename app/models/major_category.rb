class MajorCategory < ApplicationRecord
  enum :kind, { expense: 0, income: 1 }, prefix: true

  has_many :minor_categories, dependent: :restrict_with_exception

  validates :name, presence: true
  validates :kind, presence: true
end
