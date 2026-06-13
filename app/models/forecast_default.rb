class ForecastDefault < ApplicationRecord
  validates :expense_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :income_amount, numericality: { greater_than_or_equal_to: 0 }

  def self.instance
    first || create!(expense_amount: 200_000, income_amount: 335_000)
  end
end
