# frozen_string_literal: true

require "rails_helper"

RSpec.describe DailyRoutineStatus do
  describe "#day_status" do
    it "ignores month-end import when coloring the calendar" do
      travel_to Time.zone.local(2026, 9, 1, 10, 0, 0) do
        create(:expense, start_month: Date.new(2026, 8, 1), imported_at: Time.zone.local(2026, 9, 1, 9, 0, 0))

        status = described_class.new(owner_key: "development", date: Date.new(2026, 9, 1))

        expect(status.day_status).to eq(:incomplete)
      end
    end

    it "marks a weekday complete when daily notes are filled" do
      travel_to Time.zone.local(2026, 8, 14, 10, 0, 0) do
        StockDailyNote.create!(
          owner_key: "development",
          recorded_on: Date.new(2026, 8, 14),
          hypothesis: "仮説",
          result: "結果"
        )

        status = described_class.new(owner_key: "development", date: Date.new(2026, 8, 14))

        expect(status.day_status).to eq(:complete)
      end
    end

    it "requires watched stocks only when that check is selected" do
      travel_to Time.zone.local(2026, 8, 14, 10, 0, 0) do
        pref = UserPreference.create!(owner_key: "development")
        DailyRoutineItem::TOGGLEABLE_SLOTS.each do |slot|
          pref.set_daily_routine_completion_checks!(slot, %w[daily_note watched_stocks])
        end
        StockDailyNote.create!(
          owner_key: "development",
          recorded_on: Date.new(2026, 8, 14),
          hypothesis: "仮説",
          result: "結果"
        )

        status = described_class.new(owner_key: "development", date: Date.new(2026, 8, 14))

        expect(status.day_status).to eq(:incomplete)

        create_test_watch_period(stock: create_test_stock)
        status = described_class.new(owner_key: "development", date: Date.new(2026, 8, 14))
        expect(status.day_status).to eq(:complete)
      end
    end

    it "ignores a disabled morning slot when coloring the calendar" do
      travel_to Time.zone.local(2026, 8, 14, 10, 0, 0) do
        UserPreference.create!(owner_key: "development", weekday_morning_routine_enabled: false)
        StockDailyNote.create!(
          owner_key: "development",
          recorded_on: Date.new(2026, 8, 14),
          result: "結果"
        )

        status = described_class.new(owner_key: "development", date: Date.new(2026, 8, 14))

        expect(status.day_status).to eq(:complete)
        expect(status.call.map(&:slot)).not_to include("weekday_morning")
      end
    end

    it "treats a weekday as none when both morning and evening are off" do
      travel_to Time.zone.local(2026, 8, 14, 10, 0, 0) do
        UserPreference.create!(
          owner_key: "development",
          weekday_morning_routine_enabled: false,
          weekday_evening_routine_enabled: false
        )

        status = described_class.new(owner_key: "development", date: Date.new(2026, 8, 14))

        expect(status.day_status).to eq(:none)
      end
    end

    it "does not apply slot off or watched-stocks checks to past dates" do
      travel_to Time.zone.local(2026, 8, 21, 10, 0, 0) do
        UserPreference.create!(owner_key: "development", weekday_evening_routine_enabled: false)
        StockDailyNote.create!(
          owner_key: "development",
          recorded_on: Date.new(2026, 8, 14),
          hypothesis: "仮説",
          result: "結果"
        )

        status = described_class.new(owner_key: "development", date: Date.new(2026, 8, 14))

        expect(status.day_status).to eq(:complete)
        expect(status.call.map(&:slot)).to include("weekday_morning", "weekday_evening")
        expect(status.call.find { |slot| slot.slot == "weekday_morning" }.completion_checks.map(&:key))
          .to eq([ :daily_note ])
      end
    end
  end
end
