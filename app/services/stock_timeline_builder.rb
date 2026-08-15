# frozen_string_literal: true

class StockTimelineBuilder
  Row = Struct.new(:kind, :id, :sort_on, :record, keyword_init: true)
  KIND_ORDER = { "exit" => 0, "line_change" => 1, "entry" => 2 }.freeze

  class << self
    def build(stock:, trade_type:, judgment_type:, ai_script_id: nil)
      positions = position_scope(stock:, trade_type:, judgment_type:, ai_script_id:).includes(:trade_events)
                    .order(opened_at: :desc, id: :desc)
      groups = positions.map { |position| { position: position, rows: rows_for(position) } }
      rows = groups.flat_map { |g| g[:rows] }
      open_pos = positions.find(&:open?)
      line = current_line_from(open_pos)
      {
        rows: rows,
        groups: groups,
        current_line: line,
        position: position_hash(open_pos)
      }
    end

    def current_line(stock:, trade_type:, judgment_type:, ai_script_id: nil, on_or_after: nil)
      stock.current_line(trade_type:, judgment_type:, ai_script_id:, on_or_after:)
    end

    private

    def position_scope(stock:, trade_type:, judgment_type:, ai_script_id:)
      scope = stock.positions.where(trade_type: trade_type, judgment_type: judgment_type)
      if judgment_type.to_s == "ai" && ai_script_id.present?
        scope.where(ai_script_id: ai_script_id)
      elsif judgment_type.to_s == "human"
        scope.where(ai_script_id: nil)
      else
        scope
      end
    end

    def rows_for(position)
      rows = position.trade_events.map do |event|
        Row.new(
          kind: event.kind,
          id: event.id,
          sort_on: event.traded_at&.to_s || event.created_at.to_date.to_s,
          record: event
        )
      end
      rows.sort! do |a, b|
        date_cmp = b.sort_on.to_s <=> a.sort_on.to_s
        next date_cmp unless date_cmp.zero?

        kind_cmp = KIND_ORDER.fetch(a.kind, 9) <=> KIND_ORDER.fetch(b.kind, 9)
        next kind_cmp unless kind_cmp.zero?

        b.id.to_i <=> a.id.to_i
      end
      rows
    end

    def current_line_from(position)
      return nil if position.blank?

      line = position.trade_events.select(&:line_change?).max_by { |e| [ e.executed_at, e.id ] }
      return nil if line.blank?

      line
    end

    def position_hash(position)
      return { shares: 0, avg_price: nil, opened_on: nil } if position.blank?

      {
        shares: position.quantity,
        avg_price: position.average_cost,
        opened_on: position.opened_at&.in_time_zone&.to_date,
        record: position
      }
    end
  end
end
