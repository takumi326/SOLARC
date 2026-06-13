class Income < ApplicationRecord
  enum :income_type, { one_time: 0, recurring: 1 }, prefix: true

  belongs_to :minor_category

  has_many :income_transactions, dependent: :destroy
  has_many :transactions, through: :income_transactions, source: :ledger_transaction

  validates :income_type, :start_month, :amount, presence: true
  validates :amount, numericality: { greater_than_or_equal_to: 0 }
  validate :end_month_not_before_start_month

  before_validation :normalize_one_time_fields
  before_destroy :destroy_linked_ledger_transactions, prepend: true

  private

  def destroy_linked_ledger_transactions
    income_transactions.includes(:ledger_transaction).each do |it|
      it.ledger_transaction&.destroy!
    end
  end

  def end_month_not_before_start_month
    return if end_month.blank? || start_month.blank?
    return unless end_month < start_month

    errors.add(:end_month, "must be greater than or equal to start_month")
  end

  def normalize_one_time_fields
    return unless income_type_one_time?

    self.end_month = nil
  end
end
