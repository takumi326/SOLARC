# 定期マスタに紐づく台帳取引のうち、指定月以降の金額を一括で揃え、マスタ金額も更新する（以降の同期に反映）
class BulkUpdateMasterActualsFromMonthService
  Result = Struct.new(:updated_count, keyword_init: true)

  def self.call(master:, from_month:, amount:, negative:)
    new(master:, from_month:, amount:, negative:).call
  end

  def initialize(master:, from_month:, amount:, negative:)
    @master = master
    @from_month = parse_month(from_month)
    @amount = amount.to_d
    @negative = negative
  end

  def call
    raise ArgumentError, "amount must be >= 0" if @amount.negative?

    updated_count = 0
    ActiveRecord::Base.transaction do
      each_target_transaction do |tx|
        tx.update!(amount: signed_amount)
        updated_count += 1
      end
      @master.update!(amount: @amount.abs)
    end

    Result.new(updated_count:)
  end

  private

  def parse_month(value)
    Date.parse(value.to_s).beginning_of_month
  rescue Date::Error
    raise ArgumentError, "from_month is invalid"
  end

  def signed_amount
    @negative ? -@amount.abs : @amount.abs
  end

  def each_target_transaction
    join_scope.find_each do |row|
      yield row.ledger_transaction
    end
  end

  def join_scope
    if @master.is_a?(Expense)
      @master.expense_transactions
             .joins(:ledger_transaction)
             .includes(:ledger_transaction)
             .where(transactions: { month: @from_month.. })
    else
      @master.income_transactions
             .joins(:ledger_transaction)
             .includes(:ledger_transaction)
             .where(transactions: { month: @from_month.. })
    end
  end
end
