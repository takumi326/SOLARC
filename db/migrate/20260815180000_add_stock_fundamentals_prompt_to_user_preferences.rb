# frozen_string_literal: true

class AddStockFundamentalsPromptToUserPreferences < ActiveRecord::Migration[8.1]
  def change
    add_column :user_preferences, :stock_fundamentals_prompt, :text
  end
end
