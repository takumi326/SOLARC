class Forecast < ApplicationRecord
  enum :kind, { expense: 0, income: 1 }, prefix: true

  validates :kind, :month, :amount, presence: true
  validates :month, uniqueness: { scope: :kind }
end
