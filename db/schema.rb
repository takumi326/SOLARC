# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_13_070001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "ai_scripts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "prompt"
    t.datetime "updated_at", null: false
    t.string "version_name", limit: 100, null: false
    t.index ["version_name"], name: "index_ai_scripts_on_version_name", unique: true
  end

  create_table "daily_routine_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "label", limit: 255, null: false
    t.string "owner_key", limit: 255, null: false
    t.integer "position", default: 0, null: false
    t.string "slot", limit: 32, null: false
    t.datetime "updated_at", null: false
    t.index ["owner_key", "slot", "position"], name: "index_daily_routine_items_on_owner_slot_position"
  end

  create_table "daily_routine_off_days", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "off_on", null: false
    t.string "owner_key", limit: 255, null: false
    t.datetime "updated_at", null: false
    t.index ["owner_key", "off_on"], name: "index_daily_routine_off_days_on_owner_key_and_off_on", unique: true
  end

  create_table "entries", force: :cascade do |t|
    t.decimal "actual_price", precision: 12, scale: 2
    t.bigint "ai_script_id"
    t.datetime "created_at", null: false
    t.text "entry_reason", null: false
    t.decimal "expected_price", precision: 12, scale: 2
    t.string "judgment_type", limit: 20, null: false
    t.text "memo"
    t.text "scenario"
    t.integer "shares"
    t.bigint "stock_id", null: false
    t.string "trade_type", limit: 20, null: false
    t.date "traded_at"
    t.datetime "updated_at", null: false
    t.index ["ai_script_id"], name: "index_entries_on_ai_script_id"
    t.index ["stock_id", "trade_type", "judgment_type"], name: "index_entries_on_stock_trade_judgment"
    t.index ["stock_id"], name: "index_entries_on_stock_id"
    t.check_constraint "judgment_type::text = ANY (ARRAY['human'::character varying::text, 'ai'::character varying::text])", name: "entries_judgment_type_check"
    t.check_constraint "trade_type::text = ANY (ARRAY['real'::character varying::text, 'virtual'::character varying::text])", name: "entries_trade_type_check"
  end

  create_table "exits", force: :cascade do |t|
    t.decimal "actual_price", precision: 12, scale: 2
    t.bigint "ai_script_id"
    t.datetime "created_at", null: false
    t.text "exit_reason", null: false
    t.decimal "expected_price", precision: 12, scale: 2
    t.string "judgment_type", limit: 20, null: false
    t.text "memo"
    t.text "review_learning"
    t.text "review_missed"
    t.string "review_result", limit: 20
    t.integer "shares"
    t.bigint "stock_id", null: false
    t.string "trade_type", limit: 20, null: false
    t.date "traded_at"
    t.datetime "updated_at", null: false
    t.index ["ai_script_id"], name: "index_exits_on_ai_script_id"
    t.index ["stock_id", "trade_type", "judgment_type"], name: "index_exits_on_stock_trade_judgment"
    t.index ["stock_id"], name: "index_exits_on_stock_id"
    t.check_constraint "judgment_type::text = ANY (ARRAY['human'::character varying::text, 'ai'::character varying::text])", name: "exits_judgment_type_check"
    t.check_constraint "review_result IS NULL OR (review_result::text = ANY (ARRAY['as_planned'::character varying::text, 'missed'::character varying::text, 'partial'::character varying::text]))", name: "exits_review_result_check"
    t.check_constraint "trade_type::text = ANY (ARRAY['real'::character varying::text, 'virtual'::character varying::text])", name: "exits_trade_type_check"
  end

  create_table "expense_transactions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "expense_id", null: false
    t.bigint "transaction_id", null: false
    t.datetime "updated_at", null: false
    t.index ["expense_id"], name: "index_expense_transactions_on_expense_id"
    t.index ["transaction_id"], name: "index_expense_transactions_on_transaction_id", unique: true
  end

  create_table "expenses", force: :cascade do |t|
    t.decimal "amount", precision: 15, default: "0", null: false
    t.datetime "created_at", null: false
    t.date "end_month"
    t.integer "expense_type", default: 0, null: false
    t.datetime "imported_at"
    t.text "memo"
    t.bigint "minor_category_id", null: false
    t.bigint "payment_method_id", null: false
    t.integer "recurring_cycle", default: 0, null: false
    t.integer "renewal_month"
    t.date "start_month", null: false
    t.datetime "updated_at", null: false
    t.index ["end_month"], name: "index_expenses_on_end_month"
    t.index ["expense_type"], name: "index_expenses_on_expense_type"
    t.index ["minor_category_id"], name: "index_expenses_on_minor_category_id"
    t.index ["payment_method_id"], name: "index_expenses_on_payment_method_id"
    t.index ["start_month", "imported_at"], name: "index_expenses_on_start_month_and_imported_at"
    t.index ["start_month"], name: "index_expenses_on_start_month"
    t.check_constraint "amount >= 0::numeric", name: "expenses_amount_check"
    t.check_constraint "expense_type = ANY (ARRAY[0, 1])", name: "expenses_expense_type_check"
    t.check_constraint "recurring_cycle = ANY (ARRAY[0, 1])", name: "expenses_recurring_cycle_check"
    t.check_constraint "renewal_month IS NULL OR renewal_month >= 1 AND renewal_month <= 12", name: "expenses_renewal_month_check"
  end

  create_table "finance_import_drafts", force: :cascade do |t|
    t.string "compare_month"
    t.datetime "created_at", default: -> { "now()" }, null: false
    t.string "owner_key", null: false
    t.jsonb "pending_rows", default: [], null: false
    t.string "phase", default: "edit", null: false
    t.text "raw_json"
    t.jsonb "selected_lines", default: [], null: false
    t.datetime "updated_at", default: -> { "now()" }, null: false
    t.index ["owner_key"], name: "index_finance_import_drafts_on_owner_key", unique: true
  end

  create_table "forecast_defaults", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "expense_amount", precision: 15, default: "200000", null: false
    t.decimal "income_amount", precision: 15, default: "335000", null: false
    t.datetime "updated_at", null: false
    t.check_constraint "expense_amount >= 0::numeric", name: "forecast_defaults_expense_amount_check"
    t.check_constraint "income_amount >= 0::numeric", name: "forecast_defaults_income_amount_check"
  end

  create_table "forecasts", force: :cascade do |t|
    t.decimal "amount", precision: 15, null: false
    t.datetime "created_at", null: false
    t.integer "kind", default: 0, null: false
    t.date "month", null: false
    t.datetime "updated_at", null: false
    t.index ["month", "kind"], name: "index_forecasts_on_month_and_kind", unique: true
    t.check_constraint "kind = ANY (ARRAY[0, 1])", name: "forecasts_kind_check"
  end

  create_table "income_transactions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "income_id", null: false
    t.bigint "transaction_id", null: false
    t.datetime "updated_at", null: false
    t.index ["income_id"], name: "index_income_transactions_on_income_id"
    t.index ["transaction_id"], name: "index_income_transactions_on_transaction_id", unique: true
  end

  create_table "incomes", force: :cascade do |t|
    t.decimal "amount", precision: 15, default: "0", null: false
    t.datetime "created_at", null: false
    t.date "end_month"
    t.integer "income_type", default: 0, null: false
    t.bigint "minor_category_id", null: false
    t.date "start_month", null: false
    t.datetime "updated_at", null: false
    t.index ["end_month"], name: "index_incomes_on_end_month"
    t.index ["income_type"], name: "index_incomes_on_income_type"
    t.index ["minor_category_id"], name: "index_incomes_on_minor_category_id"
    t.index ["start_month"], name: "index_incomes_on_start_month"
    t.check_constraint "amount >= 0::numeric", name: "incomes_amount_check"
    t.check_constraint "income_type = ANY (ARRAY[0, 1])", name: "incomes_income_type_check"
  end

  create_table "industries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", limit: 100, null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_industries_on_name", unique: true
  end

  create_table "line_changes", force: :cascade do |t|
    t.bigint "ai_script_id"
    t.date "changed_on", null: false
    t.datetime "created_at", null: false
    t.string "judgment_type", limit: 20, null: false
    t.text "reason"
    t.bigint "stock_id", null: false
    t.decimal "stop_loss", precision: 12, scale: 2
    t.decimal "target_price", precision: 12, scale: 2
    t.string "trade_type", limit: 20, null: false
    t.datetime "updated_at", null: false
    t.index ["ai_script_id"], name: "index_line_changes_on_ai_script_id"
    t.index ["stock_id", "trade_type", "judgment_type", "changed_on"], name: "index_line_changes_on_stock_trade_judgment_changed"
    t.index ["stock_id"], name: "index_line_changes_on_stock_id"
    t.check_constraint "judgment_type::text = ANY (ARRAY['human'::character varying::text, 'ai'::character varying::text])", name: "line_changes_judgment_type_check"
    t.check_constraint "trade_type::text = ANY (ARRAY['real'::character varying::text, 'virtual'::character varying::text])", name: "line_changes_trade_type_check"
  end

  create_table "major_categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "kind", default: 0, null: false
    t.string "name", limit: 100, null: false
    t.datetime "updated_at", null: false
    t.index ["kind", "name"], name: "index_major_categories_on_kind_and_name", unique: true
    t.check_constraint "kind = ANY (ARRAY[0, 1])", name: "major_categories_kind_check"
  end

  create_table "minor_categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "major_category_id", null: false
    t.string "name", limit: 100, null: false
    t.datetime "updated_at", null: false
    t.index ["major_category_id", "name"], name: "index_minor_categories_on_major_category_id_and_name", unique: true
    t.index ["major_category_id"], name: "index_minor_categories_on_major_category_id"
  end

  create_table "monthly_balances", force: :cascade do |t|
    t.decimal "amount", precision: 15, null: false
    t.datetime "created_at", null: false
    t.date "month", null: false
    t.datetime "updated_at", null: false
    t.index ["month"], name: "index_monthly_balances_on_month", unique: true
  end

  create_table "payment_methods", force: :cascade do |t|
    t.integer "closing_day"
    t.datetime "created_at", null: false
    t.integer "debit_day"
    t.string "ledger_charge_timing", limit: 20
    t.string "method_type", limit: 20, default: "card", null: false
    t.string "name", limit: 100, null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_payment_methods_on_name", unique: true
    t.check_constraint "closing_day IS NULL OR closing_day >= 1 AND closing_day <= 31", name: "payment_methods_closing_day_check"
    t.check_constraint "debit_day IS NULL OR debit_day >= 1 AND debit_day <= 31", name: "payment_methods_debit_day_check"
    t.check_constraint "ledger_charge_timing IS NULL OR (ledger_charge_timing::text = ANY (ARRAY['same_month'::character varying::text, 'next_month'::character varying::text]))", name: "payment_methods_ledger_charge_timing_check"
    t.check_constraint "method_type::text = ANY (ARRAY['card'::character varying::text, 'bank_debit'::character varying::text, 'bank_withdrawal'::character varying::text])", name: "payment_methods_method_type_check"
  end

  create_table "stock_daily_notes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "hypothesis"
    t.string "owner_key", limit: 255, null: false
    t.date "recorded_on", null: false
    t.text "result"
    t.text "sector_research"
    t.datetime "updated_at", null: false
    t.index ["owner_key", "recorded_on"], name: "index_stock_daily_notes_on_owner_key_and_recorded_on", unique: true
  end

  create_table "stock_notes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "note", null: false
    t.date "noted_on", null: false
    t.bigint "stock_id", null: false
    t.string "title", limit: 200, default: "", null: false
    t.datetime "updated_at", null: false
    t.index ["stock_id", "noted_on"], name: "index_stock_notes_on_stock_id_and_noted_on"
    t.index ["stock_id"], name: "index_stock_notes_on_stock_id"
  end

  create_table "stock_trade_rules", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.string "title", limit: 100, null: false
    t.datetime "updated_at", null: false
  end

  create_table "stock_watch_batches", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "ends_on", null: false
    t.date "imported_on", null: false
    t.date "starts_on", null: false
    t.datetime "updated_at", null: false
    t.index ["imported_on"], name: "index_stock_watch_batches_on_imported_on"
    t.index ["starts_on", "ends_on"], name: "index_stock_watch_batches_on_starts_on_and_ends_on"
  end

  create_table "stock_watch_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "source_label", limit: 100, null: false
    t.bigint "stock_id", null: false
    t.bigint "stock_watch_batch_id", null: false
    t.datetime "updated_at", null: false
    t.index ["stock_id"], name: "index_stock_watch_items_on_stock_id"
    t.index ["stock_watch_batch_id", "stock_id"], name: "index_stock_watch_items_on_batch_and_stock", unique: true
    t.index ["stock_watch_batch_id"], name: "index_stock_watch_items_on_stock_watch_batch_id"
  end

  create_table "stocks", force: :cascade do |t|
    t.string "code", limit: 10, null: false
    t.datetime "created_at", null: false
    t.bigint "industry_id", null: false
    t.text "memo"
    t.string "name", limit: 200, null: false
    t.datetime "updated_at", null: false
    t.boolean "watched", default: false, null: false
    t.index ["code"], name: "index_stocks_on_code", unique: true
    t.index ["industry_id"], name: "index_stocks_on_industry_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.decimal "amount", precision: 15, null: false
    t.datetime "created_at", null: false
    t.date "month", null: false
    t.datetime "updated_at", null: false
    t.index ["month"], name: "index_transactions_on_month"
  end

  create_table "user_preferences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "import_claude_prompt_template"
    t.text "import_merchant_rules"
    t.string "owner_key", limit: 255, null: false
    t.text "stock_daily_hypothesis_prompt"
    t.text "stock_daily_result_prompt"
    t.text "stock_daily_sector_prompt"
    t.datetime "updated_at", null: false
    t.index ["owner_key"], name: "index_user_preferences_on_owner_key", unique: true
  end

  add_foreign_key "entries", "ai_scripts"
  add_foreign_key "entries", "stocks"
  add_foreign_key "exits", "ai_scripts"
  add_foreign_key "exits", "stocks"
  add_foreign_key "expense_transactions", "expenses"
  add_foreign_key "expense_transactions", "transactions"
  add_foreign_key "expenses", "minor_categories"
  add_foreign_key "expenses", "payment_methods"
  add_foreign_key "income_transactions", "incomes"
  add_foreign_key "income_transactions", "transactions"
  add_foreign_key "incomes", "minor_categories"
  add_foreign_key "line_changes", "ai_scripts"
  add_foreign_key "line_changes", "stocks"
  add_foreign_key "minor_categories", "major_categories"
  add_foreign_key "stock_notes", "stocks"
  add_foreign_key "stock_watch_items", "stock_watch_batches"
  add_foreign_key "stock_watch_items", "stocks"
  add_foreign_key "stocks", "industries"
end
