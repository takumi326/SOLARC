class MinorCategory < ApplicationRecord
  belongs_to :major_category

  has_many :expenses, dependent: :restrict_with_exception
  has_many :incomes, dependent: :restrict_with_exception

  validates :name, presence: true
end
