class CreateStockTradeRules < ActiveRecord::Migration[8.1]
  def change
    create_table :stock_trade_rules do |t|
      t.string :title, null: false, limit: 100
      t.text :body, null: false

      t.timestamps
    end
    add_index :stock_trade_rules, :title, unique: true
  end
end
