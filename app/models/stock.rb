# frozen_string_literal: true

class Stock < ApplicationRecord
  TRADINGVIEW_CHART_ID = "g045YVx7"

  belongs_to :industry
  has_many :stock_notes, dependent: :destroy
  has_many :entries, dependent: :destroy
  has_many :stock_exits, class_name: "StockExit", dependent: :destroy
  has_many :line_changes, dependent: :destroy
  has_many :stock_watch_items, dependent: :destroy
  has_many :stock_watch_batches, through: :stock_watch_items

  validates :code, presence: true, uniqueness: true, length: { maximum: 10 }
  validates :name, presence: true, length: { maximum: 200 }

  scope :ordered, -> { order(:code) }

  scope :with_entries, lambda {
    where(id: Entry.select(:stock_id).distinct)
  }

  scope :with_real_human_entries, lambda {
    where(id: Entry.real.human.select(:stock_id))
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
    where(id: Entry.real.human.dated_between(starts_on, ends_on).select(:stock_id))
  }

  scope :virtual_entered_in_period, lambda { |starts_on, ends_on|
    where(id: virtual_entry_scope.dated_between(starts_on, ends_on).select(:stock_id))
  }

  # AI 取引がオミットのときは仮想でも人間判断のみを対象にする
  def self.virtual_entry_scope
    AiTradeFeatures.enabled? ? Entry.virtual : Entry.virtual.human
  end

  scope :with_period_flags, lambda { |starts_on, ends_on|
    watched_sql = watched_in_period_exists_sql(starts_on, ends_on)
    entered_sql = entered_in_period_exists_sql(starts_on, ends_on)
    select("stocks.*", "(EXISTS (#{watched_sql})) AS period_watched", "(EXISTS (#{entered_sql})) AS period_entered")
  }

  scope :with_current_flags, lambda {
    entered_sql = Entry.real.human.where("entries.stock_id = stocks.id").select("1").to_sql
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
    Entry.real.human
      .where("entries.stock_id = stocks.id")
      .dated_between(starts_on, ends_on)
      .select("1")
      .to_sql
  end

  scope :with_real_holdings, lambda {
    where(<<-SQL.squish)
      id IN (
        SELECT s.id FROM stocks s
        WHERE COALESCE((
          SELECT SUM(e.shares) FROM entries e
          WHERE e.stock_id = s.id AND e.trade_type = 'real' AND e.judgment_type = 'human'
            AND e.traded_at IS NOT NULL AND e.shares IS NOT NULL
        ), 0) - COALESCE((
          SELECT SUM(x.shares) FROM exits x
          WHERE x.stock_id = s.id AND x.trade_type = 'real' AND x.judgment_type = 'human'
            AND x.traded_at IS NOT NULL AND x.shares IS NOT NULL
        ), 0) > 0
      )
    SQL
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
    settled_entry_shares = entries.real.human.where.not(traded_at: nil).where.not(shares: nil).sum(:shares)
    settled_exit_shares = stock_exits.real.human.where.not(traded_at: nil).where.not(shares: nil).sum(:shares)
    settled_entry_shares - settled_exit_shares
  end

  def holding_shares_virtual_human
    holding_shares_for(trade_type: :virtual, judgment_type: :human, ai_script_id: nil)
  end

  def holding_shares_virtual_ai(ai_script_id: nil)
    scope_entries = entries.virtual.ai.where.not(traded_at: nil).where.not(shares: nil)
    scope_exits = stock_exits.virtual.ai.where.not(traded_at: nil).where.not(shares: nil)
    if ai_script_id.present?
      scope_entries = scope_entries.where(ai_script_id: ai_script_id)
      scope_exits = scope_exits.where(ai_script_id: ai_script_id)
    end
    scope_entries.where(stock_id: id).sum(:shares) - scope_exits.where(stock_id: id).sum(:shares)
  end

  def holding_shares_for(trade_type:, judgment_type:, ai_script_id: nil)
    es = entries.public_send(trade_type).public_send(judgment_type).where.not(traded_at: nil).where.not(shares: nil)
    xs = stock_exits.public_send(trade_type).public_send(judgment_type).where.not(traded_at: nil).where.not(shares: nil)
    if judgment_type.to_s == "ai" && ai_script_id.present?
      es = es.where(ai_script_id: ai_script_id)
      xs = xs.where(ai_script_id: ai_script_id)
    end
    es.sum(:shares) - xs.sum(:shares)
  end

  def current_line(trade_type:, judgment_type:, ai_script_id: nil)
    scope = line_changes.public_send(trade_type).public_send(judgment_type)
    scope = scope.where(ai_script_id: ai_script_id) if judgment_type.to_s == "ai"
    scope = scope.where(ai_script_id: nil) if judgment_type.to_s == "human"
    scope.order(changed_on: :desc, id: :desc).first
  end
end
