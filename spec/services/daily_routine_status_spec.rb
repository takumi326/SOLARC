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
  end
end
