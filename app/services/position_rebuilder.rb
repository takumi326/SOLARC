# frozen_string_literal: true

class PositionRebuilder
  def initialize(stock)
    @stock = stock
  end

  def call
    Position.transaction do
      @stock.positions.destroy_all
      qty = 0
      position = nil
      axis_key = nil

      @stock.trade_events.chronological.each do |event|
        key = [ event.trade_type, event.judgment_type, event.ai_script_id ]
        if axis_key != key
          PositionRecalculator.new(position).call if position
          qty = 0
          position = nil
          axis_key = key
        end

        if event.entry? && position.nil?
          position = @stock.positions.create!(
            stock: @stock,
            trade_type: event.trade_type,
            judgment_type: event.judgment_type,
            ai_script_id: event.ai_script_id,
            opened_at: event.executed_at,
            initial_stop: event.stop_loss,
            initial_target: event.take_profit
          )
        end

        next if position.nil?

        event.update_column(:position_id, position.id)
        if event.settled?
          qty += event.entry? ? event.quantity : (event.exit? ? -event.quantity : 0)
        end

        if qty.zero? && !event.line_change? && event.settled?
          copy_initial_line!(position)
          PositionRecalculator.new(position).call
          qty = 0
          position = nil
        end
      end

      if position
        copy_initial_line!(position)
        PositionRecalculator.new(position).call
      end
    end
  end

  private

  def copy_initial_line!(position)
    position.trade_events.reset
    first_line = position.trade_events.line_change.chronological.first
    return if first_line.blank?
    return if position.initial_stop.present? || position.initial_target.present?

    position.update_columns(
      initial_stop: first_line.stop_loss,
      initial_target: first_line.take_profit
    )
  end
end
