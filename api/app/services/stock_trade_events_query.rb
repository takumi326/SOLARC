# frozen_string_literal: true

class StockTradeEventsQuery
  Result = Struct.new(:rows, :total_realized_pl, keyword_init: true)
  Row = Struct.new(:kind, :id, :sort_on, :stock, :record, keyword_init: true)

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
    raise ArgumentError, "settled は all / yes / no です" unless %w[all yes no].include?(settled)

    ai_script_id = parse_optional_id(@params[:ai_script_id])
    from_d = parse_optional_date(@params[:from])
    to_d = parse_optional_date(@params[:to])

    stock_scope = Stock.all
    stock_scope = stock_scope.search_by_term(@params[:q]) if @params[:q].present?
    stock_sub = stock_scope.select(:id)

    rows = []
    exit_scope_for_pl = StockExit.none

    if event_kind != "exit"
      es = Entry.where(stock_id: stock_sub).where(trade_type: trade_type, judgment_type: judgment_type)
      es = apply_ai_axis!(es, judgment_type:, ai_script_id:)
      es = apply_settled_scope(es, settled, traded_col: :traded_at)
      es = apply_date_range_entries(es, from_d, to_d)
      es.includes(:stock).find_each do |e|
        rows << build_row("entry", e, sort_on_entry(e), e.stock)
      end
    end

    if event_kind != "entry"
      xs = StockExit.where(stock_id: stock_sub).where(trade_type: trade_type, judgment_type: judgment_type)
      xs = apply_ai_axis!(xs, judgment_type:, ai_script_id:)
      xs = apply_settled_scope(xs, settled, traded_col: :traded_at)
      xs = apply_date_range_exits(xs, from_d, to_d)
      exit_scope_for_pl = xs
      xs.includes(:stock).find_each do |x|
        rows << build_row("exit", x, sort_on_exit(x), x.stock)
      end
    end

    if event_kind == "all"
      ls = LineChange.where(stock_id: stock_sub).where(trade_type: trade_type, judgment_type: judgment_type)
      ls = apply_ai_axis!(ls, judgment_type:, ai_script_id:)
      ls = apply_line_settled(ls, settled)
      ls = apply_date_range_lines(ls, from_d, to_d)
      ls.includes(:stock).find_each do |l|
        rows << build_row("line_change", l, l.changed_on.to_s, l.stock)
      end
    end

    rows.sort_by! { |r| [ r.sort_on.to_s, r.id.to_i ] }
    rows.reverse!

    total_pl =
      if event_kind != "entry"
        StockRealizedPl.total_for_exits(filter_exits_for_pl(exit_scope_for_pl, judgment_type, ai_script_id))
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

  def apply_settled_scope(rel, settled, traded_col:)
    case settled
    when "yes" then rel.where.not(traded_col => nil)
    when "no" then rel.where(traded_col => nil)
    else rel
    end
  end

  def apply_line_settled(rel, settled)
    settled == "no" ? rel.none : rel
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
    Row.new(kind: kind, id: record.id, sort_on: sort_on, stock: stock, record: record)
  end

  def filter_exits_for_pl(scope, judgment_type, ai_script_id)
    return scope if judgment_type.to_s == "human"
    return scope.where(ai_script_id: ai_script_id) if ai_script_id.present?

    scope
  end
end
