# frozen_string_literal: true

class Stock < ApplicationRecord
  TRADINGVIEW_CHART_ID = "g045YVx7"

  belongs_to :industry
  has_many :stock_notes, dependent: :destroy
  has_many :entries, dependent: :destroy
  has_many :stock_exits, class_name: "StockExit", dependent: :destroy
  has_many :line_changes, dependent: :destroy
  has_many :positions, dependent: :destroy
  has_many :trade_events, dependent: :destroy
  has_many :stock_watch_items, dependent: :destroy
  has_many :stock_watch_batches, through: :stock_watch_items

  validates :code, presence: true, uniqueness: true, length: { maximum: 10 }
  validates :name, presence: true, length: { maximum: 200 }

  scope :ordered, -> { order(:code) }

  scope :with_entries, lambda {
    where(id: TradeEvent.entry.select(:stock_id).distinct)
  }

  scope :with_real_human_entries, lambda {
    where(id: TradeEvent.entry.real.human.select(:stock_id))
  }

  scope :with_virtual_entries, lambda {
    where(id: virtual_entry_scope.select(:stock_id))
  }

  scope :watched, -> { where(watched: true) }

  scope :watched_in_period, lambda { |starts_on, ends_on|
    where(id: StockWatchItem.joins(:stock_watch_batch)
      .merge(StockWatchBatch.overlapping(starts_on, ends_on))
      .select(:stock_id))
  }

  scope :entered_in_period, lambda { |starts_on, ends_on|
    where(id: TradeEvent.entry.real.human.dated_between(starts_on, ends_on).select(:stock_id))
  }

  scope :virtual_entered_in_period, lambda { |starts_on, ends_on|
    where(id: virtual_entry_scope.dated_between(starts_on, ends_on).select(:stock_id))
  }

  # AI 取引がオミットのときは仮想でも人間判断のみを対象にする
  def self.virtual_entry_scope
    AiTradeFeatures.enabled? ? TradeEvent.entry.virtual : TradeEvent.entry.virtual.human
  end

  scope :with_period_flags, lambda { |starts_on, ends_on|
    watched_sql = watched_in_period_exists_sql(starts_on, ends_on)
    entered_sql = entered_in_period_exists_sql(starts_on, ends_on)
    select("stocks.*", "(EXISTS (#{watched_sql})) AS period_watched", "(EXISTS (#{entered_sql})) AS period_entered")
  }

  scope :with_current_flags, lambda {
    entered_sql = TradeEvent.entry.real.human.where("trade_events.stock_id = stocks.id").select("1").to_sql
    select("stocks.*", "stocks.watched AS period_watched", "(EXISTS (#{entered_sql})) AS current_entered")
  }

  def self.watched_in_period_exists_sql(starts_on, ends_on)
    StockWatchItem.joins(:stock_watch_batch)
      .where("stock_watch_items.stock_id = stocks.id")
      .merge(StockWatchBatch.overlapping(starts_on, ends_on))
      .select("1")
      .to_sql
  end

  def self.entered_in_period_exists_sql(starts_on, ends_on)
    TradeEvent.entry.real.human
      .where("trade_events.stock_id = stocks.id")
      .dated_between(starts_on, ends_on)
      .select("1")
      .to_sql
  end

  scope :with_real_holdings, lambda {
    where(id: Position.open.real.human.where("quantity > 0").select(:stock_id))
  }

  scope :search_by_term, lambda { |q|
    next all if q.blank?

    p = "%#{ActiveRecord::Base.sanitize_sql_like(q.to_s)}%"
    where("stocks.code ILIKE :p OR stocks.name ILIKE :p", p: p)
  }

  def self.tradingview_url(code)
    c = code.to_s.strip
    "https://jp.tradingview.com/chart/#{TRADINGVIEW_CHART_ID}/?symbol=TSE%3A#{c}"
  end

  def tradingview_url
    self.class.tradingview_url(code)
  end

  # 実取引の保有株数（約定済み entry / exit のみ）
  def holding_shares_real
    holding_shares_for(trade_type: :real, judgment_type: :human)
  end

  def holding_shares_virtual_human
    holding_shares_for(trade_type: :virtual, judgment_type: :human, ai_script_id: nil)
  end

  def holding_shares_virtual_ai(ai_script_id: nil)
    holding_shares_for(trade_type: :virtual, judgment_type: :ai, ai_script_id: ai_script_id)
  end

  def holding_shares_for(trade_type:, judgment_type:, ai_script_id: nil)
    scope = positions.open.public_send(trade_type).public_send(judgment_type)
    if judgment_type.to_s == "ai" && ai_script_id.present?
      scope = scope.where(ai_script_id: ai_script_id)
    elsif judgment_type.to_s == "human"
      scope = scope.where(ai_script_id: nil)
    end
    scope.sum(:quantity)
  end

  def currently_watched?(on: Time.zone.today)
    stock_watch_items.joins(:stock_watch_batch).merge(StockWatchBatch.covering(on)).exists?
  end

  def current_line(trade_type:, judgment_type:, ai_script_id: nil, on_or_after: nil)
    pos = positions.open.public_send(trade_type).public_send(judgment_type)
    pos = pos.where(ai_script_id: ai_script_id) if judgment_type.to_s == "ai"
    pos = pos.where(ai_script_id: nil) if judgment_type.to_s == "human"
    open_pos = pos.order(opened_at: :desc, id: :desc).first
    return nil if open_pos.blank?

    line = open_pos.trade_events.line_change.chronological.last
    return nil if line.blank?
    return nil if on_or_after.present? && line.traded_at.present? && line.traded_at < on_or_after

    line
  end
end
