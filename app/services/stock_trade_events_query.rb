# frozen_string_literal: true

class StockTradeEventsQuery
  Result = Struct.new(:rows, :total_realized_pl, keyword_init: true)
  Row = Struct.new(:kind, :id, :sort_on, :stock, :record, keyword_init: true)
  KIND_ORDER = { "exit" => 0, "line_change" => 1, "entry" => 2 }.freeze

  class << self
    def call(params)
      new(params).call
    end
  end

  def initialize(params)
    @params = params
  end

  def call
    trade_type = require_enum!(@params[:trade_type], %w[real virtual])
    judgment_type = require_enum!(@params[:judgment_type], %w[human ai])
    event_kind = (@params[:event_kind].presence || "all").to_s
    raise ArgumentError, "event_kind は all / entry / exit です" unless %w[all entry exit].include?(event_kind)

    settled = (@params[:settled].presence || "all").to_s
    raise ArgumentError, "settled は all / yes / no / none です" unless %w[all yes no none].include?(settled)

    ai_script_id = parse_optional_id(@params[:ai_script_id])
    from_d = parse_optional_date(@params[:from])
    to_d = parse_optional_date(@params[:to])

    stock_scope = Stock.all
    stock_scope = stock_scope.search_by_term(@params[:q]) if @params[:q].present?
    stock_sub = stock_scope.select(:id)

    rel = TradeEvent.where(stock_id: stock_sub).where(trade_type: trade_type, judgment_type: judgment_type)
    rel = apply_ai_axis!(rel, judgment_type:, ai_script_id:)
    rel = rel.where.not(kind: :line_change)
    rel = rel.where(kind: :entry) if event_kind == "entry"
    rel = rel.where(kind: :exit) if event_kind == "exit"
    rel = apply_settled_scope(rel, settled)
    rel = apply_date_range(rel, from_d, to_d)

    rows = rel.includes(:stock).to_a.map do |event|
      build_row(event.kind, event, event.traded_at&.to_s || event.created_at.to_date.to_s, event.stock)
    end

    rows.sort! do |a, b|
      date_cmp = b.sort_on.to_s <=> a.sort_on.to_s
      next date_cmp unless date_cmp.zero?

      kind_cmp = KIND_ORDER.fetch(a.kind, 9) <=> KIND_ORDER.fetch(b.kind, 9)
      next kind_cmp unless kind_cmp.zero?

      a.id.to_i <=> b.id.to_i
    end

    total_pl =
      if event_kind != "entry"
        Position.where(stock_id: stock_sub, trade_type: trade_type, judgment_type: judgment_type).sum(:realized_pnl)
      else
        BigDecimal("0")
      end

    Result.new(rows: rows, total_realized_pl: total_pl)
  end

  private

  def require_enum!(value, allowed)
    v = value.to_s
    raise ArgumentError, "不正なパラメータです" unless allowed.include?(v)

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

  def apply_settled_scope(rel, settled)
    case settled
    when "yes" then rel.where.not(actual_price: nil).where.not(quantity: nil)
    when "no" then rel.where(actual_price: nil)
    when "none" then rel.none
    else rel
    end
  end

  def apply_date_range(rel, from_d, to_d)
    rel = rel.where("trade_events.executed_at >= ?", from_d.in_time_zone.beginning_of_day) if from_d
    rel = rel.where("trade_events.executed_at <= ?", to_d.in_time_zone.end_of_day) if to_d
    rel
  end

  def build_row(kind, record, sort_on, stock)
    Row.new(kind: kind, id: record.id, sort_on: sort_on, stock: stock, record: record)
  end
end
