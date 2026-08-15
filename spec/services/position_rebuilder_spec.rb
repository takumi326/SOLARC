# frozen_string_literal: true

require "rails_helper"

RSpec.describe PositionRebuilder do
  let(:stock) { create_test_stock }
  let(:registrar) { TradeEventRegistrar.new(stock: stock) }

  def record(kind, **attrs)
    day = attrs.delete(:on) || Date.current
    registrar.call(kind: kind, executed_at: Time.zone.local(day.year, day.month, day.day, 12, 0, attrs.delete(:sec) || 0), **attrs)
  end

  it "binds same-day entry, line change, and exit to one position" do
    e = record(:entry, quantity: 100, actual_price: 1000, entry_reason: "e", on: Date.current, sec: 1, initial_stop: 900)
    l = record(:line_change, stop_loss: 950, take_profit: 1200, on: Date.current, sec: 2)
    x = record(:exit, quantity: 100, actual_price: 1100, exit_reason: "x", on: Date.current, sec: 3)

    expect([ e, l, x ].map(&:position_id).uniq.size).to eq(1)
  end

  it "opens a new position after a full exit then re-entry" do
    record(:entry, quantity: 100, actual_price: 1000, entry_reason: "e1", on: Date.current, sec: 1)
    record(:exit, quantity: 100, actual_price: 1100, exit_reason: "x", on: Date.current, sec: 2)
    e2 = record(:entry, quantity: 50, actual_price: 900, entry_reason: "e2", on: Date.current, sec: 3)

    expect(stock.positions.count).to eq(2)
    expect(e2.position).to eq(stock.positions.order(:id).last)
  end

  it "updates average cost with add-on entries" do
    record(:entry, quantity: 100, actual_price: 1000, entry_reason: "e1")
    record(:entry, quantity: 50, actual_price: 1300, entry_reason: "e2")

    expect(stock.positions.open.first.average_cost).to eq(BigDecimal("1100"))
  end

  it "rejects an exit larger than holdings" do
    record(:entry, quantity: 100, actual_price: 1000, entry_reason: "e")
    expect {
      record(:exit, quantity: 101, actual_price: 1000, exit_reason: "x")
    }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "rejects a line change without a position" do
    expect {
      record(:line_change, stop_loss: 900)
    }.to raise_error(ActiveRecord::RecordInvalid, /建玉が存在しません/)
  end

  it "rebuilds position boundaries after an entry quantity edit" do
    e1 = record(:entry, quantity: 100, actual_price: 1000, entry_reason: "e1", on: Date.new(2026, 1, 1))
    record(:exit, quantity: 40, actual_price: 1100, exit_reason: "x", on: Date.new(2026, 1, 2))
    record(:entry, quantity: 10, actual_price: 900, entry_reason: "e2", on: Date.new(2026, 1, 3))
    expect(stock.positions.count).to eq(1)

    e1.update_columns(quantity: 40)
    described_class.new(stock).call

    expect(stock.positions.count).to eq(2)
    expect(stock.positions.order(:opened_at, :id).last.quantity).to eq(10)
  end

  it "is idempotent" do
    record(:entry, quantity: 100, actual_price: 1000, entry_reason: "e", initial_stop: 800)
    record(:line_change, stop_loss: 850)
    record(:exit, quantity: 100, actual_price: 1100, exit_reason: "x")

    described_class.new(stock).call
    ids = stock.positions.order(:opened_at, :id).pluck(:id, :quantity, :status, :realized_pnl)
    described_class.new(stock).call
    expect(stock.positions.order(:opened_at, :id).pluck(:quantity, :status, :realized_pnl)).to eq(ids.map { |r| r[1..] })
  end

  it "calculates R-multiple from the first line setting" do
    record(:entry, quantity: 100, actual_price: 1000, entry_reason: "e")
    record(:line_change, stop_loss: 900)
    record(:line_change, stop_loss: 950)
    record(:exit, quantity: 100, actual_price: 1100, exit_reason: "x")
    pos = stock.positions.closed.first

    expect(pos.risk_per_share).to eq(100)
    expect(pos.r_multiple).to eq(1)
  end

  it "does not change initial_stop after a later line change" do
    record(:entry, quantity: 100, actual_price: 1000, entry_reason: "e", initial_stop: 900)
    record(:line_change, stop_loss: 950)
    pos = stock.positions.open.first

    expect(pos.initial_stop).to eq(BigDecimal("900"))
    expect(pos.current_stop).to eq(BigDecimal("950"))
  end

  it "does not attach a line change dated before the current position opened" do
    record(:entry, quantity: 100, actual_price: 3480, entry_reason: "e1", on: Date.new(2026, 8, 1))
    record(:exit, quantity: 100, actual_price: 2222, exit_reason: "x", on: Date.new(2026, 8, 13))
    e2 = record(:entry, quantity: 100, actual_price: 20_000, entry_reason: "e2", on: Date.new(2026, 8, 15))

    expect {
      record(:line_change, stop_loss: 100, on: Date.new(2026, 8, 14))
    }.to raise_error(ActiveRecord::RecordInvalid, /建玉が存在しません/)

    expect(e2.position.trade_events.line_change).to be_empty
  end

  it "does not attach a line change after the closing exit" do
    record(:entry, quantity: 100, actual_price: 3480, entry_reason: "e", on: Date.new(2026, 8, 1))
    x = record(:exit, quantity: 100, actual_price: 2222, exit_reason: "x", on: Date.new(2026, 8, 13))

    expect {
      record(:line_change, stop_loss: 11, on: Date.new(2026, 8, 14))
    }.to raise_error(ActiveRecord::RecordInvalid, /建玉が存在しません/)

    expect(x.position.trade_events.line_change).to be_empty
    expect(x.position.closed_at.to_date).to eq(Date.new(2026, 8, 13))
  end
end
