# frozen_string_literal: true

class CreatePositionsAndTradeEvents < ActiveRecord::Migration[8.0]
  def up
    create_table :positions do |t|
      t.references :stock, null: false, foreign_key: true
      t.string :trade_type, limit: 20, null: false
      t.string :judgment_type, limit: 20, null: false
      t.bigint :ai_script_id
      t.integer :status, null: false, default: 0
      t.datetime :opened_at, null: false
      t.datetime :closed_at
      t.integer :quantity, null: false, default: 0
      t.decimal :average_cost, precision: 12, scale: 2
      t.decimal :realized_pnl, precision: 14, scale: 2, default: 0, null: false
      t.decimal :initial_stop, precision: 12, scale: 2
      t.decimal :initial_target, precision: 12, scale: 2
      t.timestamps
    end
    add_index :positions, [ :stock_id, :status ]
    add_index :positions, [ :stock_id, :trade_type, :judgment_type, :ai_script_id, :status ],
              name: "index_positions_on_stock_axis_status"
    add_check_constraint :positions, "trade_type IN ('real', 'virtual')", name: "positions_trade_type_check"
    add_check_constraint :positions, "judgment_type IN ('human', 'ai')", name: "positions_judgment_type_check"
    add_check_constraint :positions, "status IN (0, 1)", name: "positions_status_check"

    create_table :trade_events do |t|
      t.references :position, foreign_key: true
      t.references :stock, null: false, foreign_key: true
      t.string :trade_type, limit: 20, null: false
      t.string :judgment_type, limit: 20, null: false
      t.bigint :ai_script_id
      t.integer :kind, null: false
      t.datetime :executed_at, null: false
      t.integer :quantity
      t.decimal :expected_price, precision: 12, scale: 2
      t.decimal :actual_price, precision: 12, scale: 2
      t.decimal :stop_loss, precision: 12, scale: 2
      t.decimal :take_profit, precision: 12, scale: 2
      t.text :entry_reason
      t.text :scenario
      t.text :exit_reason
      t.text :reason
      t.text :memo
      t.string :review_result, limit: 20
      t.text :review_missed
      t.text :review_learning
      t.timestamps
    end
    add_index :trade_events, [ :position_id, :executed_at, :id ]
    add_index :trade_events, [ :stock_id, :trade_type, :judgment_type ]
    add_check_constraint :trade_events, "trade_type IN ('real', 'virtual')", name: "trade_events_trade_type_check"
    add_check_constraint :trade_events, "judgment_type IN ('human', 'ai')", name: "trade_events_judgment_type_check"
    add_check_constraint :trade_events, "kind IN (0, 1, 2)", name: "trade_events_kind_check"

    backfill_trade_events
    say_with_time "rebuild positions from trade_events" do
      Stock.find_each do |stock|
        PositionRebuilder.new(stock).call
      end
    end
  end

  def down
    drop_table :trade_events
    drop_table :positions
  end

  private

  def backfill_trade_events
    execute(<<~SQL.squish)
      INSERT INTO trade_events (
        position_id, stock_id, trade_type, judgment_type, ai_script_id, kind, executed_at,
        quantity, expected_price, actual_price, entry_reason, scenario, memo, created_at, updated_at
      )
      SELECT
        NULL, stock_id, trade_type, judgment_type, ai_script_id, 0,
        (COALESCE(traded_at, DATE(created_at))::timestamp + (id || ' seconds')::interval),
        shares, expected_price, actual_price, entry_reason, scenario, memo, created_at, updated_at
      FROM entries
    SQL

    execute(<<~SQL.squish)
      INSERT INTO trade_events (
        position_id, stock_id, trade_type, judgment_type, ai_script_id, kind, executed_at,
        quantity, expected_price, actual_price, exit_reason, memo, review_result, review_missed, review_learning,
        created_at, updated_at
      )
      SELECT
        NULL, stock_id, trade_type, judgment_type, ai_script_id, 1,
        (COALESCE(traded_at, DATE(created_at))::timestamp + (id || ' seconds')::interval),
        shares, expected_price, actual_price, exit_reason, memo, review_result, review_missed, review_learning,
        created_at, updated_at
      FROM exits
    SQL

    execute(<<~SQL.squish)
      INSERT INTO trade_events (
        position_id, stock_id, trade_type, judgment_type, ai_script_id, kind, executed_at,
        stop_loss, take_profit, reason, created_at, updated_at
      )
      SELECT
        NULL, stock_id, trade_type, judgment_type, ai_script_id, 2,
        (changed_on::timestamp + (id || ' seconds')::interval),
        stop_loss, target_price, reason, created_at, updated_at
      FROM line_changes
    SQL
  end
end
