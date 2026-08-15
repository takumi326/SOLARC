# frozen_string_literal: true

class TradeEvent < ApplicationRecord
  include StockTradeAxes
  include PairedSettlementFields
  include OptionalDecimalFields

  belongs_to :position, optional: true

  enum :kind, { entry: 0, exit: 1, line_change: 2 }, validate: true

  alias_attribute :shares, :quantity
  alias_attribute :target_price, :take_profit

  validates :executed_at, presence: true, if: -> { actual_price.present? || line_change? }
  validates :entry_reason, presence: true, if: :entry?
  validates :exit_reason, presence: true, if: :exit?
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates_optional_decimal :expected_price, :actual_price, :stop_loss, :take_profit

  validate :position_must_be_open_for_non_entry
  validate :exit_quantity_within_holding

  before_save :ensure_executed_at

  scope :chronological, -> { order(:executed_at, :id) }
  scope :for_position, -> { where(kind: [ :entry, :exit ]).where.not(quantity: nil).where.not(actual_price: nil) }
  scope :dated_between, lambda { |starts_on, ends_on|
    rel = all
    rel = rel.where("trade_events.executed_at >= ?", starts_on.in_time_zone.beginning_of_day) if starts_on.present?
    rel = rel.where("trade_events.executed_at <= ?", ends_on.in_time_zone.end_of_day) if ends_on.present?
    rel
  }

  def traded_at
    executed_at&.in_time_zone&.to_date
  end

  def traded_at=(value)
    assign_executed_at_from_date(value)
  end

  def changed_on
    traded_at
  end

  def changed_on=(value)
    assign_executed_at_from_date(value)
  end

  def settled?
    !line_change? && actual_price.present? && quantity.to_i.positive?
  end

  private

  def ensure_executed_at
    self.executed_at ||= Time.current
  end

  def assign_executed_at_from_date(value)
    if value.blank?
      self.executed_at = nil
      return
    end

    date = value.to_date
    now = Time.current
    self.executed_at = Time.zone.local(date.year, date.month, date.day, now.hour, now.min, now.sec)
  end

  def expected_or_actual_price_present
    return if line_change?

    super
  end

  def settlement_price_and_date_together
    return if line_change?

    super
  end

  def position_must_be_open_for_non_entry
    return if entry?
    return if position.present?

    errors.add(:base, "建玉が存在しません。先にエントリーを登録してください")
  end

  def exit_quantity_within_holding
    return unless exit?
    return if position.blank?
    return if quantity.blank?

    held = position.quantity.to_i
    held += quantity_was.to_i if persisted? && kind_was == "exit"
    return if quantity.to_i <= held

    errors.add(:quantity, "保有株数(#{held})を超えています")
  end
end
