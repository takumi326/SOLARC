class Expense < ApplicationRecord
  enum :expense_type, { one_time: 0, recurring: 1 }, prefix: true
  enum :recurring_cycle, { monthly: 0, yearly: 1 }, prefix: true

  belongs_to :minor_category
  belongs_to :payment_method

  has_many :expense_transactions, dependent: :destroy
  has_many :transactions, through: :expense_transactions, source: :ledger_transaction

  validates :expense_type, :start_month, :amount, presence: true
  validates :amount, numericality: { only_integer: true, other_than: 0 }
  validates :memo, length: { maximum: 2000 }, allow_nil: true
  validates :renewal_month, inclusion: { in: 1..12, allow_nil: true }
  validate :end_month_not_before_start_month
  validate :recurring_options

  scope :imported, -> { where.not(imported_at: nil) }

  before_validation :normalize_recurring_fields
  before_validation :strip_memo
  # dependent: :destroy が登録する before_destroy より先に台帳を消す（ET だけ消すと Transaction が残る）
  before_destroy :destroy_linked_ledger_transactions, prepend: true

  private

  def destroy_linked_ledger_transactions
    expense_transactions.includes(:ledger_transaction).each do |et|
      et.ledger_transaction&.destroy!
    end
  end

  def strip_memo
    self.memo = memo.to_s.strip.presence
  end

  def end_month_not_before_start_month
    return if end_month.blank? || start_month.blank?
    return unless end_month < start_month

    errors.add(:end_month, "must be greater than or equal to start_month")
  end

  def recurring_options
    return unless expense_type_recurring?
    return unless recurring_cycle_yearly? && renewal_month.blank?

    errors.add(:renewal_month, "must be present for yearly recurring")
  end

  def normalize_recurring_fields
    if expense_type_one_time?
      self.recurring_cycle = :monthly
      self.renewal_month = nil
      self.end_month = start_month if start_month.present?
    elsif recurring_cycle_monthly?
      self.renewal_month = nil
    end
  end
end
