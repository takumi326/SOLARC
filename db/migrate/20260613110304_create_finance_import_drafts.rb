class CreateFinanceImportDrafts < ActiveRecord::Migration[8.1]
  def change
    create_table :finance_import_drafts do |t|
      t.string :owner_key, null: false
      t.text :raw_json
      t.jsonb :pending_rows, null: false, default: []
      t.jsonb :selected_lines, null: false, default: []
      t.string :compare_month
      t.string :phase, null: false, default: "edit"

      t.timestamps
    end
    add_index :finance_import_drafts, :owner_key, unique: true
  end
end
