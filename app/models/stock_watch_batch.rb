# frozen_string_literal: true

class StockWatchBatch < ApplicationRecord
  has_many :stock_watch_items, dependent: :destroy
  has_many :stocks, through: :stock_watch_items

  validates :imported_on, :starts_on, :ends_on, presence: true
  validate :ends_on_not_before_starts_on

  scope :imported_between, ->(range) { where(imported_on: range) }
  scope :covering, ->(date) { where("starts_on <= ? AND ends_on >= ?", date, date) }
  # 期間は片側だけの指定も許す（開始のみ = それ以降 / 終了のみ = それ以前）
  scope :overlapping, lambda { |starts_on, ends_on|
    scope = all
    scope = scope.where(ends_on: starts_on..) if starts_on.present?
    scope = scope.where(starts_on: ..ends_on) if ends_on.present?
    scope
  }
  scope :recent, -> { order(imported_on: :desc, id: :desc) }

  def watch_period_label
    if starts_on == ends_on
      starts_on.strftime("%-m/%-d")
    else
      "#{starts_on.strftime('%-m/%-d')}〜#{ends_on.strftime('%-m/%-d')}"
    end
  end

  def source_labels
    stock_watch_items
      .pluck(:source_label)
      .flat_map { |label| label.to_s.split(" / ") }
      .map(&:strip)
      .reject(&:blank?)
      .uniq
      .sort
  end

  # 平日はその日、土日は翌月曜（次の取引日）。
  def self.effective_watch_date(from_date = Time.zone.today)
    date = from_date.to_date
    date.saturday? || date.sunday? ? date.next_occurring(:monday) : date
  end

  # 平日の取込 → その週の月〜金。土日（休日ルーチン）→ 翌週の月〜金。
  def self.default_watch_range(from_date = Time.zone.today)
    monday = effective_watch_date(from_date).beginning_of_week(:monday)
    monday..(monday + 4)
  end

  def self.sync_watched_flags!
    active_ids = StockWatchItem
      .joins(:stock_watch_batch)
      .merge(covering(Time.zone.today))
      .distinct
      .pluck(:stock_id)

    Stock.where(watched: true).where.not(id: active_ids).update_all(watched: false)
    Stock.where(id: active_ids, watched: false).update_all(watched: true)
  end

  private

  def ends_on_not_before_starts_on
    return if starts_on.blank? || ends_on.blank?
    return if ends_on >= starts_on

    errors.add(:ends_on, "は開始日以降にしてください")
  end
end
