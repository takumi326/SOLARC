# frozen_string_literal: true

require "rails_helper"

RSpec.describe StockWatchlistImporter do
  it "imports multiple TradingView list files into one batch" do
    create_test_stock(code: "2871", name: "ニチレイ")
    create_test_stock(code: "5444", name: "大和工業")
    create_test_stock(code: "5406", name: "神戸鋼")

    dir = Dir.mktmpdir
    path1 = File.join(dir, "ロング_押し目_2cf6d.txt")
    path2 = File.join(dir, "ロング_高値ブレイク_ab665.txt")
    File.write(path1, "TSE:2871,TSE:5444")
    File.write(path2, "TSE:5406,TSE:9999")

    travel_to Time.zone.local(2026, 8, 8, 10, 0, 0) do
      result = described_class.import!(
        files: [
          Rack::Test::UploadedFile.new(path1, "text/plain"),
          Rack::Test::UploadedFile.new(path2, "text/plain")
        ],
        imported_on: Date.new(2026, 8, 8),
        starts_on: Date.new(2026, 8, 10),
        ends_on: Date.new(2026, 8, 14)
      )

      expect(result.imported_count).to eq(3)
      expect(result.missing_codes).to eq([ "9999" ])
      expect(result.source_labels).to contain_exactly("ロング_押し目", "ロング_高値ブレイク")
      expect(result.batch.watch_period_label).to eq("8/10〜8/14")
      expect(Stock.find_by!(code: "2871").watched?).to eq(false)
    end

    travel_to Time.zone.local(2026, 8, 11, 10, 0, 0) do
      StockWatchBatch.sync_watched_flags!
      expect(Stock.find_by!(code: "2871").watched?).to eq(true)
      expect(Stock.find_by!(code: "5406").watched?).to eq(true)
    end
  ensure
    FileUtils.remove_entry(dir) if dir && Dir.exist?(dir)
  end

  it "builds a source label from the filename" do
    expect(described_class.label_from_filename("ロング_押し目_2cf6d.txt")).to eq("ロング_押し目")
    expect(described_class.label_from_filename("watch.txt")).to eq("watch")
  end
end
