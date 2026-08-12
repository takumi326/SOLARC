# frozen_string_literal: true

class StockWatchlistsController < ApplicationController
  def new
    @imported_on = parse_date(params[:date]) || Time.zone.today
    range = StockWatchBatch.default_watch_range(@imported_on)
    @starts_on = range.begin
    @ends_on = range.end
  end

  def create
    files = Array(params[:files]).flatten.compact.select { |f| f.respond_to?(:read) }
    imported_on = parse_date(params[:imported_on]) || Time.zone.today
    starts_on = parse_date(params[:starts_on])
    ends_on = parse_date(params[:ends_on])

    if starts_on.blank? || ends_on.blank?
      redirect_to new_stock_watchlist_path, alert: "監視期間を指定してください。"
      return
    end

    result = StockWatchlistImporter.import!(
      files: files,
      imported_on: imported_on,
      starts_on: starts_on,
      ends_on: ends_on
    )

    notice = "#{result.imported_count}件を監視リストに取り込みました（#{result.batch.watch_period_label}）。"
    notice += " 未登録コードをスキップ: #{result.missing_codes.join(', ')}" if result.missing_codes.any?

    redirect_to daily_routine_path(date: imported_on.iso8601), notice: notice
  rescue ArgumentError => e
    redirect_to new_stock_watchlist_path, alert: e.message
  rescue StandardError => e
    Rails.logger.error("[StockWatchlistImporter] #{e.class}: #{e.message}")
    redirect_to new_stock_watchlist_path, alert: "監視リストの取り込みに失敗しました。"
  end

  private

  def parse_date(value)
    return if value.blank?

    Date.iso8601(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end
