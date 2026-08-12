# frozen_string_literal: true

class CreateStockWatchItems < ActiveRecord::Migration[8.1]
  def change
    create_table :stock_watch_items do |t|
      t.references :stock_watch_batch, null: false, foreign_key: true
      t.references :stock, null: false, foreign_key: true
      t.string :source_label, null: false, limit: 100
      t.timestamps
    end

    add_index :stock_watch_items, [ :stock_watch_batch_id, :stock_id ], unique: true,
              name: "index_stock_watch_items_on_batch_and_stock"
  end
end
