# frozen_string_literal: true

class StockWatchPeriodsController < ApplicationController
  before_action :set_stock
  before_action :set_item, only: [ :edit, :update, :destroy ]

  def new
    range = StockWatchBatch.default_watch_range(Time.zone.today)
    @starts_on = range.begin
    @ends_on = range.end
  end

  def create
    starts_on, ends_on = parsed_period_or_redirect(new_stock_stock_watch_period_path(@stock))
    return if starts_on.nil?

    ActiveRecord::Base.transaction do
      batch = StockWatchBatch.create!(
        imported_on: Time.zone.today,
        starts_on: starts_on,
        ends_on: ends_on
      )
      StockWatchItem.create!(
        stock_watch_batch: batch,
        stock: @stock,
        source_label: "手動"
      )
      StockWatchBatch.sync_watched_flags!
    end

    redirect_to stock_path(@stock), notice: "監視期間を追加しました。"
  rescue StandardError => e
    Rails.logger.error("[StockWatchPeriods#create] #{e.class}: #{e.message}")
    redirect_to new_stock_stock_watch_period_path(@stock), alert: "監視期間の追加に失敗しました。"
  end

  def edit
    batch = @item.stock_watch_batch
    @starts_on = batch.starts_on
    @ends_on = batch.ends_on
  end

  def update
    starts_on, ends_on = parsed_period_or_redirect(edit_stock_stock_watch_period_path(@stock, @item))
    return if starts_on.nil?

    batch = @item.stock_watch_batch
    ActiveRecord::Base.transaction do
      if batch.stock_watch_items.where.not(id: @item.id).exists?
        new_batch = StockWatchBatch.create!(
          imported_on: Time.zone.today,
          starts_on: starts_on,
          ends_on: ends_on
        )
        @item.update!(stock_watch_batch: new_batch)
      else
        batch.update!(starts_on: starts_on, ends_on: ends_on)
      end
      StockWatchBatch.sync_watched_flags!
    end

    redirect_to stock_path(@stock), notice: "監視期間を保存しました。"
  rescue StandardError => e
    Rails.logger.error("[StockWatchPeriods#update] #{e.class}: #{e.message}")
    redirect_to edit_stock_stock_watch_period_path(@stock, @item), alert: "監視期間の保存に失敗しました。"
  end

  def destroy
    batch = @item.stock_watch_batch
    ActiveRecord::Base.transaction do
      @item.destroy!
      batch.destroy! if batch.stock_watch_items.reload.empty?
      StockWatchBatch.sync_watched_flags!
    end

    redirect_to stock_path(@stock), notice: "監視期間を削除しました。"
  end

  private

  def set_stock
    @stock = Stock.find(params[:stock_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to stocks_path, alert: "銘柄が見つかりません。"
  end

  def set_item
    @item = @stock.stock_watch_items.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to stock_path(@stock), alert: "監視期間が見つかりません。"
  end

  def parsed_period_or_redirect(fallback_path)
    starts_on = parse_date(params[:starts_on])
    ends_on = parse_date(params[:ends_on])

    if starts_on.blank? || ends_on.blank?
      redirect_to fallback_path, alert: "監視期間を指定してください。"
      return [ nil, nil ]
    end
    if ends_on < starts_on
      redirect_to fallback_path, alert: "監視終了日は開始日以降にしてください。"
      return [ nil, nil ]
    end

    [ starts_on, ends_on ]
  end

  def parse_date(value)
    return if value.blank?

    Date.iso8601(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end
