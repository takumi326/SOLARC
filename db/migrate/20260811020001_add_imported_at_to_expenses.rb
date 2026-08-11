# frozen_string_literal: true

class AddImportedAtToExpenses < ActiveRecord::Migration[8.1]
  def change
    add_column :expenses, :imported_at, :datetime
    add_index :expenses, [ :start_month, :imported_at ]
  end
end
