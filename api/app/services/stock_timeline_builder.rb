# frozen_string_literal: true

class StockTimelineBuilder
  Row = Struct.new(:kind, :id, :sort_on, :record, keyword_init: true)

  class << self
    def build(stock:, trade_type:, judgment_type:, ai_script_id: nil)
      rows = timeline_rows(stock:, trade_type:, judgment_type:, ai_script_id:)
      line = current_line(stock:, trade_type:, judgment_type:, ai_script_id:)
      { rows: rows, current_line: line }
    end

    def timeline_rows(stock:, trade_type:, judgment_type:, ai_script_id: nil)
      es = stock.entries.where(trade_type: trade_type, judgment_type: judgment_type)
      xs = stock.stock_exits.where(trade_type: trade_type, judgment_type: judgment_type)
      ls = stock.line_changes.where(trade_type: trade_type, judgment_type: judgment_type)
      es, xs, ls = apply_ai_axis!(es, xs, ls, judgment_type:, ai_script_id:)

      rows = []
      es.find_each { |e| rows << Row.new(kind: "entry", id: e.id, sort_on: sort_date_for_entry(e), record: e) }
      xs.find_each { |x| rows << Row.new(kind: "exit", id: x.id, sort_on: sort_date_for_exit(x), record: x) }
      ls.find_each { |l| rows << Row.new(kind: "line_change", id: l.id, sort_on: l.changed_on.to_s, record: l) }

      rows.sort_by! { |r| [ r.sort_on.to_s, r.id.to_i ] }
      rows.reverse!
      rows
    end

    def current_line(stock:, trade_type:, judgment_type:, ai_script_id: nil)
      if judgment_type.to_s == "ai" && ai_script_id.present?
        stock.current_line(trade_type: trade_type, judgment_type: judgment_type, ai_script_id: ai_script_id)
      else
        stock.current_line(trade_type: trade_type, judgment_type: judgment_type)
      end
    end

    private

    def apply_ai_axis!(es, xs, ls, judgment_type:, ai_script_id:)
      if judgment_type.to_s == "ai" && ai_script_id.present?
        [ es.where(ai_script_id: ai_script_id), xs.where(ai_script_id: ai_script_id), ls.where(ai_script_id: ai_script_id) ]
      elsif judgment_type.to_s == "human"
        [ es.where(ai_script_id: nil), xs.where(ai_script_id: nil), ls.where(ai_script_id: nil) ]
      else
        [ es, xs, ls ]
      end
    end

    def sort_date_for_entry(e)
      (e.traded_at || e.created_at.to_date).to_s
    end

    def sort_date_for_exit(x)
      (x.traded_at || x.created_at.to_date).to_s
    end
  end
end
