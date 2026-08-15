# frozen_string_literal: true

class TradeEventRegistrar
  def initialize(stock:)
    @stock = stock
  end

  def call(kind:, executed_at: nil, **attrs)
    attrs = attrs.symbolize_keys
    attrs[:trade_type] ||= "real"
    attrs[:judgment_type] ||= "human"
    axis = {
      trade_type: attrs[:trade_type],
      judgment_type: attrs[:judgment_type],
      ai_script_id: attrs[:ai_script_id]
    }

    Position.transaction do
      at = executed_at || Time.current
      position = covering_position(at, **axis)

      case kind.to_sym
      when :entry
        position ||= @stock.positions.create!(
          axis.merge(
            opened_at: at,
            initial_stop: attrs[:initial_stop] || attrs[:stop_loss],
            initial_target: attrs[:initial_target] || attrs[:take_profit] || attrs[:target_price]
          )
        )
      when :exit, :line_change
        if position.nil?
          event = TradeEvent.new(kind: kind, stock: @stock, executed_at: executed_at, **attrs.except(:initial_stop, :initial_target))
          event.errors.add(:base, "建玉が存在しません。先にエントリーを登録してください")
          raise ActiveRecord::RecordInvalid, event
        end
      end

      event_attrs = attrs.except(:initial_stop, :initial_target, :target_price, :executed_at)
      if attrs.key?(:take_profit) || attrs.key?(:target_price)
        event_attrs[:take_profit] = attrs[:take_profit] || attrs[:target_price]
      end

      event = @stock.trade_events.create!(
        event_attrs.merge(position: position, kind: kind, executed_at: executed_at)
      )
      PositionRecalculator.new(position.reload).call
      event
    end
  end

  private

  def covering_position(at, trade_type:, judgment_type:, ai_script_id: nil)
    @stock.positions.where(
      trade_type: trade_type,
      judgment_type: judgment_type,
      ai_script_id: ai_script_id
    ).where("opened_at <= ?", at)
     .where("closed_at IS NULL OR closed_at >= ?", at)
     .order(opened_at: :desc, id: :desc)
     .first
  end
end
