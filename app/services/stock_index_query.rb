# frozen_string_literal: true

class StockIndexQuery
  Result = Data.define(
    :stocks,
    :stock_flags,
    :q,
    :watch,
    :entry,
    :virtual,
    :period_starts_on,
    :period_ends_on,
    :period_active,
    :searching
  )

  class << self
    def call(params)
      new(params).call
    end
  end

  def initialize(params)
    @params = params
  end

  def call
    q = @params[:q].to_s.strip
    watch, entry, virtual = parse_filter_flags
    searching = q.present?
    # 入力された日付は絞り込みに使えなくてもそのまま返す（フォームで入力値が消えないように）
    period_starts_on, period_ends_on = parse_period
    period_active = period_usable?(period_starts_on, period_ends_on)
    filter_starts_on = period_active ? period_starts_on : nil
    filter_ends_on = period_active ? period_ends_on : nil

    scope = Stock.includes(:industry)
    scope = scope.search_by_term(q) if searching
    scope = apply_visibility(scope, watch:, entry:, virtual:, searching:, period_active:,
                                    period_starts_on: filter_starts_on, period_ends_on: filter_ends_on)
    scope = apply_sort(scope, period_active:, period_starts_on: filter_starts_on, period_ends_on: filter_ends_on)

    stocks = scope.to_a
    stock_flags = build_stock_flags(stocks, period_active:, period_starts_on: filter_starts_on,
                                            period_ends_on: filter_ends_on)

    Result.new(
      stocks: stocks,
      stock_flags: stock_flags,
      q: q,
      watch: watch,
      entry: entry,
      virtual: virtual,
      period_starts_on: period_starts_on,
      period_ends_on: period_ends_on,
      period_active: period_active,
      searching: searching
    )
  end

  private

  def parse_filter_flags
    values = [ last_param(:watch), last_param(:entry), last_param(:virtual) ]
    return [ true, true, true ] if values.all?(&:nil?)

    values.map { |value| value.to_s == "1" }
  end

  def last_param(key)
    return nil unless @params.key?(key)

    value = @params[key]
    value.is_a?(Array) ? value.last : value
  end

  def parse_period
    [ parse_optional_date(@params[:period_starts_on]), parse_optional_date(@params[:period_ends_on]) ]
  end

  # 片側だけの指定も有効。開始 > 終了の場合だけ絞り込みに使わない。
  def period_usable?(starts_on, ends_on)
    return false if starts_on.blank? && ends_on.blank?
    return true if starts_on.blank? || ends_on.blank?

    starts_on <= ends_on
  end

  def parse_optional_date(value)
    return nil if value.blank?

    Date.iso8601(value.to_s)
  rescue ArgumentError
    nil
  end

  def apply_visibility(scope, watch:, entry:, virtual:, searching:, period_active:, period_starts_on:, period_ends_on:)
    return scope.none unless watch || entry || virtual
    return scope if searching && watch && entry && virtual

    sets = []
    sets << watch_set(period_active, period_starts_on, period_ends_on) if watch
    sets << entry_set(period_active, period_starts_on, period_ends_on) if entry
    sets << virtual_set(period_active, period_starts_on, period_ends_on) if virtual

    # merge だと id 条件が上書きされてしまうため、和集合は or で組み立ててから id で絞る
    scope.where(id: sets.reduce { |combined, set| combined.or(set) }.select(:id))
  end

  def watch_set(period_active, starts_on, ends_on)
    period_active ? Stock.watched_in_period(starts_on, ends_on) : Stock.watched
  end

  def entry_set(period_active, starts_on, ends_on)
    period_active ? Stock.entered_in_period(starts_on, ends_on) : Stock.with_real_human_entries
  end

  def virtual_set(period_active, starts_on, ends_on)
    period_active ? Stock.virtual_entered_in_period(starts_on, ends_on) : Stock.with_virtual_entries
  end

  def apply_sort(scope, period_active:, period_starts_on:, period_ends_on:)
    if period_active
      scope.with_period_flags(period_starts_on, period_ends_on).order(Arel.sql("period_watched DESC, period_entered DESC, stocks.code ASC"))
    else
      scope.with_current_flags.order(Arel.sql("stocks.watched DESC, current_entered DESC, stocks.code ASC"))
    end
  end

  def build_stock_flags(stocks, period_active:, period_starts_on:, period_ends_on:)
    return {} if stocks.empty?

    if period_active
      flags_from_period_columns(stocks)
    else
      flags_from_current_state(stocks)
    end
  end

  def flags_from_period_columns(stocks)
    stocks.each_with_object({}) do |stock, hash|
      hash[stock.id] = {
        watched: ActiveRecord::Type::Boolean.new.cast(stock.read_attribute(:period_watched)),
        entered: ActiveRecord::Type::Boolean.new.cast(stock.read_attribute(:period_entered))
      }
    end
  end

  def flags_from_current_state(stocks)
    entered_ids = Entry.real.human.where(stock_id: stocks.map(&:id)).distinct.pluck(:stock_id).to_set

    stocks.each_with_object({}) do |stock, hash|
      hash[stock.id] = {
        watched: stock.watched?,
        entered: entered_ids.include?(stock.id)
      }
    end
  end
end
