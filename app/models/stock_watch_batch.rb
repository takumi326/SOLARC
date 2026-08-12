# frozen_string_literal: true

class StockWatchBatch < ApplicationRecord
  has_many :stock_watch_items, dependent: :destroy
  has_many :stocks, through: :stock_watch_items

  validates :imported_on, :starts_on, :ends_on, presence: true
  validate :ends_on_not_before_starts_on

  scope :imported_between, ->(range) { where(imported_on: range) }
  scope :covering, ->(date) { where("starts_on <= ? AND ends_on >= ?", date, date) }
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

  def self.default_watch_range(from_date = Time.zone.today)
    monday = from_date.to_date.next_occurring(:monday)
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
