class PaymentMethod < ApplicationRecord
  has_many :expenses, dependent: :restrict_with_exception

  LEDGER_CHARGE_TIMINGS = %w[same_month next_month].freeze

  validates :name, presence: true
  validates :method_type, presence: true, inclusion: { in: %w[card bank_debit bank_withdrawal] }
  validates :closing_day, inclusion: { in: 1..31, allow_nil: true }
  validates :debit_day, inclusion: { in: 1..31, allow_nil: true }
  validates :ledger_charge_timing, inclusion: { in: LEDGER_CHARGE_TIMINGS, allow_nil: true }

  before_validation :normalize_schedule_for_method_type

  # 支出マスタの「対象月」（同期した暦月）に対し、台帳 Transaction.month をどうするか
  def ledger_month_for_expense_accrual(accrual_month)
    m = accrual_month.beginning_of_month
    return m unless method_type.in?(%w[card bank_debit])

    expense_ledgers_next_month? ? m.next_month.beginning_of_month : m
  end

  def expense_ledgers_next_month?
    return false unless method_type.in?(%w[card bank_debit])

    timing = self[:ledger_charge_timing]
    timing.nil? || timing == "next_month"
  end

  private

  def normalize_schedule_for_method_type
    case method_type
    when "card"
      self.closing_day = nil
      self.debit_day = nil
      self.ledger_charge_timing ||= "next_month"
    when "bank_debit"
      self.closing_day = nil
      self.debit_day = nil
      self.ledger_charge_timing ||= "same_month"
    when "bank_withdrawal"
      self.closing_day = nil
      self.debit_day = nil
      self.ledger_charge_timing = nil
    end
  end
end
