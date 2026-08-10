class AddImportMerchantRulesToUserPreferences < ActiveRecord::Migration[8.1]
  def change
    add_column :user_preferences, :import_merchant_rules, :text
  end
end
