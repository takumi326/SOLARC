# frozen_string_literal: true

module Api
  class StockTradeEventsController < ApplicationController
    include ApiDecimalJson

    def index
      trade_type = require_enum!(params[:trade_type], %w[real virtual])
      return if performed?

      judgment_type = require_enum!(params[:judgment_type], %w[human ai])
      return if performed?

      ai_script_id = parse_optional_id(params[:ai_script_id])
      event_kind = (params[:event_kind].presence || "all").to_s
      unless %w[all entry exit].include?(event_kind)
        render json: { error: { code: "bad_request", message: "event_kind は all / entry / exit です" } }, status: :bad_request
        return
      end

      settled = (params[:settled].presence || "all").to_s
      unless %w[all yes no].include?(settled)
        render json: { error: { code: "bad_request", message: "settled は all / yes / no です" } }, status: :bad_request
        return
      end

      from_d = parse_optional_date(params[:from])
      to_d = parse_optional_date(params[:to])

      stock_scope = Stock.all
      stock_scope = stock_scope.search_by_term(params[:q]) if params[:q].present?
      stock_sub = stock_scope.select(:id)

      rows = []
      exit_scope_for_pl = StockExit.none

      if event_kind != "exit"
        es = Entry.where(stock_id: stock_sub).where(trade_type: trade_type, judgment_type: judgment_type)
        es = apply_ai_axis!(es, judgment_type: judgment_type, ai_script_id: ai_script_id)
        es = apply_settled_scope(es, settled, traded_col: :traded_at)
        es = apply_date_range_entries(es, from_d, to_d)
        es = es.includes(:stock)
        es.find_each do |e|
          rows << build_row("entry", e, sort_on_entry(e), e.stock)
        end
      end

      if event_kind != "entry"
        xs = StockExit.where(stock_id: stock_sub).where(trade_type: trade_type, judgment_type: judgment_type)
        xs = apply_ai_axis!(xs, judgment_type: judgment_type, ai_script_id: ai_script_id)
        xs = apply_settled_scope(xs, settled, traded_col: :traded_at)
        xs = apply_date_range_exits(xs, from_d, to_d)
        xs = xs.includes(:stock)
        exit_scope_for_pl = xs
        xs.find_each do |x|
          rows << build_row("exit", x, sort_on_exit(x), x.stock)
        end
      end

      if event_kind == "all"
        ls = LineChange.where(stock_id: stock_sub).where(trade_type: trade_type, judgment_type: judgment_type)
        ls = apply_ai_axis!(ls, judgment_type: judgment_type, ai_script_id: ai_script_id)
        ls = apply_line_settled(ls, settled)
        ls = apply_date_range_lines(ls, from_d, to_d)
        ls = ls.includes(:stock)
        ls.find_each do |l|
          rows << build_row("line_change", l, l.changed_on.to_s, l.stock)
        end
      end

      rows.sort_by! { |r| [ r[:sort_on].to_s, r[:id].to_i ] }
      rows.reverse!

      total_pl =
        if event_kind != "entry"
          StockRealizedPl.total_for_exits(filter_exits_for_pl(exit_scope_for_pl, judgment_type, ai_script_id))
        else
          BigDecimal("0")
        end

      render json: {
        data: {
          rows: rows,
          total_realized_pl: decimal_json(total_pl)
        }
      }
    end

    private

    def require_enum!(value, allowed)
      v = value.to_s
      unless allowed.include?(v)
        render json: { error: { code: "bad_request", message: "不正なパラメータです" } }, status: :bad_request
        return nil
      end
      v
    end

    def parse_optional_id(v)
      return nil if v.blank?

      Integer(v)
    rescue ArgumentError, TypeError
      nil
    end

    def parse_optional_date(v)
      return nil if v.blank?

      Date.iso8601(v.to_s)
    rescue ArgumentError
      nil
    end

    def apply_ai_axis!(rel, judgment_type:, ai_script_id:)
      if judgment_type.to_s == "ai" && ai_script_id.present?
        rel.where(ai_script_id: ai_script_id)
      elsif judgment_type.to_s == "human"
        rel.where(ai_script_id: nil)
      else
        rel
      end
    end

    def apply_settled_scope(rel, settled, traded_col:)
      case settled
      when "yes"
        rel.where.not(traded_col => nil)
      when "no"
        rel.where(traded_col => nil)
      else
        rel
      end
    end

    def apply_line_settled(rel, settled)
      case settled
      when "no"
        rel.none
      else
        rel
      end
    end

    def apply_date_range_entries(rel, from_d, to_d)
      rel = rel.where("COALESCE(entries.traded_at, DATE(entries.created_at)) >= ?", from_d) if from_d
      rel = rel.where("COALESCE(entries.traded_at, DATE(entries.created_at)) <= ?", to_d) if to_d
      rel
    end

    def apply_date_range_exits(rel, from_d, to_d)
      rel = rel.where("COALESCE(exits.traded_at, DATE(exits.created_at)) >= ?", from_d) if from_d
      rel = rel.where("COALESCE(exits.traded_at, DATE(exits.created_at)) <= ?", to_d) if to_d
      rel
    end

    def apply_date_range_lines(rel, from_d, to_d)
      rel = rel.where("line_changes.changed_on >= ?", from_d) if from_d
      rel = rel.where("line_changes.changed_on <= ?", to_d) if to_d
      rel
    end

    def sort_on_entry(e)
      (e.traded_at || e.created_at.to_date).to_s
    end

    def sort_on_exit(x)
      (x.traded_at || x.created_at.to_date).to_s
    end

    def build_row(kind, record, sort_on, stock)
      sk = { id: stock.id, code: stock.code, name: stock.name }
      case kind
      when "entry"
        { kind: kind, id: record.id, sort_on: sort_on, stock: sk }.merge(entry_fields(record))
      when "exit"
        { kind: kind, id: record.id, sort_on: sort_on, stock: sk }.merge(exit_fields(record))
      when "line_change"
        { kind: kind, id: record.id, sort_on: sort_on, stock: sk }.merge(line_change_fields(record))
      else
        { kind: kind, id: record.id, sort_on: sort_on, stock: sk }
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

    def filter_exits_for_pl(scope, judgment_type, ai_script_id)
      return scope if judgment_type.to_s == "human"

      return scope.where(ai_script_id: ai_script_id) if ai_script_id.present?

      scope
    end
  end
end
