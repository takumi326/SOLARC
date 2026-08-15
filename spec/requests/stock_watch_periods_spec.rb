# frozen_string_literal: true

require "rails_helper"

RSpec.describe "StockWatchPeriods", type: :request do
  it "adds a watch period for a stock" do
    stock = create_test_stock

    travel_to Time.zone.local(2026, 8, 13, 10, 0, 0) do
      expect {
        post stock_stock_watch_periods_path(stock), params: {
          starts_on: "2026-08-17",
          ends_on: "2026-08-21"
        }
      }.to change(StockWatchBatch, :count).by(1)

      expect(response).to redirect_to(stock_path(stock))
      follow_redirect!
      expect(response.body).to include("8/17〜8/21")
      expect(stock.reload.watched?).to eq(false)
    end

    travel_to Time.zone.local(2026, 8, 18, 10, 0, 0) do
      StockWatchBatch.sync_watched_flags!
      expect(stock.reload.watched?).to eq(true)
    end
  end

  it "deletes a watch period" do
    stock = create_test_stock
    batch = create_test_watch_period(stock: stock, starts_on: Date.new(2026, 8, 17), ends_on: Date.new(2026, 8, 21))
    item = batch.stock_watch_items.find_by!(stock: stock)

    expect {
      delete stock_stock_watch_period_path(stock, item)
    }.to change(StockWatchItem, :count).by(-1)

    expect(response).to redirect_to(stock_path(stock))
  end

  it "updates a watch period" do
    stock = create_test_stock
    batch = create_test_watch_period(stock: stock, starts_on: Date.new(2026, 8, 10), ends_on: Date.new(2026, 8, 14))
    item = batch.stock_watch_items.find_by!(stock: stock)

    patch stock_stock_watch_period_path(stock, item), params: {
      starts_on: "2026-08-17",
      ends_on: "2026-08-21"
    }

    expect(response).to redirect_to(stock_path(stock))
    follow_redirect!
    expect(response.body).to include("8/17〜8/21")
    expect(batch.reload.starts_on).to eq(Date.new(2026, 8, 17))
    expect(batch.reload.ends_on).to eq(Date.new(2026, 8, 21))
  end
end
