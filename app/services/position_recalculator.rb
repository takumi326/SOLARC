# frozen_string_literal: true

class PositionRecalculator
  def initialize(position)
    @position = position
  end

  def call
    qty = 0
    avg = BigDecimal("0")
    pnl = BigDecimal("0")

    closing_at = nil
    @position.trade_events.chronological.each do |event|
      case event.kind.to_sym
      when :entry
        next unless event.settled?

        new_qty = qty + event.quantity
        avg = ((avg * qty) + (event.actual_price.to_d * event.quantity)) / new_qty
        qty = new_qty
      when :exit
        next unless event.settled?

        pnl += (event.actual_price.to_d - avg) * event.quantity
        qty -= event.quantity
        closing_at = event.executed_at if qty.zero?
      end
    end

    qty = 0 if qty.negative?
    @position.update!(
      quantity: qty,
      average_cost: avg.zero? && qty.zero? ? nil : avg,
      realized_pnl: pnl,
      status: qty.zero? ? :closed : :open,
      closed_at: qty.zero? ? closing_at : nil
    )
    @position
  end
end
