# frozen_string_literal: true

class CreateStockSettings < ActiveRecord::Migration[8.0]
  def change
    create_table :stock_settings do |t|
      t.string :tradingview_chart_id, null: false, default: "8WvKf6oB", limit: 40
      t.timestamps
    end
  end
end
