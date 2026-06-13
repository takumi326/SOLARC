# frozen_string_literal: true

module Api
  class StockTradeEventsController < ApplicationController
    include ApiDecimalJson

    def index
      result = StockTradeEventsQuery.call(params)
      rows = result.rows.map { |row| build_json_row(row) }
      render json: {
        data: {
          rows: rows,
          total_realized_pl: decimal_json(result.total_realized_pl)
        }
      }
    rescue ArgumentError => e
      render json: { error: { code: "bad_request", message: e.message } }, status: :bad_request
    end

    private

    def build_json_row(row)
      sk = { id: row.stock.id, code: row.stock.code, name: row.stock.name }
      base = { kind: row.kind, id: row.id, sort_on: row.sort_on, stock: sk }
      case row.kind
      when "entry"
        base.merge(entry_fields(row.record))
      when "exit"
        base.merge(exit_fields(row.record))
      when "line_change"
        base.merge(line_change_fields(row.record))
      else
        base
      end
    end

    def entry_fields(e)
      {
        stock_id: e.stock_id,
        trade_type: e.trade_type,
        judgment_type: e.judgment_type,
        ai_script_id: e.ai_script_id,
        expected_price: e.expected_price&.to_s("F"),
        actual_price: e.actual_price&.to_s("F"),
        shares: e.shares,
        traded_at: e.traded_at&.iso8601,
        entry_reason: e.entry_reason,
        scenario: e.scenario,
        memo: e.memo,
        created_at: e.created_at.iso8601,
        updated_at: e.updated_at.iso8601
      }
    end

    def exit_fields(x)
      {
        stock_id: x.stock_id,
        trade_type: x.trade_type,
        judgment_type: x.judgment_type,
        ai_script_id: x.ai_script_id,
        expected_price: x.expected_price&.to_s("F"),
        actual_price: x.actual_price&.to_s("F"),
        shares: x.shares,
        traded_at: x.traded_at&.iso8601,
        exit_reason: x.exit_reason,
        review_result: x.review_result,
        review_missed: x.review_missed,
        review_learning: x.review_learning,
        memo: x.memo,
        created_at: x.created_at.iso8601,
        updated_at: x.updated_at.iso8601
      }
    end

    def line_change_fields(l)
      {
        stock_id: l.stock_id,
        trade_type: l.trade_type,
        judgment_type: l.judgment_type,
        ai_script_id: l.ai_script_id,
        changed_on: l.changed_on.iso8601,
        stop_loss: l.stop_loss&.to_s("F"),
        target_price: l.target_price&.to_s("F"),
        reason: l.reason,
        created_at: l.created_at.iso8601,
        updated_at: l.updated_at.iso8601
      }
    end
  end
end
