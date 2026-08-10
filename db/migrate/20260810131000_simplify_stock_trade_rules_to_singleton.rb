# frozen_string_literal: true

class SimplifyStockTradeRulesToSingleton < ActiveRecord::Migration[8.1]
  def up
    remove_index :stock_trade_rules, :title if index_exists?(:stock_trade_rules, :title)

    keep_id = select_value("SELECT id FROM stock_trade_rules ORDER BY id ASC LIMIT 1")
    if keep_id
      execute("DELETE FROM stock_trade_rules WHERE id <> #{connection.quote(keep_id)}")
    end
  end

  def down
    add_index :stock_trade_rules, :title, unique: true unless index_exists?(:stock_trade_rules, :title)
  end
end
