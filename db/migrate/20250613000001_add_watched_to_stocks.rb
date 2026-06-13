class AddWatchedToStocks < ActiveRecord::Migration[8.1]
  def change
    add_column :stocks, :watched, :boolean, null: false, default: false
  end
end
