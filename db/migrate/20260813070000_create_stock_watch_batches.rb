# frozen_string_literal: true

class CreateStockWatchBatches < ActiveRecord::Migration[8.1]
  def change
    create_table :stock_watch_batches do |t|
      t.date :imported_on, null: false
      t.date :starts_on, null: false
      t.date :ends_on, null: false
      t.timestamps
    end

    add_index :stock_watch_batches, :imported_on
    add_index :stock_watch_batches, [ :starts_on, :ends_on ]
  end
end
