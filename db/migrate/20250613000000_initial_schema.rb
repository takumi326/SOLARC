class InitialSchema < ActiveRecord::Migration[8.1]
  def change
    create_table :major_categories do |t|
      t.integer :kind, null: false, default: 0
      t.string :name, limit: 100, null: false
      t.timestamps
    end
    add_index :major_categories, [ :kind, :name ], unique: true
    add_check_constraint :major_categories, "kind IN (0, 1)", name: "major_categories_kind_check"

    create_table :minor_categories do |t|
      t.references :major_category, null: false, foreign_key: true
      t.string :name, limit: 100, null: false
      t.timestamps
    end
    add_index :minor_categories, [ :major_category_id, :name ], unique: true

    create_table :payment_methods do |t|
      t.string :name, limit: 100, null: false
      t.string :method_type, limit: 20, null: false, default: "card"
      t.integer :closing_day
      t.integer :debit_day
      t.string :ledger_charge_timing, limit: 20
      t.timestamps
    end
    add_index :payment_methods, :name, unique: true
    add_check_constraint :payment_methods, "method_type IN ('card', 'bank_debit', 'bank_withdrawal')", name: "payment_methods_method_type_check"
    add_check_constraint :payment_methods, "closing_day IS NULL OR (closing_day >= 1 AND closing_day <= 31)", name: "payment_methods_closing_day_check"
    add_check_constraint :payment_methods, "debit_day IS NULL OR (debit_day >= 1 AND debit_day <= 31)", name: "payment_methods_debit_day_check"
    add_check_constraint :payment_methods, "ledger_charge_timing IS NULL OR ledger_charge_timing IN ('same_month', 'next_month')", name: "payment_methods_ledger_charge_timing_check"

    create_table :expenses do |t|
      t.references :minor_category, null: false, foreign_key: true
      t.references :payment_method, null: false, foreign_key: true
      t.integer :expense_type, null: false, default: 0
      t.integer :recurring_cycle, null: false, default: 0
      t.integer :renewal_month
      t.decimal :amount, precision: 15, scale: 0, null: false, default: 0
      t.date :start_month, null: false
      t.date :end_month
      t.text :memo
      t.timestamps
    end
    add_index :expenses, :expense_type
    add_index :expenses, :start_month
    add_index :expenses, :end_month
    add_check_constraint :expenses, "expense_type IN (0, 1)", name: "expenses_expense_type_check"
    add_check_constraint :expenses, "recurring_cycle IN (0, 1)", name: "expenses_recurring_cycle_check"
    add_check_constraint :expenses, "renewal_month IS NULL OR (renewal_month >= 1 AND renewal_month <= 12)", name: "expenses_renewal_month_check"
    add_check_constraint :expenses, "amount >= 0", name: "expenses_amount_check"

    create_table :incomes do |t|
      t.references :minor_category, null: false, foreign_key: true
      t.date :start_month, null: false
      t.integer :income_type, null: false, default: 0
      t.decimal :amount, precision: 15, scale: 0, null: false, default: 0
      t.date :end_month
      t.timestamps
    end
    add_index :incomes, :income_type
    add_index :incomes, :start_month
    add_index :incomes, :end_month
    add_check_constraint :incomes, "income_type IN (0, 1)", name: "incomes_income_type_check"
    add_check_constraint :incomes, "amount >= 0", name: "incomes_amount_check"

    create_table :forecasts do |t|
      t.integer :kind, null: false, default: 0
      t.date :month, null: false
      t.decimal :amount, precision: 15, scale: 0, null: false
      t.timestamps
    end
    add_index :forecasts, [ :month, :kind ], unique: true
    add_check_constraint :forecasts, "kind IN (0, 1)", name: "forecasts_kind_check"

    create_table :forecast_defaults do |t|
      t.decimal :expense_amount, precision: 15, scale: 0, null: false, default: 200_000
      t.decimal :income_amount, precision: 15, scale: 0, null: false, default: 335_000
      t.timestamps
    end
    add_check_constraint :forecast_defaults, "expense_amount >= 0", name: "forecast_defaults_expense_amount_check"
    add_check_constraint :forecast_defaults, "income_amount >= 0", name: "forecast_defaults_income_amount_check"

    create_table :transactions do |t|
      t.date :month, null: false
      t.decimal :amount, precision: 15, scale: 0, null: false
      t.timestamps
    end
    add_index :transactions, :month

    create_table :expense_transactions do |t|
      t.references :expense, null: false, foreign_key: true
      t.references :transaction, null: false, foreign_key: true, index: { unique: true }
      t.timestamps
    end

    create_table :income_transactions do |t|
      t.references :income, null: false, foreign_key: true
      t.references :transaction, null: false, foreign_key: true, index: { unique: true }
      t.timestamps
    end

    create_table :monthly_balances do |t|
      t.date :month, null: false
      t.decimal :amount, precision: 15, scale: 0, null: false
      t.timestamps
    end
    add_index :monthly_balances, :month, unique: true

    create_table :user_preferences do |t|
      t.string :owner_key, limit: 255, null: false
      t.text :import_claude_prompt_template
      t.text :stock_daily_hypothesis_prompt
      t.text :stock_daily_result_prompt
      t.text :stock_daily_sector_prompt
      t.timestamps
    end
    add_index :user_preferences, :owner_key, unique: true

    create_table :stock_daily_notes do |t|
      t.string :owner_key, limit: 255, null: false
      t.date :recorded_on, null: false
      t.text :hypothesis
      t.text :result
      t.text :sector_research
      t.timestamps
    end
    add_index :stock_daily_notes, [ :owner_key, :recorded_on ], unique: true

    create_table :industries do |t|
      t.string :name, limit: 100, null: false
      t.timestamps
    end
    add_index :industries, :name, unique: true

    create_table :stocks do |t|
      t.string :code, limit: 10, null: false
      t.string :name, limit: 200, null: false
      t.references :industry, null: false, foreign_key: true
      t.text :memo
      t.timestamps
    end
    add_index :stocks, :code, unique: true

    create_table :stock_notes do |t|
      t.references :stock, null: false, foreign_key: true
      t.date :noted_on, null: false
      t.string :title, limit: 200, null: false, default: ""
      t.text :note, null: false
      t.timestamps
    end
    add_index :stock_notes, [ :stock_id, :noted_on ]

    create_table :ai_scripts do |t|
      t.string :version_name, limit: 100, null: false
      t.text :prompt
      t.timestamps
    end
    add_index :ai_scripts, :version_name, unique: true

    create_table :entries do |t|
      t.references :stock, null: false, foreign_key: true
      t.string :trade_type, limit: 20, null: false
      t.string :judgment_type, limit: 20, null: false
      t.references :ai_script, foreign_key: true
      t.decimal :expected_price, precision: 12, scale: 2
      t.decimal :actual_price, precision: 12, scale: 2
      t.integer :shares
      t.date :traded_at
      t.text :entry_reason, null: false
      t.text :scenario
      t.text :memo
      t.timestamps
    end
    add_index :entries, [ :stock_id, :trade_type, :judgment_type ], name: "index_entries_on_stock_trade_judgment"
    add_check_constraint :entries, "trade_type IN ('real', 'virtual')", name: "entries_trade_type_check"
    add_check_constraint :entries, "judgment_type IN ('human', 'ai')", name: "entries_judgment_type_check"

    create_table :exits do |t|
      t.references :stock, null: false, foreign_key: true
      t.string :trade_type, limit: 20, null: false
      t.string :judgment_type, limit: 20, null: false
      t.references :ai_script, foreign_key: true
      t.decimal :expected_price, precision: 12, scale: 2
      t.decimal :actual_price, precision: 12, scale: 2
      t.integer :shares
      t.date :traded_at
      t.text :exit_reason, null: false
      t.string :review_result, limit: 20
      t.text :review_missed
      t.text :review_learning
      t.text :memo
      t.timestamps
    end
    add_index :exits, [ :stock_id, :trade_type, :judgment_type ], name: "index_exits_on_stock_trade_judgment"
    add_check_constraint :exits, "trade_type IN ('real', 'virtual')", name: "exits_trade_type_check"
    add_check_constraint :exits, "judgment_type IN ('human', 'ai')", name: "exits_judgment_type_check"
    add_check_constraint :exits, "review_result IS NULL OR review_result IN ('as_planned', 'missed', 'partial')", name: "exits_review_result_check"

    create_table :line_changes do |t|
      t.references :stock, null: false, foreign_key: true
      t.string :trade_type, limit: 20, null: false
      t.string :judgment_type, limit: 20, null: false
      t.references :ai_script, foreign_key: true
      t.date :changed_on, null: false
      t.decimal :stop_loss, precision: 12, scale: 2
      t.decimal :target_price, precision: 12, scale: 2
      t.text :reason
      t.timestamps
    end
    add_index :line_changes, [ :stock_id, :trade_type, :judgment_type, :changed_on ], name: "index_line_changes_on_stock_trade_judgment_changed"
    add_check_constraint :line_changes, "trade_type IN ('real', 'virtual')", name: "line_changes_trade_type_check"
    add_check_constraint :line_changes, "judgment_type IN ('human', 'ai')", name: "line_changes_judgment_type_check"
  end
end
