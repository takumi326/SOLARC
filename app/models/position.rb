# frozen_string_literal: true

class Position < ApplicationRecord
  include StockTradeAxes

  belongs_to :stock
  has_many :trade_events, -> { order(:executed_at, :id) }, dependent: :nullify

  enum :status, { open: 0, closed: 1 }, validate: true

  validates :opened_at, presence: true
  validates :quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def risk_per_share
    return nil if initial_stop.blank? || average_cost.blank?

    average_cost - initial_stop
  end

  def r_multiple
    return nil if risk_per_share.blank? || risk_per_share.zero?

    total = trade_events.entry.where.not(quantity: nil).sum(:quantity)
    return nil if total.zero?

    realized_pnl / (risk_per_share * total)
  end

  def current_stop
    trade_events.line_change.last&.stop_loss || initial_stop
  end

  def current_target
    trade_events.line_change.last&.take_profit || initial_target
  end

  def same_day_closed_candidates(at = Time.current)
    stock.positions.where(trade_type: trade_type, judgment_type: judgment_type, ai_script_id: ai_script_id)
         .where("status = ? OR (status = ? AND closed_at >= ?)",
                Position.statuses[:open], Position.statuses[:closed], at.beginning_of_day)
  end
end
